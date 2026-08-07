# Kiro → Anthropic API Proxy Plugin Plan

**Goal**: Mitmproxy addon that translates Kiro's AWS Bedrock API calls to Anthropic Messages API, enabling use of OAuth tokens instead of AWS credentials.

---

## Architecture

### Pipeline Flow

```
Kiro → mitmproxy → httpx → Anthropic API
  ↓         ↓         ↓           ↓
 AWS    Translate  Stream      OAuth
Request  Format    SSE        Auth
  ↓         ↓         ↓           ↓
 AWS    Encode    Parse      Response
Response  Binary   Events     Chunks
```

### Technology Stack

- **mitmproxy**: Request/response interception
- **httpx**: HTTP client for Anthropic API calls
- **botocore.eventstream**: AWS EventStream encoding/decoding
- **json**: Request/response translation
- **sseclient** or manual SSE parser: Parse Anthropic streaming

---

## Resource Locations

### Captured Data

- **Kiro API flows**: `./kiro-flows.mitm` (binary mitmproxy format)
- **Detailed text export**: `./kiro-flows-detailed.txt` (24,736 lines)
- **API comparison**: `./api-comparison.md` (542 lines)

### Reference Implementations

- **Claude Code OAuth**: `/home/fredrik/Projects/Python/project-autumn-25/crush-claude/`
  - OAuth flow: `_research/oauth/`
  - Proxy example: `_research/proxy/proxy-api.js`
  - API spec: `OFFICIAL_API_SPEC.md`
  - README: `README.md`

### Tools & Scripts

- **Hook script**: `./hook-fetch.js` (fetch interceptor)
- **Launch wrapper**: `./kiro-mitm.sh` (Kiro with mitmproxy)
- **Test decoder**: REPL session (proven EventStream decode)

---

## Translation Requirements

### 1. Request Translation: Kiro → Anthropic

#### Input: Kiro AWS Bedrock Format

```json
{
  "conversationState": {
    "conversationId": "...",
    "currentMessage": {
      "userInputMessage": {
        "content": "user message",
        "modelId": "claude-sonnet-4.5",
        "userInputMessageContext": {
          "tools": [{"toolSpecification": {...}}]
        }
      }
    },
    "history": [
      {"userInputMessage": {"content": "...", "modelId": "..."}},
      {"assistantResponseMessage": {"content": "...", "toolUses": []}}
    ]
  },
  "profileArn": "arn:aws:..."
}
```

#### Output: Anthropic Messages API Format

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 32000,
  "system": "You are Claude Code, Anthropic's official CLI for Claude.",
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "tools": [
    {"name": "...", "description": "...", "input_schema": {...}}
  ],
  "stream": true
}
```

#### Translation Steps

1. Extract `history` + `currentMessage` → flatten to `messages` array
2. Convert `userInputMessage` → `{role: "user"}`
3. Convert `assistantResponseMessage` → `{role: "assistant"}`
4. Extract first user message in history → extract as `system` if it's a system prompt
5. Unwrap `toolSpecification` → Anthropic tool format
6. Map model ID: `claude-sonnet-4.5` → `claude-sonnet-4-5-20250929`
7. Add required fields: `max_tokens`, inject identity in `system`

### 2. Response Translation: Anthropic → Kiro

#### Input: Anthropic SSE Streaming

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_..."}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":10}}

event: message_stop
data: {"type":"message_stop"}
```

#### Output: AWS EventStream Binary

```python
# For each text delta:
{
  headers: {
    ':event-type': 'assistantResponseEvent',
    ':content-type': 'application/json',
    ':message-type': 'event'
  },
  payload: b'{"content":"Hello"}'
}

# Final metering event:
{
  headers: {
    ':event-type': 'meteringEvent',
    ':content-type': 'application/json',
    ':message-type': 'event'
  },
  payload: b'{"unit":"credit","usage":0.00123}'
}
```

#### Translation Steps

1. Parse SSE events from Anthropic response
2. Extract `content_block_delta` → get `delta.text`
3. Encode each chunk as AWS EventStream message:
   - Headers: `:event-type`, `:content-type`, `:message-type`
   - Payload: `{"content": "text chunk"}`
