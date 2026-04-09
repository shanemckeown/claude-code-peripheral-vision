# Claude Code Peripheral Vision

Peripheral vision for Claude Code. Captures bugs, misconfigs, and code smells that Claude notices during coding but aren't part of the current task. Without this, they vanish.

## The Problem

During AI-assisted coding, Claude constantly notices tangential issues: a stale env reference while debugging an auth bug, pre-existing TypeScript errors while implementing a feature, 99 GitHub vulnerabilities scrolling past during a `git push`. These observations exist in Claude's reasoning or get mentioned once and forgotten. Over hundreds of sessions, this compounds into preventable production incidents.

## What It Does

Four hooks, one bash script, zero cost.

| Hook | When | What |
|------|------|------|
| **SessionStart** | Session begin/resume | Injects "log observations" instruction |
| **UserPromptSubmit** | Every 3rd message | Periodic reminder nudge |
| **PostToolUse:Bash** | After shell commands | Auto-captures warnings and deprecations |
| **Stop** | After each Claude response | Scans response for tangential observations |

The PostToolUse and Stop hooks are fully programmatic. No LLM involvement, just pattern matching. The SessionStart and UserPromptSubmit hooks are structural reminders so Claude doesn't need to "remember" to log things.

## Example Output

```
~/.claude/observer/observations.log

- [2026-04-06 16:54] (main) [auto] `git push -u origin main`
  remote: GitHub found 99 vulnerabilities on default branch (2 critical, 59 high, 34 moderate, 4 low)

- [2026-04-07 09:23] (feature/auth) [scan] Extracted from Claude's response:
  I notice the types in stripe.ts:520 have pre-existing TS2339 errors

- [2026-04-07 11:45] (main) [auto] `npx tsc --noEmit`
  warning TS6385: 'importsNotUsedAsValues' is deprecated in TypeScript 5.5

- [2026-04-07 14:02] (feature/booking) Stale SESSION_SECRET env ref in middleware.ts:42
```

Each entry is tagged with timestamp, branch, and source:
- `[auto]` — captured programmatically from command output
- `[scan]` — extracted from Claude's response via regex
- (no tag) — Claude logged it manually via the structural reminder

## Real-world Signal

Data from a single user running PV across 4 days in active development (Apr 6–9, 2026):

| Source | Captured | Real finds | Noise | Hit rate |
|---|---|---|---|---|
| **Manual** — Claude logs via the structural reminder | 19 | 19 | 0 | **100%** |
| **Scan** — regex on Claude's response text | 4 | 4 | 0 | **100%** |
| **Auto** — regex on Bash stdout | 40 | ~12 | ~28 | ~30% |
| **Total** | 63 | ~35 | ~28 | ~56% |

**Manual and scan are the high-value paths.** Every observation Claude logs itself, or that the scan regex pulls from its response text, is a real drive-by finding. In 4 days these two paths alone captured orphaned database tables, customer-facing modal bugs, deploy race conditions, and pre-emptive Next.js 16 deprecation signposts — all things that would otherwise have been mentioned once and lost.

**Auto is noisier than it should be.** The default grep for `warn` / `deprecat` picks up real warnings but also catches `Logger.warn(…)` log statements that appear in `git diff` / `git show` output, duplicate timestamped log paths (e.g. a daily gcloud permission error that re-hashes every run), and test mocks like `warn: jest.fn()`. The shipped `observer.sh` filter excludes the most common false-positive patterns and normalizes timestamped log paths before deduping — if you use custom logger helpers with a different name, extend the exclusion regex in the `grep -viE` block in `observer.sh`.

**Evaluating PV?** Don't judge it on the raw auto count. Read the entries tagged `[scan]` and the untagged manual entries — that's the high-signal core.

## Known Blind Spots

Peripheral vision only sees what the hook system exposes. A few structural limitations to understand before adoption:

- **IDE-only diagnostics.** TypeScript language server warnings, `@deprecated` JSDoc markers on library APIs, ESLint inline hints, and anything else your editor surfaces in the gutter but `tsc --noEmit` / `next build` ignore. These never hit Bash stdout (so `[auto]` can't see them) and Claude rarely writes about them in chat (so `[scan]` can't either). Real example: Drizzle ORM ships a `@deprecated` marker on `pgTable()`'s third parameter that surfaces as ~120 inline hints in Claude Code but produces zero output from `tsc` or `next build` — PV captured it only when a user explicitly asked about it.
- **Silent internal reasoning.** If Claude notices something while reading a file but the reasoning never reaches the response text or a Bash command, there's nothing for the hook to grep. The `[scan]` hook works on Claude's synthesis, not its thoughts.
- **Binary and image output.** The hook reads `tool_response.stdout` as text. Screenshot diffs, rendered PDFs, image comparisons — all invisible.

Practical implication: PV catches the majority of drive-by findings but not all of them. If you're doing a deprecation sweep or a dependency upgrade, don't rely on PV to surface IDE hints — run a dedicated pass with your editor open.

## Install

**Requires:** `jq` (`brew install jq` on macOS, `apt install jq` on Linux)

### 1. Copy the script

```bash
mkdir -p ~/.claude/hooks
curl -o ~/.claude/hooks/observer.sh \
  https://raw.githubusercontent.com/shanemckeown/claude-code-peripheral-vision/main/observer.sh
chmod +x ~/.claude/hooks/observer.sh
```

### 2. Add hooks to your settings

Add this to your `~/.claude/settings.json` inside the `"hooks"` object:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|compact",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/observer.sh",
            "statusMessage": "Observer: loading..."
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/observer.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/observer.sh",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/observer.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Start a new session

That's it. The observer runs automatically. Check captured observations:

```bash
cat ~/.claude/observer/observations.log
```

## Optional: Review Skills

Copy the skills from `skills/` to `~/.claude/skills/` for slash commands:

| Command | What |
|---------|------|
| `/pv` | Status overview and recent observations |
| `/pv-list` | Full list with filtering |
| `/pv-triage` | Interactive review: fix, create issue, dismiss, or skip each observation |
| `/pv-clear` | Archive observations and start fresh |

## Configuration

| Env var | Default | What |
|---------|---------|------|
| `OBSERVER_DIR` | `~/.claude/observer` | Where observations are stored |
| `OBSERVER_REMIND_INTERVAL` | `3` | Remind every Nth user message |

## How It Works

See [DESIGN.md](DESIGN.md) for the full architecture story, including:
- Why hooks beat CLAUDE.md instructions
- Format discovery (we dumped the actual JSON Claude Code sends to hooks)
- Why we scan Claude's synthesis, not raw files
- Why observations write to a global location

## Key Design Decision

Early in development, we considered firing a Haiku call after every file read to scan for issues. A non-obvious insight killed this approach: Claude already does the hard work of noticing issues. The gap isn't detection, it's capture. Paying a weaker model to re-scan files a stronger model already analyzed is redundant. The correct layer is Claude's own output (available in the Stop hook's `last_assistant_message` field), not the raw files.

## Deep Mode (optional)

For power users who want more thorough observation extraction, add a prompt hook that asks Haiku to analyze Claude's responses:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "prompt",
            "model": "claude-haiku",
            "prompt": "Review the following Claude Code assistant response. Extract any code observations that are OUTSIDE the current task scope -- bugs, misconfigs, deprecations, code smells, or issues the assistant noticed but chose not to address. For each observation, output: OBSERVATION: [description] [file:line if mentioned]. If none, output: NONE.",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

This adds one Haiku call per user message (~$0.005/session). The extracted observations appear in Claude's context, making it very likely to log them.

## License

MIT
