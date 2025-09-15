```
HANDLER CONFIGURATION

Available Handlers: SSH, PYTHON, CLAUDE
Actions: auto, ask, never
Timeout: 2s, 5s, 10s, 30s

Syntax:
# HANDLER_NAME
## Group Name (action, timeout)
- pattern
- ~disabled~
- pattern # comment

Example:
# SSH
## Safe Commands (auto, 2s)
- ls
- pwd

## File Operations (ask, 5s)
- rm *
- cp *

## Dangerous (never)
- sudo *
- rm -rf *
```
