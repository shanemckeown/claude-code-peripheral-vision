#!/usr/bin/env bash
# Minimal hook that dumps raw JSON input to /tmp for format discovery.
# Install temporarily, run a session, inspect the dumps, then remove.
set -euo pipefail

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || echo "")
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

case "$EVENT" in
  PostToolUse)
    if [ "$TOOL" = "Bash" ]; then
      echo "$INPUT" > /tmp/observer-dump-post-tool.json
    fi
    ;;
  UserPromptSubmit)
    echo "$INPUT" > /tmp/observer-dump-prompt.json
    ;;
  Stop)
    echo "$INPUT" > /tmp/observer-dump-stop.json
    ;;
esac

exit 0