4. Calculate credits from token usage (conversion factor ~0.006 per token)
5. Encode final `meteringEvent` with credit usage
6. Return concatenated binary stream

---

## Implementation Plan

### Phase 1: Basic Translation (No Streaming)

**File**: `kiro-anthropic-addon.py`

```python
from mitmproxy import http
import json
import httpx

class KiroAnthropicProxy:
    def request(self, flow: http.HTTPFlow):
        if "generateAssistantResponse" not in flow.request.url:
            return

        # Parse Kiro request
        kiro_req = json.loads(flow.request.content)

        # Translate to Anthropic format
        anthropic_req = translate_request(kiro_req)

        # Store for response phase
        flow.metadata["anthropic_request"] = anthropic_req

    def response(self, flow: http.HTTPFlow):
        if "anthropic_request" not in flow.metadata:
            return

        # Call Anthropic API (non-streaming first)
        anthropic_resp = call_anthropic_api(
            flow.metadata["anthropic_request"]
        )

        # Translate back to AWS format
        aws_response = translate_response(anthropic_resp)

        # Replace response
        flow.response.content = aws_response

addons = [KiroAnthropicProxy()]
```

**Functions to implement**:

- `translate_request(kiro_req)` → anthropic_req
- `call_anthropic_api(req)` → response
- `translate_response(anthropic_resp)` → AWS binary

### Phase 2: Streaming Support

Add SSE parsing and real-time AWS EventStream encoding:

```python
async def response(self, flow: http.HTTPFlow):
    # Stream Anthropic API
    async with httpx.AsyncClient() as client:
        async with client.stream('POST', 'https://api.anthropic.com/v1/messages',
                                 json=anthropic_req, headers=headers) as resp:
            buffer = bytearray()
            async for line in resp.aiter_lines():
                if line.startswith('data: '):
                    chunk = parse_sse_chunk(line)
                    aws_chunk = encode_aws_event(chunk)
                    buffer.extend(aws_chunk)

            flow.response.content = bytes(buffer)
```

### Phase 3: OAuth Token Management

Add automatic token loading from Claude Code OAuth:

```python
def load_oauth_token():
    """Load from /home/fredrik/Projects/Python/project-autumn-25/crush-claude/"""
    # Use oauth project to get fresh token
    pass
```

---

## Testing Strategy

### Unit Tests

1. **Request translation**:
   - Input: Kiro request from `kiro-flows-detailed.txt`
   - Expected: Valid Anthropic API request
   - Verify: Model ID, messages array, tools extraction

2. **Response translation**:
   - Input: Mock Anthropic SSE events
   - Expected: AWS EventStream binary
   - Verify: Decodable with `botocore.eventstream`

3. **EventStream encoding**:
   - Input: `{"content": "test"}`
   - Expected: Binary with correct headers/payload
   - Verify: Round-trip decode matches

### Integration Tests

1. **End-to-end with captured flows**:
   - Replay Kiro request from `kiro-flows.mitm`
   - Mock Anthropic API response
   - Verify Kiro can parse response

2. **Live API test**:
   - Run addon with mitmproxy
   - Launch Kiro with proxy
   - Send test message
   - Verify response appears in Kiro

---

## Endpoints to Intercept

### Primary Endpoint

- `POST https://codewhisperer.us-east-1.amazonaws.com/generateAssistantResponse`
  → Proxy to `POST https://api.anthropic.com/v1/messages`

### Stub Endpoints (Return Mock Data)

- `GET https://codewhisperer.us-east-1.amazonaws.com/ListAvailableModels`
  → Return Pro tier models
- `GET https://codewhisperer.us-east-1.amazonaws.com/getUsageLimits`
  → Return 1000 credits, 42 used

---

## Configuration

### Required Environment Variables

```bash
ANTHROPIC_API_KEY=sk-ant-api...  # Or load from OAuth
ANTHROPIC_OAUTH_TOKEN=sk-ant-oat01-...  # From Claude Code
```

