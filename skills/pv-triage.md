---
name: pv-triage
description: |
  Interactive triage of peripheral vision observations. Review each one
  and decide: fix now, create an issue, or dismiss.
  Use when: "pv triage", "pv-triage", "triage observations", "review observations".
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /pv-triage — Triage Observations

Walk through each unreviewed observation and decide what to do with it.

## Steps

1. Read the observation log:

```bash
OBS_FILE="$HOME/.claude/observer/observations.log"
[ -f "$OBS_FILE" ] && cat "$OBS_FILE" || echo "EMPTY"
```

2. If empty, tell the user: "No observations to triage. The observer will capture
   them as you work."

3. Parse each observation entry (entries start with `- [`). For each one,
   present it via AskUserQuestion:

   **Format the question clearly:**
   - Show the observation text
   - Show when it was captured and from which branch
   - Show the source ([auto], [scan], or manual)
   - If it references a file/line, note whether that file exists in the current project

   **Options:**
   - **A) Fix now** — investigate and fix this issue in the current session
   - **B) Create issue** — create a tracking issue (if `bd` is available, create a bead;
     otherwise suggest creating a GitHub issue or TODO)
   - **C) Dismiss** — not actionable, remove from log
   - **D) Skip** — leave it for later

4. After each decision:
   - **Fix now:** Stop triage. Tell the user you'll investigate the issue.
     Leave remaining observations for next triage.
   - **Create issue:** If `bd` CLI is available, run:
     ```bash
     bd create --title="[PV] <observation summary>" --description="<full observation text>\n\nSource: observer auto-capture" --type=bug --priority=3
     ```
     Then remove the observation from the log.
     If `bd` is not available, tell the user to create an issue manually.
   - **Dismiss:** Remove the observation from the log.
   - **Skip:** Leave it, move to the next observation.

5. To remove an observation from the log, rewrite the file without that entry.
   Be careful to preserve all other entries exactly.

6. After all observations are triaged (or user stops), show summary:
   ```
   Triage complete:
     Fixed: N
     Issues created: N
     Dismissed: N
     Skipped: N (remaining in log)
   ```
