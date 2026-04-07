---
name: pv
description: |
  Peripheral Vision — review drive-by observations captured by the observer hook.
  Shows status, recent observations, and session stats.
  Use when: "pv", "observations", "what did observer catch", "peripheral vision".
allowed-tools:
  - Bash
  - Read
---

# /pv — Peripheral Vision Status

Show the current state of the observation log.

## Steps

1. Read the observation log:

```bash
OBS_FILE="$HOME/.claude/observer/observations.log"
if [ ! -f "$OBS_FILE" ]; then
  echo "NO_LOG"
else
  TOTAL=$(grep -c "^- \[" "$OBS_FILE" 2>/dev/null || echo 0)
  AUTO=$(grep -c "\[auto\]" "$OBS_FILE" 2>/dev/null || echo 0)
  SCAN=$(grep -c "\[scan\]" "$OBS_FILE" 2>/dev/null || echo 0)
  MANUAL=$((TOTAL - AUTO - SCAN))
  echo "TOTAL: $TOTAL"
  echo "AUTO: $AUTO (from command output)"
  echo "SCAN: $SCAN (from response scanning)"
  echo "MANUAL: $MANUAL (logged by Claude)"
  echo "---RECENT---"
  tail -20 "$OBS_FILE"
fi
```

2. If `NO_LOG`: tell the user the observer hasn't captured anything yet. Check that hooks are installed in `~/.claude/settings.json`.

3. Otherwise, present a summary:

```
Peripheral Vision: {TOTAL} observations
  {AUTO} auto-captured from command output
  {SCAN} scanned from Claude's responses
  {MANUAL} manually logged by Claude

Recent:
{last 5 observations}
```

4. Suggest next actions:
   - `/pv-list` to see all observations
   - `/pv-triage` to review and act on them
   - `/pv-clear` to archive reviewed observations