### Launch Command

```bash
uv run mitmproxy \
  -s kiro-anthropic-addon.py \
  --listen-port 8080 \
  --set upstream_cert=false
```

### Kiro Launch (with proxy)

```bash
HTTP_PROXY=http://127.0.0.1:8080 \
HTTPS_PROXY=http://127.0.0.1:8080 \
NODE_EXTRA_CA_CERTS=~/.mitmproxy/mitmproxy-ca-cert.pem \
kiro
```

---

## Dependencies

Add to `pyproject.toml`:

```toml
dependencies = [
    "mitmproxy>=12.1.2",
    "boto3>=1.40.52",
    "botocore>=1.40.52",
    "httpx>=0.28.1",
]
```

Already installed in `tmp-kiro` project.

---

## Model ID Mapping

| Kiro Model ID       | Anthropic API Model ID                    |
| ------------------- | ----------------------------------------- |
| `claude-sonnet-4.5` | `claude-sonnet-4-5-20250929`              |
| `claude-sonnet-4`   | `claude-sonnet-4-20250514`                |
| `claude-opus-4`     | `claude-opus-4-20250514`                  |
| `auto`              | `claude-sonnet-4-5-20250929` (default)    |
| `simple-task`       | `claude-3-5-haiku-20241022` (lightweight) |

---

## Tool Schema Conversion

### Kiro Format

```json
{
  "toolSpecification": {
    "name": "executeBash",
    "description": "Execute bash command",
    "inputSchema": {
      "json": {
        "type": "object",
        "properties": {...},
        "required": [...]
      }
    }
  }
}
```

### Anthropic Format

```json
{
  "name": "executeBash",
  "description": "Execute bash command",
  "input_schema": {
    "type": "object",
    "properties": {...},
    "required": [...]
  }
}
```

**Conversion**: Unwrap `toolSpecification`, rename `inputSchema.json` → `input_schema`

---

## Credit Calculation

AWS Bedrock uses "credits" for metering. Conversion from Anthropic tokens:

```python
def tokens_to_credits(input_tokens, output_tokens):
    # Approximate conversion based on captured data
    # Example: 31999 tokens = 0.006 credits
    return (input_tokens + output_tokens) * 0.0000002
```

---

## Error Handling

### Anthropic API Errors

- Map HTTP error codes to AWS format
- Preserve error messages
- Return as AWS EventStream error event

### Token Expiry

- Detect 401 from Anthropic
- Attempt refresh (if using OAuth)
- Return meaningful error to Kiro

### Streaming Failures

- Handle incomplete SSE streams
- Close AWS EventStream properly
- Log errors for debugging

---

## Success Criteria

1. ✅ Kiro connects and authenticates (sees stubbed usage limits)
2. ✅ Chat messages translate correctly
3. ✅ Streaming responses work in real-time
4. ✅ Tool definitions preserved
5. ✅ Multi-turn conversations maintain context
6. ✅ System prompts (from history) extracted correctly
7. ✅ Credits/metering events calculated

---

## Next Steps

1. **Implement Phase 1**: Basic non-streaming translation
2. **Test with captured flows**: Validate request/response conversion
3. **Add streaming**: Implement SSE → EventStream pipeline
4. **Integration test**: Run with live Kiro + Anthropic API
5. **OAuth integration**: Load tokens from Claude Code OAuth project
6. **Polish**: Error handling, logging, configuration

---

## References

- **API Comparison**: `./api-comparison.md`
- **Kiro Captures**: `./kiro-flows.mitm`, `./kiro-flows-detailed.txt`
- **Anthropic Spec**: `/home/fredrik/Projects/Python/project-autumn-25/crush-claude/OFFICIAL_API_SPEC.md`
- **OAuth Implementation**: `/home/fredrik/Projects/Python/project-autumn-25/crush-claude/_research/oauth/`
- **EventStream Decode**: Proven in REPL (this session)

---

**Status**: Ready to implement
**Estimated Complexity**: Medium (streaming adds complexity, but all pieces proven)
**Blocker**: None - all dependencies available, format mappings documented
