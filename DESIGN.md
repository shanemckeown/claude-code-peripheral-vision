# claude-code-observer — Design Notes

## The Problem

During AI-assisted coding sessions, Claude constantly notices tangential issues
(bugs, misconfigs, code smells) that aren't part of the current task. These
observations vanish because:

1. They exist only in Claude's reasoning (the user never sees them)
2. They're mentioned once in chat ("I notice X but that's not our focus") and forgotten
3. Context compaction erases them between sessions

Over hundreds of sessions, this compounds into preventable production incidents and
accumulating tech debt. No existing tool captures this "peripheral vision."

## Why Hooks, Not Instructions

The first instinct is to add a CLAUDE.md instruction: "log observations to a file."
This fails because Claude doesn't "remember" to do it, especially during complex
debugging sessions where the current task dominates attention.

Hooks solve this structurally. They fire programmatically on specific events without
Claude needing to recall anything. The hook system handles the remembering.

## Format Discovery (2026-04-06)

Before building, we installed minimal dump hooks to capture the actual JSON formats
Claude Code sends to each hook event. Here's what we found:

### PostToolUse:Bash — tool_response shape

```json
{
  "tool_response": {
    "stdout": "actual command output here",
    "stderr": "error output here",
    "interrupted": false,
    "isImage": false
  }
}
```

The output lives at `.tool_response.stdout`, not `.tool_response` as a string.
This is what we grep for warnings and deprecation notices.

### UserPromptSubmit — available fields

```json
{
  "session_id": "...",
  "transcript_path": "/Users/.../.claude/projects/.../session.jsonl",
  "cwd": "/path/to/project",
  "prompt": "the user's message",
  "hook_event_name": "UserPromptSubmit"
}

```

Key: `cwd` is available (used for project directory resolution) and
`transcript_path` points to the full conversation JSONL. However, we don't
need to parse the transcript because of what we found in the Stop event.

### Stop — the discovery that simplified everything

```json
{
  "hook_event_name": "Stop",
  "last_assistant_message": "Claude's full response text...",
  "stop_hook_active": false,
  "transcript_path": "...",
  "cwd": "..."
}
```

**`last_assistant_message` is provided directly.** This is Claude's complete
response as a string, handed to the hook without any file parsing. This means
we can scan Claude's output for tangential observations using simple regex,
right in the Stop hook, with zero file I/O.

## Architecture Evolution

### Original design (before format discovery)

```
UserPromptSubmit → read transcript JSONL → parse last assistant message → regex
```

This was complex (JSONL parsing in bash), fragile (unknown transcript format),
and slow (reading potentially large files).

### Final design (after format discovery)

```
Stop → read last_assistant_message from input JSON → regex
```

Simpler, faster, no file I/O. The Stop hook gets the response handed to it.

### Why not scan every file with a smaller model?

Early in the design, we considered firing a Haiku call after every file read to
scan for issues. A non-technical insight from the project's creator killed this:

> "Claude already does the hard work of noticing issues. The gap isn't detection,
> it's capture."

Paying a weaker model to re-scan files that a stronger model already analyzed is
redundant. The correct layer is Claude's own synthesis (its response), not the
raw files. This reduced Deep mode cost from ~$0.03/session to ~$0.005/session.

## Two Modes

### Light (free, pure bash)

| Hook | Event | What it does |
|------|-------|-------------|
| SessionStart | Session begin/resume/compact | Injects "log observations" instruction |
| UserPromptSubmit | Every Nth user message | Periodic reminder nudge |
| PostToolUse:Bash | After shell commands (async) | Auto-captures warnings/deprecations |
| Stop | After each Claude response | Regex scans `last_assistant_message` for observations + session summary |

### Deep (Light + Haiku)

Adds a `type: "prompt"` hook on UserPromptSubmit that asks Haiku to extract
tangential observations from Claude's conversation context. Output is injected
as additional context, making Claude very likely to log it.

For power users with an API key, a `type: "command"` alternative calls Haiku
via curl for fully programmatic capture to the log file.

## Auto-Dedup

The PostToolUse:Bash hook greps command output for warnings. The same warning
(e.g., a TypeScript deprecation) appears on every build. Without dedup, the
log fills with noise. Each finding is hashed (md5) and checked against a
seen-hashes file. Duplicates are silently skipped.

## Why a Flat File

Structured issue trackers (GitHub Issues, Linear, beads) are better for
tracking work. But they add dependencies and setup friction. For a shareable
tool, the observation log should be:

- Zero-dependency (just a file)
- Append-only (safe for concurrent hooks)
- Human-readable (grep-friendly)

The flat file is the right v1. Issue tracker integration is a v2 feature
that people can build on top.

## Why a Global Location

Observations write to `~/.claude/observer/observations.log`, not to each
project's `.claude/` directory. This was a deliberate choice:

- **Worktree safety:** Conductor and git worktrees are ephemeral. When a
  workspace is archived or cleaned up, per-project observations would be lost.
- **Cross-project visibility:** One file shows observations from all projects.
  The branch tag on each entry provides context for which project it came from.
- **Override:** Set `OBSERVER_DIR` env var to change the location.
