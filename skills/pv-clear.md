---
name: pv-clear
description: |
  Archive or clear the observation log. Moves current observations to an
  archive file and starts fresh.
  Use when: "pv clear", "pv-clear", "clear observations", "archive observations".
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /pv-clear — Clear Observations

Archive the current observation log and start fresh.

## Steps

1. Check current state:

```bash
OBS_FILE="$HOME/.claude/observer/observations.log"
ARCHIVE_DIR="$HOME/.claude/observer/archive"
if [ ! -f "$OBS_FILE" ] || [ ! -s "$OBS_FILE" ]; then
  echo "EMPTY"
else
  COUNT=$(grep -c "^- \[" "$OBS_FILE" 2>/dev/null || echo 0)
  echo "COUNT: $COUNT"
fi
```

2. If empty: "Nothing to clear."

3. If observations exist, ask via AskUserQuestion:
   - **A) Archive and clear** — move to `~/.claude/observer/archive/YYYY-MM-DD.log`,
     start fresh. Nothing is lost.
   - **B) Delete permanently** — empty the log. Observations are gone.
   - **C) Cancel** — do nothing.

4. If archiving:

```bash
ARCHIVE_DIR="$HOME/.claude/observer/archive"
mkdir -p "$ARCHIVE_DIR"
mv "$HOME/.claude/observer/observations.log" "$ARCHIVE_DIR/$(date +%Y-%m-%d-%H%M%S).log"
touch "$HOME/.claude/observer/observations.log"
```

5. Confirm: "Archived {N} observations to {archive path}. Log is now empty."
