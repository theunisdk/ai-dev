Set up cross-repo session orchestration on this machine: teach the global Claude Code config that sessions start worker sessions in other repos through a launcher script, run as PM and worker, and keep worktrees inside the repo; and make every new session auto-load project context through the `tdk-1-start` skill.

## The concept

Claude Code sessions can see and message each other (`ListAgents` / `SendMessage`), and a session can launch a new interactive session. That turns one habit into infrastructure: when the real fix belongs in a *different* repo than the session's cwd (e.g. working from a docs/knowledge hub while the change lands in a code repo), the session spawns a dedicated worker session **in** that repo instead of coding cross-repo. The worker gets the target repo's own CLAUDE.md, skills, and review setup — context the spawning session structurally lacks.

The spawning session becomes that worker's PM: it tracks and decides, the worker does the work and the merge. Sessions are named so a family (one PM and its workers) shares a 4-digit code.

Three pieces make it work without re-derivation every time:

1. A **launcher script** the machine owner provides (spec below), plus a separate **PM launcher** for new top-level project sessions.
2. A **global CLAUDE.md section** documenting the launchers, the worktree location, the PM/worker split, and the guardrails.
3. A **global SessionStart hook** so every new session (spawned or hand-started) runs `tdk-1-start` first and loads its repo's context automatically.

## Prerequisites

- tmux installed.
- The `tdk-1-start` skill present in `~/.claude/skills/` — run this repo's `setup.sh` first if it isn't.
- A **worker launcher** on `PATH`, taking `<repo-path> <reason>` and a brief on stdin. It must:
  - name the worker `<code>-<repo>-<reason>`, where `<code>` is the spawning session's 4-digit family code, read from the spawning session's own name (mint a fresh one if that name has none);
  - create the worktree at `<repo>/.claude/worktrees/<reason>` on branch `feat/<reason>`, branched from origin's default branch (local HEAD when there is no origin);
  - launch in place, with no new worktree, when `<repo-path>` is already a linked worktree;
  - offer a no-worktree mode for research;
  - start the session there (one way: `tmux new-session -d -s <name> -c <dir> "claude --remote-control <name>"`), pin its effort (e.g. high), and send the brief as the first message (e.g. as the positional prompt argument to `claude`) so the worker starts at once.
- A **PM launcher** on `PATH` that starts a new top-level session named `<code>-PM-<link>-<reason>`, where `<link>` is a short project alias: a fresh 4-digit code per launch, the literal token `PM`, and `<reason>` defaulting to `session`.

Neither launcher ships with this repo. If the machine doesn't have them, write them to this spec first and substitute their names below.

## Step 1 — add this section to `~/.claude/CLAUDE.md`

Append verbatim, replacing `<worker-launcher>` and `<pm-launcher>` with the script names (create the file if missing; skip if an equivalent section already exists):

````markdown
## Worktrees live inside the repo

Every git worktree goes in `<repo>/.claude/worktrees/<name>`. Never create one next to the
repo as `../<repo>-<name>`, even where a skill or a repo's CLAUDE.md still says to.
By hand: `git -C <repo> worktree add .claude/worktrees/<name> -b feat/<name> origin/<default-branch>`.

## Cross-repo work: spawn a worker session in the target repo

When the real fix lands in a *different repo* than the one this session is running in,
do not code it from here. Launch a dedicated Claude session in the target repo and hand
it the task — this is a known, supported move; don't re-derive it:

```bash
<worker-launcher> [--no-worktree] <repo-path> <reason> - <<'EOF'
<the brief>
EOF
# --no-worktree: research, no code changes
```

- It names the worker `<code>-<repo>-<reason>` with this session's 4-digit family code.
  Don't hand-roll names or tmux commands.
- It creates `<repo>/.claude/worktrees/<reason>` on `feat/<reason>` from origin's default
  branch (local HEAD without an origin). A `<repo-path>` that is already a linked worktree
  launches in place.
- It pins the worker's effort and sends the brief as its first message, so the worker starts
  at once. Write the brief as if for someone with zero conversation context — it has none.
  Follow-ups go by `SendMessage`; the worker can message back.
- The spawned session loads that repo's own CLAUDE.md, skills, and review kit — context
  this session does not have. That's the point of spawning rather than editing cross-repo.
- A global SessionStart hook already makes every new session run `tdk-1-start` on startup —
  don't also put "run tdk-1-start" in the brief.
- First launch in an untrusted folder waits at the trust prompt for the user's answer —
  say so when spawning.
- Don't spawn a full session for a trivial lookup or one-line edit in another repo — a
  subagent or direct tools are cheaper. Spawn when the work is a real task: multi-file
  changes, needs the repo's conventions/review pipeline, or should run in parallel while
  this session continues its own work.

## "Start a <x> session": launch a PM session

When the user asks to start a session for a project, that is a new top-level PM session,
not a child of this one. Launch it with `<pm-launcher> <link> <repo-path> [reason] [goal...]`,
never with the worker launcher. It is named `<code>-PM-<link>-<reason>` (reason defaults to
`session`). Every launch gets a fresh code; never reuse one from an earlier launch, or the
new project's workers inherit the wrong family. Report the session name it prints.

## PM and worker sessions

- **The PM tracks and decides; it does no work.** It plans, writes briefs, starts workers with
  the worker launcher, reads their reports and the PR verdicts, and decides when each one
  merges and when to deploy. It never edits files, creates worktrees by hand, resolves
  conflicts, merges or deploys.
- **Workers do the work and the merge.** A worker implements, opens a reviewed PR, reports to
  its PM, and merges only after the PM sends GO. It deploys when told to. Workers carry their
  PM's code. Whichever session ran the worker launcher is that worker's PM.
- **A merge is its own Bash command.** Never chain `gh pr merge` or `git merge` to anything
  else with `&&`, `;`, `||` or `|`. Use `-R <owner/repo>` or `git -C <repo>` instead of a
  `cd` prefix.
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
