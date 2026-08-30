Set up cross-repo session orchestration on this machine: teach the global Claude Code config that sessions can spawn peer sessions in other repos via tmux, and make every new session auto-load project context through the `tdk-1-start` skill.

## The concept

Claude Code sessions can see and message each other (`ListAgents` / `SendMessage`), and a session can launch a new interactive session with plain tmux + the `claude` CLI. That turns one habit into infrastructure: when the real fix belongs in a *different* repo than the session's cwd (e.g. working from a docs/knowledge hub while the change lands in a code repo), the session spawns a dedicated worker session **in** that repo instead of coding cross-repo. The worker gets the target repo's own CLAUDE.md, skills, and review setup — context the spawning session structurally lacks.

Two pieces make it work without re-derivation every time:

1. A **global CLAUDE.md section** documenting the spawn recipe and its guardrails.
2. A **global SessionStart hook** so every new session (spawned or hand-started) runs `tdk-1-start` first and loads its repo's context automatically.

## Prerequisites

- tmux installed.
- The `tdk-1-start` skill present in `~/.claude/skills/` — run this repo's `setup.sh` first if it isn't.

## Step 1 — add this section to `~/.claude/CLAUDE.md`

Append verbatim (create the file if missing; skip if an equivalent section already exists):

````markdown
## Cross-repo work: spawn a full session in the target repo via tmux

When the real fix lands in a *different repo* than the one this session is running in,
do not code it from here. Launch a dedicated Claude session in the target repo and hand
it the task — this is a known, supported move; don't re-derive it:

```bash
tmux new-session -d -s <name> -c <repo-path> "claude --remote-control <name>"
# without Remote Control:  claude -n <name>
```

- The spawned session loads that repo's own CLAUDE.md, skills, and review kit — context
  this session does not have. That's the point of spawning rather than editing cross-repo.
- After launch it appears in `ListAgents`; send it the task with `SendMessage`. Write the
  brief as if for someone with zero conversation context — it has none. It can message back.
- A global SessionStart hook already makes every new session run `tdk-1-start` on startup —
  don't also put "run tdk-1-start" in the brief.
- An initial prompt can also be passed as a CLI argument at launch.
- First launch in a directory may need one interactive trust/permission answer from Theunis —
  say so when spawning, and prefer launching where a session has run before.
- Implementation work still follows the worktree rule: the spawned session should work in a
  git worktree, not the repo's primary checkout (launch it there, or tell it to create one).
- Don't spawn a full session for a trivial lookup or one-line edit in another repo — a
  subagent or direct tools are cheaper. Spawn when the work is a real task: multi-file
  changes, needs the repo's conventions/review pipeline, or should run in parallel while
  this session continues its own work.
````

## Step 2 — add the SessionStart hook to `~/.claude/settings.json`

Merge into the existing file — never replace it. If a `hooks.SessionStart` entry already exists, add alongside rather than clobbering:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear",
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Theunis wants the tdk-1-start skill run at the start of every session. Invoke the tdk-1-start skill (Skill tool) as your first action to load the current repo context, then proceed with the user request.\"}}'"
          }
        ]
      }
    ]
  }
}
```

The matcher fires on fresh startups and after `/clear` (context wiped → reload wanted), but not on `--resume` or post-compaction, where context is already present.

## Step 3 — verify

```bash
jq -e '.hooks.SessionStart[] | select(.matcher == "startup|clear") | .hooks[] | select(.type == "command") | .command' ~/.claude/settings.json
```

Exit 0 and the echo command printed = correctly wired. Malformed JSON silently disables the whole settings file, so fix any pre-existing breakage too. The hook takes effect from the next session; already-running sessions won't see it.
