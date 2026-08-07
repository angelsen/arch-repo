# Kiro AWS Bedrock API vs Anthropic Messages API Comparison

This document compares the API format used by Kiro's AWS Bedrock integration (`/generateAssistantResponse`) with Anthropic's standard Messages API (`/v1/messages`).

## Overview

- **Kiro AWS Bedrock**: Uses a conversational state model with explicit history tracking and AWS-specific metadata
- **Anthropic Messages API**: Uses a standard request/response model with messages array and SSE streaming

---

## Request Format Comparison

### Top-Level Structure

#### Kiro AWS Bedrock

```json
{
  "conversationState": { ... },
  "profileArn": "arn:aws:codewhisperer:..."
}
```

#### Anthropic Messages API

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 32000,
  "messages": [ ... ],
  "tools": [ ... ],
  "system": "...",
  "temperature": 1.0,
  "metadata": { ... },
  "stream": true
}
```

### Conversation State vs Messages Array

#### Kiro AWS Bedrock - `conversationState`

```json
{
  "conversationState": {
    "agentContinuationId": "0c753dc5-4838-471b-8ee7-aab8e42f17b6",
    "agentTaskType": "vibe",
    "chatTriggerType": "MANUAL",
    "conversationId": "219470f4-9c3c-467c-9622-41ac3a6a0883",
    "currentMessage": {
      "userInputMessage": {
        "content": "hi",
        "modelId": "claude-sonnet-4.5",
        "origin": "AI_EDITOR",
        "userInputMessageContext": {
          "tools": [ ... ]
        }
      }
    },
    "history": [
      {
        "userInputMessage": {
          "content": "previous user message",
          "modelId": "simple-task",
          "origin": "AI_EDITOR"
        }
      },
      {
        "assistantResponseMessage": {
          "content": "previous assistant response",
          "toolUses": []
        }
      }
    ]
  },
  "profileArn": "arn:aws:codewhisperer:us-east-1:699475941385:profile/EHGA3GRVQMUK"
}
```

**Key characteristics:**

- Separates current message from conversation history
- Each message has a `modelId` field
- Tools are nested in `currentMessage.userInputMessage.userInputMessageContext.tools`
- History is an array of alternating `userInputMessage` and `assistantResponseMessage` objects
- Contains AWS-specific metadata (agentContinuationId, conversationId, profileArn)

#### Anthropic Messages API - `messages`

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 32000,
  "messages": [
    {
      "role": "user",
      "content": "previous user message"
    },
    {
      "role": "assistant",
      "content": "previous assistant response"
    },
    {
      "role": "user",
      "content": "current user message"
    }
  ],
  "tools": [ ... ],
  "system": "system prompt"
}
```

**Key characteristics:**

- Flat messages array with role-based structure
- Current message is the last item in the messages array
- Model is specified once at the top level
- Tools are at the top level, apply to all messages
- System prompt is a separate top-level field
- Requires `max_tokens` parameter

### Tool Definitions

#### Kiro AWS Bedrock - Tool Format

```json
{
  "tools": [
    {
      "toolSpecification": {
        "name": "executeBash",
        "description": "Execute the specified bash command...",
        "inputSchema": {
          "json": {
            "type": "object",
            "properties": {
              "command": {
                "type": "string",
                "description": "Bash command to execute"
              }
            },
            "required": ["command"],
            "additionalProperties": false,
            "$schema": "http://json-schema.org/draft-07/schema#"
          }
        }
      }
    }
  ]
}
```

**Location**: `conversationState.currentMessage.userInputMessage.userInputMessageContext.tools`

**Key characteristics:**

- Tools wrapped in `toolSpecification` object
- Schema wrapped in `inputSchema.json` object
- Includes `$schema` reference

#### Anthropic Messages API - Tool Format

```json
{
  "tools": [
    {
      "name": "Task",
      "description": "Launch a new agent to handle complex tasks...",
      "input_schema": {
        "type": "object",
        "properties": {
          "subagent_type": {
            "type": "string",
            "description": "Agent type to use"
          }
        },
        "required": ["subagent_type"]
      }
    }
  ]
}
```

**Location**: Top-level `tools` field

**Key characteristics:**

- Direct tool objects (no wrapper)
- Uses `input_schema` (snake_case) instead of `inputSchema`
- No `$schema` reference needed
- Simpler, flatter structure

### Message Content Structure

#### Kiro AWS Bedrock

```json
{
  "userInputMessage": {
    "content": "message text with environment context",
    "modelId": "claude-sonnet-4.5",
    "origin": "AI_EDITOR"
  }
}
```

```json
{
  "assistantResponseMessage": {
    "content": "assistant response text",
    "toolUses": []
  }
}
```

#### Anthropic Messages API

```json
{
  "role": "user",
  "content": "message text"
}
```

