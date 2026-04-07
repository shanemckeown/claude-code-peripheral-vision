---
name: pv-list
description: |
  List all peripheral vision observations with optional filtering.
  Use when: "pv list", "pv-list", "show observations", "list observations".
allowed-tools:
  - Bash
  - Read
---

# /pv-list — List Observations

Read and display all captured observations, with optional filtering.

## Steps

1. Check for arguments. The user may pass filters:
   - `/pv-list` — show all
   - `/pv-list auto` — only auto-captured (from command output)
   - `/pv-list scan` — only scanned from responses
   - `/pv-list <keyword>` — grep for a keyword

2. Read the log:

```bash
OBS_FILE="$HOME/.claude/observer/observations.log"
[ -f "$OBS_FILE" ] && cat "$OBS_FILE" || echo "EMPTY"
```

3. If filtering was requested, apply it. Otherwise show all entries.

4. Format the output as a numbered list for easy reference in `/pv-triage`:

```
  #1  [2026-04-06 14:05] (main) [auto] `npm run build`
      warning: React.createFactory() is deprecated

  #2  [2026-04-06 15:01] (feature/auth) [scan] Extracted from response:
      Race condition in auth.ts:89 — concurrent saves could overwrite

  #3  [2026-04-07 09:12] (main) Stale env ref in middleware.ts:42
```

5. Show count: "{N} observations total ({X} auto, {Y} scan, {Z} manual)"
