#!/bin/bash
# Launch Kiro with mitmproxy intercept

# Start mitmproxy in background (or run in separate terminal)
# Uncomment if you want it auto-started:
# mitmproxy &
# MITM_PID=$!

# Launch Kiro with proxy settings
NODE_EXTRA_CA_CERTS=~/.mitmproxy/mitmproxy-ca-cert.pem \
HTTP_PROXY=http://127.0.0.1:8080 \
HTTPS_PROXY=http://127.0.0.1:8080 \
kiro "$@"

# Cleanup
# kill $MITM_PID 2>/dev/null