```json
{
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "assistant response"
    }
  ]
}
```

**Note**: Anthropic content can be either a string or an array of content blocks (text, tool_use, tool_result)

---

## Response Format Comparison

### Kiro AWS Bedrock - Binary Event Stream

**Format**: AWS Event Stream (binary protocol)

```
:event-type...assistantResponseEvent
:content-type...application/json
:message-type...event{"content":"Hi"}

:event-type...assistantResponseEvent
:content-type...application/json
:message-type...event{"content":"! Need help with something?"}

:event-type...meteringEvent
:content-type...application/json
:message-type...event{"unit":"credit","usage":0.03218855223880597}
```

**Event types**:

- `assistantResponseEvent`: Contains content chunks
  - Format: `{"content": "text chunk"}`
- `meteringEvent`: Contains usage information
  - Format: `{"unit": "credit", "usage": 0.032...}`

**Characteristics**:

- Binary event stream format
- Each chunk is a separate event
- Text is streamed incrementally
- Usage information comes at the end

### Anthropic Messages API - Server-Sent Events (SSE)

**Format**: Standard SSE with `event:` and `data:` lines

```
event: message_start
data: {"type":"message_start","message":{"model":"claude-3-5-haiku-20241022","id":"msg_01KF9RVY...","role":"assistant","content":[],"usage":{...}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{...}}

event: message_stop
data: {"type":"message_stop"}
```

**Event types**:

1. `message_start`: Initial message metadata
2. `content_block_start`: Start of a content block (text, thinking, tool_use)
3. `content_block_delta`: Incremental text chunks
4. `ping`: Keep-alive pings
5. `content_block_stop`: End of content block
6. `message_delta`: Final metadata and usage
7. `message_stop`: End of stream

**Characteristics**:

- Standard SSE protocol (widely supported)
- Structured event lifecycle
- Multiple content blocks possible (thinking, text, tool_use)
- Rich metadata in each event
- Usage information in both `message_start` and `message_delta`

---

## Translation Requirements

### Request Translation: Kiro → Anthropic

#### 1. Flatten Message Structure

```javascript
// Extract from Kiro format
const kiroRequest = {
  conversationState: {
    currentMessage: { userInputMessage: { content, modelId, userInputMessageContext } },
    history: [ ... ]
  }
};

// Transform to Anthropic format
const anthropicRequest = {
  model: modelId,  // Extract from currentMessage
  max_tokens: 32000,  // Add required field
  messages: [
    // Convert history
    ...history.map(msg => {
      if (msg.userInputMessage) {
        return { role: "user", content: msg.userInputMessage.content };
      } else if (msg.assistantResponseMessage) {
        return { role: "assistant", content: msg.assistantResponseMessage.content };
      }
    }),
    // Add current message
    { role: "user", content: currentMessage.userInputMessage.content }
  ],
  tools: userInputMessageContext.tools?.map(transformTool) || undefined
};
```

#### 2. Transform Tool Definitions

```javascript
function transformTool(kiroTool) {
  return {
    name: kiroTool.toolSpecification.name,
    description: kiroTool.toolSpecification.description,
    input_schema: kiroTool.toolSpecification.inputSchema.json,
    // Remove $schema field if present
  };
}
```

#### 3. Extract System Prompt

```javascript
// Kiro embeds system prompt in first history message content
// Anthropic uses separate system field
const systemPrompt = extractSystemPromptFromHistory(history);
if (systemPrompt) {
  anthropicRequest.system = systemPrompt;
}
```

#### 4. Map Model Names

```javascript
const modelMapping = {
  "claude-sonnet-4.5": "claude-sonnet-4-5-20250929",
  "simple-task": "claude-3-5-haiku-20241022",
  // Add other mappings
};

anthropicRequest.model = modelMapping[kiroModelId] || kiroModelId;
```

### Response Translation: Anthropic → Kiro

#### 1. Convert SSE to Binary Event Stream

```javascript
// Parse Anthropic SSE events
for (const event of sseEvents) {
  if (event.event === "content_block_delta") {
    const text = event.data.delta.text;

    // Convert to Kiro binary event format
    emitKiroBinaryEvent({
      eventType: "assistantResponseEvent",
      content: { content: text },
    });
  }

  if (event.event === "message_delta") {
    const usage = event.data.usage;

    // Emit metering event
    emitKiroBinaryEvent({
      eventType: "meteringEvent",
      content: { unit: "credit", usage: calculateCredits(usage) },
    });
  }
}
```

#### 2. Handle Content Blocks

```javascript
// Anthropic can have multiple content blocks (thinking, text)
// Kiro expects simple text chunks
let fullContent = "";

for (const event of sseEvents) {
  if (
    event.event === "content_block_delta" &&
    event.data.delta.type === "text_delta"
  ) {
    fullContent += event.data.delta.text;
    // Stream each chunk to Kiro
  }
}
```

