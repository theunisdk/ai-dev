# Session Board Mod — Design

**Date:** 2026-10-08
**Status:** Approved

## Problem

Sessions are spawned in tmux with `claude --remote-control <name>`, across several machines. A PM
session is named `<project>-pm-<number>-<topic>` and its workers carry the same number
(`add-member-corova-5158`). With several features running, the desktop sidebar is a flat list: it
doesn't show which worker belongs to which PM, or which session is waiting on the user (a command
approval, a question, a finished task).

## Goal

A pane in the Claude desktop app that shows, at a glance, every running session grouped under its
PM, with the ones that need the user called out at the top.

Out of scope: which machine a session runs on, its folder, acting on a session from the board.

## Data source

Claude Code already tracks every session the account can reach. The `ListAgents` tool returns it as
text, and a mod can call it with `$.tool.call({ tool: "ListAgents" })`. Verified on 2026-10-08:

```
Peer sessions (11):
  infrastructure-94 [e3e361]  ·  interactive  ·  idle  ·  started 3d ago
  pixeljoy-esp32-6d [99596b]  ·  interactive  ·  busy  ·  started 48m ago
  tbagbuild-server-setup [f9f708]  ·  Remote Control  ·  requires_action
  serova-pm-5158-shane [f3d130]  ·  Remote Control  ·  idle
```

- Sessions on other machines appear only while the calling session has Remote Control on.
- A remote session waiting on a permission prompt reported `requires_action`.
- States seen or found in the Claude Code source: `busy`, `waiting`, `idle` (local);
  `running`, `requires_action`, `idle` (Remote Control).

No per-session reporting, no server, no change to the spawn recipe in `tdk-3-is-pm`.

## Design

### What the user sees

- `/board` opens a **Sessions** pane (desktop app beside the transcript; terminal too).
- **Needs you** section on top: every session in `waiting` / `requires_action`, with its PM's name.
- One block per number: the PM first with a `PM` tag, workers indented under it. Blocks holding a
  waiting session sort first. A number with workers but no running PM shows "no PM".
- **Other** at the bottom: sessions with no number (`Spawner`, `tbagbuild`, …).
- Each row: name and state — **working** (`busy`, `running`), **needs you** (`waiting`,
  `requires_action`), **idle** (`idle`); any other state word shown as-is.
- If no Remote Control rows come back, a hint line: Remote Control is off in this session, so only
  this machine's sessions are listed.
- When a session turns to needs-you between two polls, a toast: `<name> needs you`.

### How it works

- Poll `ListAgents` every 5 s while the pane is open (`$.clock.every`); each tick first checks
  `$.ui.panes()` and stops the timer once the pane is gone.
- Each poll's parsed result is written to one `$.state` value; the pane's render hook reads it, so
  every write redraws the pane.
- **Parsing** (pure function): a row is `<name> [<ref>]  ·  <kind>  ·  <state>[  ·  …]`. Rows that
  don't match keep their raw text and land in Other.
- **Grouping** (pure function), from the name alone:
  - split on `-`: a `pm` token directly followed by a 3+ digit token marks the PM of that group;
  - otherwise the first token of 3+ digits puts the session in that group;
  - otherwise Other. (`infrastructure-94` and `pixeljoy-esp32-6d` stay in Other.)
- Toasts compare the set of needs-you names with the previous poll's, held in the same state value.

### Layout in the repo

- `mods/session-board/`: `.claude-plugin/plugin.json` (no `version`, so it follows commits),
  `hooks/hooks.json`, `hooks/register.tsx`, `hooks/board.ts` (parse + group), `types/index.d.ts`
  (the `$.state` contract), tests.
- `setup.sh`: also symlinks each `mods/*/` folder holding `.claude-plugin/plugin.json` into
  `~/.claude/skills/`, where Claude Code loads it as a plugin in every session.
- `.gitignore`: `mods/*/.claude-plugin/types/` (generated on every load, includes the machine's MCP
  tool list).
- README: a `mods/` section.

## Error handling

- `ListAgents` call rejects or returns no `listing`: the pane keeps the last good result and shows
  the error and its time in a dim line; the next tick retries.
- Unparseable rows are never dropped (see Parsing).

## Testing

- Unit tests for parse and group, using the two real listings captured on 2026-10-08.
- A render test mounting the pane on `terminal` and `desktop` with `ListAgents` mocked, checking the
  needs-you section, PM grouping and the no-Remote-Control hint.
- `claude plugin validate`, `tsc -p`, then a live check with `/board` against real sessions.