#### 3. Calculate Credits from Tokens

```javascript
// Anthropic provides token counts, Kiro uses credits
function calculateCredits(usage) {
  // Example conversion (actual rates may differ)
  const inputTokens = usage.input_tokens || 0;
  const outputTokens = usage.output_tokens || 0;

  const inputCost = (inputTokens * 0.003) / 1000; // $3 per MTok
  const outputCost = (outputTokens * 0.015) / 1000; // $15 per MTok

  return inputCost + outputCost;
}
```

---

## Fields That Can Pass Through Unchanged

### From Kiro to Anthropic:

- **Tool names and descriptions**: Direct copy
- **Tool input schemas**: Copy with structure change (unwrap from `inputSchema.json`)
- **Message content text**: Direct copy (remove environment context tags if needed)
- **Temperature**: Can pass through if present

### From Anthropic to Kiro:

- **Text content chunks**: Direct copy
- **Stop reason**: Can be preserved (map to Kiro format)

---

## Fields Requiring Translation

### Kiro → Anthropic:

| Kiro Field                                                  | Anthropic Field | Transformation                                                    |
| ----------------------------------------------------------- | --------------- | ----------------------------------------------------------------- |
| `conversationState.currentMessage.userInputMessage.modelId` | `model`         | Map model names                                                   |
| `conversationState.history` + `currentMessage`              | `messages`      | Flatten to role-based array                                       |
| `userInputMessageContext.tools`                             | `tools`         | Unwrap `toolSpecification`, rename `inputSchema` → `input_schema` |
| N/A                                                         | `max_tokens`    | Add default value (e.g., 32000)                                   |
| System prompt in first history message                      | `system`        | Extract from history                                              |
| `conversationId`, `agentContinuationId`                     | `metadata`      | Optional: preserve in metadata                                    |

### Anthropic → Kiro:

| Anthropic Field              | Kiro Field               | Transformation                 |
| ---------------------------- | ------------------------ | ------------------------------ |
| SSE events                   | Binary event stream      | Convert protocol               |
| `content_block_delta` events | `assistantResponseEvent` | Extract text from delta        |
| `message_delta.usage`        | `meteringEvent`          | Convert tokens to credits      |
| `message.id`                 | `conversationId`         | Optional: use for tracking     |
| `stop_reason`                | N/A                      | Can be logged but not required |

---

## Additional Considerations

### 1. Model ID Mapping

Kiro uses simplified model names while Anthropic uses versioned identifiers:

- `claude-sonnet-4.5` → `claude-sonnet-4-5-20250929`
- `simple-task` → `claude-3-5-haiku-20241022` (or appropriate small model)

### 2. Environment Context

Kiro embeds environment information in user messages:

```
hi

<EnvironmentContext>
<OPEN-EDITOR-FILES>
No files are open
</OPEN-EDITOR-FILES>
</EnvironmentContext>
```

This can either be:

- Stripped before sending to Anthropic
- Preserved as-is (Anthropic will process it)
- Moved to system prompt

### 3. Tool Use Responses

Both formats support tool use, but structure differs:

- **Kiro**: `assistantResponseMessage.toolUses`
- **Anthropic**: Content blocks with `type: "tool_use"`

Tool results also differ in structure and need translation.

### 4. Streaming vs Non-Streaming

Both APIs support streaming, but:

- **Kiro**: Binary event stream (AWS-specific protocol)
- **Anthropic**: Standard SSE (easier to parse)

For non-streaming, Anthropic returns a complete message object, while Kiro likely expects a single event.

### 5. Error Handling

Error formats differ between the APIs and need translation:

- **Anthropic**: Standard HTTP errors with JSON body
- **Kiro**: AWS-specific error events in the stream

### 6. Authentication

- **Kiro**: Uses AWS credentials and profile ARN
- **Anthropic**: Uses `x-api-key` header

The proxy must handle authentication translation.

---

## Summary

### Most Complex Translations:

1. **Message structure**: Kiro's nested `currentMessage` + `history` → Anthropic's flat `messages` array
2. **Tool definitions**: Unwrapping `toolSpecification` and renaming `inputSchema`
3. **Response streaming**: Binary event stream → SSE format
4. **Usage/metering**: Token counts → credit calculations

### Simplest Pass-Throughs:

1. Message content text
2. Tool names and descriptions
3. Tool input schemas (structure preserved, just unwrapped)
4. Basic metadata

### Critical Requirements:

1. Must add `max_tokens` for Anthropic (not present in Kiro)
2. Must convert model IDs to Anthropic's versioned format
3. Must handle streaming protocol conversion
4. Must extract/inject system prompts correctly
