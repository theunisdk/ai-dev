# Session Board Mod Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Claude Code mod whose `/board` command opens a pane listing every running session, grouped under its PM, with the sessions waiting on the user on top.

**Architecture:** One plugin at `mods/session-board/`. Pure functions in `hooks/board.ts` parse the `ListAgents` tool's text listing and group it by the number in each session name. `hooks/register.tsx` registers `/board`, polls `ListAgents` every 5 s through `$.tool.call` while the pane is open, keeps the parsed list in one `$.state` value, toasts sessions that start waiting, and draws the pane. `setup.sh` links `mods/*` into `~/.claude/skills/`, where Claude Code loads each as a plugin.

**Tech Stack:** Claude Code function-hook plugins (TypeScript/TSX module, `claude-code` API, `claude-code/testing` kit), `claude plugin validate`, `claude plugin test`, bash.

**Spec:** `docs/superpowers/specs/2026-10-08-session-board-design.md`

## Global Constraints

- Work on branch `feat/session-board`. Never commit to `main`; never push.
- Commit messages: imperative subject in the repo's style (`mods: …`, `setup: …`), no attribution or co-author lines.
- Comments: match the surrounding density (these files carry almost none). A comment only where a reader would otherwise reach a wrong conclusion. No change-narration, no "previously…", no `FIX:` markers, no comments defending a decision — that belongs in the commit body.
- The mod runs with no DOM and no Node: no `fs`, `process`, `require` or dynamic `import()`; everything outside goes through `$`.
- Any function that takes `$` must be declared at the module's top level, not inside `register` (`claude plugin validate` refuses `$` passed to a nested function).
- `$.state` refs need literal `plugin` and `key`: `{ plugin: 'session-board', key: 'snapshot' } as const`.
- In tests: hooks are `($, e, next)`; op events (`ui.open`, `ui.panes`, `ui.toast`, `command.register`) answer `{ value }`; `tool.call` answers `{ result }` or `{ deny }`; `session.start` answers `{ cwd }`.
- Poll interval 5000 ms. Command name `board`. Pane id `session-board`, title `Sessions`.
- Grouping: split the name on `-`; a `pm` token (any case) directly followed by a 3+ digit token marks the PM of that number; otherwise the first 3+ digit token is the group; otherwise Other.
- States: `busy`, `running` → working; `waiting`, `requires_action` → needs you; `idle` → idle; anything else shown as the raw word.
- Run every `claude plugin …` command from the repo root `/Users/theunisdk/dev/private/ai-dev`.
- Do not write into the real `~/.claude/`. `setup.sh` checks run with a temporary `HOME`.

## Review Focus

- `ListAgents` output changes in a later Claude Code release: rows the parser can't read must still appear (in Other), never vanish. Pinned in Task 1 (`keeps a row it cannot read…`, `never groups a row it could not read`).
- `ListAgents` slower than the 5 s tick (many Remote Control sessions): ticks must not stack calls. Pinned in Task 2 (`skips a tick while the previous ListAgents call is still running`).
- The pane closed, or the mod hot-reloaded with the pane still open: polling stops in the first case and resumes in the second. Pinned in Task 2 (`stops polling…`, `resumes polling…`).
- Remote Control off in the board session: the board silently shows only local sessions unless it says why. Pinned in Task 2 (`hints at Remote Control…`).
- `setup.sh` re-run, or a real directory already at the link's place: must stay idempotent and never clobber. Pinned in Task 3's check script.

---

### Task 1: Mod scaffold, listing parser and grouping

**Files:**
- Create: `mods/session-board/.claude-plugin/plugin.json`
- Create: `mods/session-board/hooks/hooks.json`
- Create: `mods/session-board/hooks/register.tsx` (stub; Task 2 replaces it)
- Create: `mods/session-board/types/index.d.ts`
- Create: `mods/session-board/hooks/board.ts`
- Test: `mods/session-board/tests/fixtures.ts`, `mods/session-board/tests/board.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces (`hooks/board.ts`):
  - `parseListing(listing: string): Session[]`
  - `groupOf(name: string): { number: string; isPm: boolean } | null`
  - `buildBoard(sessions: Session[]): Board`
  - `newlyWaiting(before: Session[], after: Session[]): string[]`
- Produces (`types/index.d.ts`): `SessionState`, `Session`, `Group`, `NeedsYou`, `Board`, `Snapshot`, and the `PluginState` entry `'session-board': { snapshot: Snapshot }`.
- Produces (`tests/fixtures.ts`): `ALL_IDLE`, `ONE_WAITING`, `WORKER_WAITING`, `LOCAL_ONLY` listing strings.

- [ ] **Step 1: Write the manifest, hooks list, stub module and state contract**

`mods/session-board/.claude-plugin/plugin.json`:
```json
{
  "name": "session-board",
  "description": "A pane listing running Claude Code sessions, grouped under their PM, with the ones waiting on you on top",
  "author": { "name": "Theunis" },
  "types": "./types/index.d.ts"
}
```

`mods/session-board/hooks/hooks.json`:
```json
{ "modules": ["./register.tsx"] }
```

`mods/session-board/hooks/register.tsx` (stub, so the plugin loads for the tests):
```tsx
import type { Register } from 'claude-code'

export const register: Register = () => {}
```

`mods/session-board/types/index.d.ts`:
```ts
export type SessionState = 'working' | 'needs-you' | 'idle' | 'unknown'

export type Session = {
  name: string
  kind: string
  status: string
  state: SessionState
  isParsed: boolean
}

export type Group = { number: string; pms: Session[]; workers: Session[] }

export type NeedsYou = { session: Session; pmName: string | null }

export type Board = {
  needsYou: NeedsYou[]
  groups: Group[]
  other: Session[]
  hasRemote: boolean
}

export type Snapshot = {
  sessions: Session[]
  checkedAt: number | null
  error: { message: string; at: number } | null
}

declare module 'claude-code' {
  interface PluginState {
    'session-board': { snapshot: Snapshot }
  }
}
```

- [ ] **Step 2: Write the fixtures and the failing tests**

`mods/session-board/tests/fixtures.ts`:
```ts
// Captured from ListAgents on 2026-10-08.
export const ALL_IDLE = `This session is Claude Code mods storage location [d34ee0] — the name other sessions use to message it (it is not listed below; a message to it would be a message to yourself).

Peer sessions (10):
  infrastructure-94 [e3e361]  ·  interactive  ·  idle  ·  started 3d ago
  pixeljoy-esp32-6d [99596b]  ·  interactive  ·  busy  ·  started 45m ago
  Spawner [2c22cc]  ·  Remote Control  ·  idle
  tbagbuild-server-setup [f9f708]  ·  Remote Control  ·  idle
  serova-pm-5158-shane [f3d130]  ·  Remote Control  ·  idle
  meeting-pm-1774-security [568b57]  ·  Remote Control  ·  idle
  tbagdev-help [5e23ee]  ·  Remote Control  ·  idle
  add-member-corova-5158 [a3632a]  ·  Remote Control  ·  idle
  sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  idle
  tbagbuild [6213a5]  ·  Remote Control  ·  idle`

export const ONE_WAITING = `This session is Claude Code mods storage location [d34ee0] — the name other sessions use to message it (it is not listed below; a message to it would be a message to yourself).

Peer sessions (11):
  infrastructure-94 [e3e361]  ·  interactive  ·  idle  ·  started 3d ago
  pixeljoy-esp32-6d [99596b]  ·  interactive  ·  busy  ·  started 48m ago
  tbagbuild-server-setup [f9f708]  ·  Remote Control  ·  requires_action
  tektons-9396-memebrdb [6501b1]  ·  Remote Control  ·  idle
  Spawner [2c22cc]  ·  Remote Control  ·  idle
  serova-pm-5158-shane [f3d130]  ·  Remote Control  ·  idle
  meeting-pm-1774-security [568b57]  ·  Remote Control  ·  idle
  tbagdev-help [5e23ee]  ·  Remote Control  ·  idle
  add-member-corova-5158 [a3632a]  ·  Remote Control  ·  idle
  sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  idle
  tbagbuild [6213a5]  ·  Remote Control  ·  idle`

export const WORKER_WAITING = ALL_IDLE.replace(
  'sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  idle',
  'sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  requires_action',
)

export const LOCAL_ONLY = `Peer sessions (2):
  infrastructure-94 [e3e361]  ·  interactive  ·  idle  ·  started 3d ago
  pixeljoy-esp32-6d [99596b]  ·  interactive  ·  waiting  ·  started 45m ago`
```

`mods/session-board/tests/board.test.ts`:
```ts
import { describe, expect, test } from 'claude-code/testing'

import { buildBoard, groupOf, newlyWaiting, parseListing } from '../hooks/board'
import { ALL_IDLE, LOCAL_ONLY, ONE_WAITING, WORKER_WAITING } from './fixtures'

describe('parseListing', () => {
  test('reads every peer row and skips the header lines', () => {
    const sessions = parseListing(ALL_IDLE)
    expect(sessions.length).toBe(10)
    expect(sessions[0]).toEqual({
      name: 'infrastructure-94',
      kind: 'interactive',
      status: 'idle',
      state: 'idle',
      isParsed: true,
    })
    expect(sessions[2]).toEqual({
      name: 'Spawner',
      kind: 'Remote Control',
      status: 'idle',
      state: 'idle',
      isParsed: true,
    })
  })

  test('maps local and Remote Control states', () => {
    const states = parseListing(ONE_WAITING).map(s => [s.name, s.state])
    expect(states).toContainEqual(['tbagbuild-server-setup', 'needs-you'])
    expect(states).toContainEqual(['pixeljoy-esp32-6d', 'working'])
    expect(parseListing(LOCAL_ONLY)[1]?.state).toBe('needs-you')
    const running = parseListing('  w-1234 [a1]  ·  Remote Control  ·  running')
    expect(running[0]?.state).toBe('working')
  })

  test('keeps an unknown state word as-is', () => {
    const [session] = parseListing('  w-1234 [a1]  ·  Remote Control  ·  compacting')
    expect(session).toEqual({
      name: 'w-1234',
      kind: 'Remote Control',
      status: 'compacting',
      state: 'unknown',
      isParsed: true,
    })
  })

  test('keeps a row it cannot read instead of dropping it', () => {
    const [session] = parseListing('  something new the listing never said before')
    expect(session).toEqual({
      name: 'something new the listing never said before',
      kind: '',
      status: '',
      state: 'unknown',
      isParsed: false,
    })
  })

  test('reads names with spaces, rows without a ref, and CRLF line ends', () => {
    const sessions = parseListing(
      'Peer sessions (2):\r\n  my long name [ab12]  ·  interactive  ·  idle  ·  started 2m ago\r\n  bare-5158  ·  Remote Control  ·  busy\r\n',
    )
    expect(sessions.map(s => [s.name, s.kind, s.status])).toEqual([
      ['my long name', 'interactive', 'idle'],
      ['bare-5158', 'Remote Control', 'busy'],
    ])
  })
})

describe('groupOf', () => {
  test('finds the PM by its pm-<number> token', () => {
    expect(groupOf('serova-pm-5158-shane')).toEqual({ number: '5158', isPm: true })
    expect(groupOf('PM-1774-security')).toEqual({ number: '1774', isPm: true })
  })

  test('puts a worker in the group of its first 3+ digit token', () => {
    expect(groupOf('add-member-corova-5158')).toEqual({ number: '5158', isPm: false })
    expect(groupOf('tektons-9396-memebrdb')).toEqual({ number: '9396', isPm: false })
  })

  test('leaves short or absent numbers ungrouped', () => {
    expect(groupOf('infrastructure-94')).toBeNull()
    expect(groupOf('pixeljoy-esp32-6d')).toBeNull()
    expect(groupOf('tbagbuild')).toBeNull()
    expect(groupOf('Claude Code mods storage location')).toBeNull()
  })
})

describe('buildBoard', () => {
  test('groups workers under their PM and keeps the rest in Other', () => {
    const board = buildBoard(parseListing(ONE_WAITING))
    expect(
      board.groups.map(g => [g.number, g.pms.map(s => s.name), g.workers.map(s => s.name)]),
    ).toEqual([
      ['9396', [], ['tektons-9396-memebrdb']],
      ['5158', ['serova-pm-5158-shane'], ['add-member-corova-5158']],
      ['1774', ['meeting-pm-1774-security'], ['sec-2b-1774']],
    ])
    expect(board.other.map(s => s.name)).toEqual([
      'infrastructure-94',
      'pixeljoy-esp32-6d',
      'tbagbuild-server-setup',
      'Spawner',
      'tbagdev-help',
      'tbagbuild',
    ])
    expect(board.needsYou).toEqual([
      { session: expect.objectContaining({ name: 'tbagbuild-server-setup' }), pmName: null },
    ])
    expect(board.hasRemote).toBe(true)
  })

  test('puts a group with a waiting worker first and names its PM', () => {
    const board = buildBoard(parseListing(WORKER_WAITING))
    expect(board.groups[0]?.number).toBe('1774')
    expect(board.needsYou).toEqual([
      { session: expect.objectContaining({ name: 'sec-2b-1774' }), pmName: 'meeting-pm-1774-security' },
    ])
  })

  test('keeps every PM of a number', () => {
    const board = buildBoard(
      parseListing('  a-pm-1234 [1]  ·  Remote Control  ·  idle\n  b-pm-1234 [2]  ·  Remote Control  ·  idle'),
    )
    expect(board.groups[0]?.pms.map(s => s.name)).toEqual(['a-pm-1234', 'b-pm-1234'])
  })

  test('says when no Remote Control session is listed', () => {
    expect(buildBoard(parseListing(LOCAL_ONLY)).hasRemote).toBe(false)
  })

  test('never groups a row it could not read', () => {
    const board = buildBoard(parseListing('  odd row 1234 with no separators'))
    expect(board.groups).toEqual([])
    expect(board.other.length).toBe(1)
  })
})

describe('newlyWaiting', () => {
  test('names only sessions that were not already waiting', () => {
    const before = parseListing(ONE_WAITING)
    const after = parseListing(
      ONE_WAITING.replace('sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  idle', 'sec-2b-1774 [3b5d6b]  ·  Remote Control  ·  requires_action'),
    )
    expect(newlyWaiting(before, after)).toEqual(['sec-2b-1774'])
    expect(newlyWaiting(after, after)).toEqual([])
  })
})
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `claude plugin test mods/session-board`
Expected: FAIL — `../hooks/board` cannot be resolved.

- [ ] **Step 4: Implement the parser and grouping**

`mods/session-board/hooks/board.ts`:
```ts
import type { Board, Group, Session, SessionState } from '../types'

// A ListAgents row: `  <name> [<ref>]  ·  <kind>  ·  <status>[  ·  started …]`
const ROW = /^\s+(.+?)(?: \[[^\]]+\])?\s+·\s+(.+?)\s+·\s+([^\s·]+)(?:\s+·.*)?$/
const NUMBER = /^\d{3,}$/

const STATES: Record<string, SessionState> = {
  busy: 'working',
  running: 'working',
  waiting: 'needs-you',
  requires_action: 'needs-you',
  idle: 'idle',
}

export function parseListing(listing: string): Session[] {
  const sessions: Session[] = []
  for (const line of listing.split(/\r?\n/)) {
    if (!/^\s/.test(line) || line.trim() === '') continue
    const match = ROW.exec(line)
    if (match === null) {
      sessions.push({ name: line.trim(), kind: '', status: '', state: 'unknown', isParsed: false })
      continue
    }
    const status = match[3] ?? ''
    sessions.push({
      name: match[1] ?? '',
      kind: match[2] ?? '',
      status,
      state: STATES[status] ?? 'unknown',
      isParsed: true,
    })
  }
  return sessions
}

export function groupOf(name: string): { number: string; isPm: boolean } | null {
  const tokens = name.split('-')
  for (let i = 0; i + 1 < tokens.length; i++) {
    const next = tokens[i + 1] ?? ''
    if (tokens[i]?.toLowerCase() === 'pm' && NUMBER.test(next)) return { number: next, isPm: true }
  }
  const number = tokens.find(token => NUMBER.test(token))
  return number === undefined ? null : { number, isPm: false }
}

export function buildBoard(sessions: Session[]): Board {
  const groups = new Map<string, Group>()
  const other: Session[] = []
  for (const session of sessions) {
    const key = session.isParsed ? groupOf(session.name) : null
    if (key === null) {
      other.push(session)
      continue
    }
    const group = groups.get(key.number) ?? { number: key.number, pms: [], workers: [] }
    groups.set(key.number, group)
    if (key.isPm) group.pms.push(session)
    else group.workers.push(session)
  }

  const needsYou = sessions
    .filter(session => session.state === 'needs-you')
    .map(session => {
      const key = groupOf(session.name)
      const pm = key === null ? undefined : groups.get(key.number)?.pms[0]
      return { session, pmName: pm === undefined || pm === session ? null : pm.name }
    })

  const isWaiting = (group: Group) =>
    [...group.pms, ...group.workers].some(session => session.state === 'needs-you')
  const all = [...groups.values()]

  return {
    needsYou,
    groups: [...all.filter(isWaiting), ...all.filter(group => !isWaiting(group))],
    other,
    hasRemote: sessions.some(session => session.kind === 'Remote Control'),
  }
}

export function newlyWaiting(before: Session[], after: Session[]): string[] {
  const waited = new Set(before.filter(s => s.state === 'needs-you').map(s => s.name))
  return after.filter(s => s.state === 'needs-you' && !waited.has(s.name)).map(s => s.name)
}
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `claude plugin test mods/session-board`
Expected: `14 pass`, `0 fail`.

Run: `claude plugin validate mods/session-board`
Expected: `✔ Validation passed with warnings` (the only warning: no `version`, which is intended — the mod loads from the folder in place).

- [ ] **Step 6: Commit**

```bash
git add mods/session-board
git commit -m "mods: session-board listing parser and grouping"
```

---

### Task 2: `/board` command, polling, toasts and the pane

**Files:**
- Modify: `mods/session-board/hooks/register.tsx` (replace the stub)
- Create: `mods/session-board/tsconfig.json`
- Test: `mods/session-board/tests/pane.test.tsx`

**Interfaces:**
- Consumes: `parseListing`, `buildBoard`, `newlyWaiting` from `./board`; `Session`, `Snapshot` from `../types`; fixtures from `./fixtures`.
- Produces: the `/board` command; pane id `session-board`; `$.state` value `session-board.snapshot`.

- [ ] **Step 1: Write the failing engine tests**

`mods/session-board/tests/pane.test.tsx`:
```tsx
import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

import { ALL_IDLE, LOCAL_ONLY, ONE_WAITING, WORKER_WAITING } from './fixtures'

const SURFACES = ['terminal', 'desktop'] as const
const PANE = 'session-board'
const PANE_PROPS = {
  title: 'Sessions',
  isFocused: false,
  bodyColumns: 80,
  placement: 'dock' as const,
  scroll: { offset: 0, bodyRows: 40 },
}

type Answer = { listing: string } | { deny: string }

// The engine beneath the plugin: ListAgents answers from `answers` in turn (the
// last one repeats), the pane is open while `world.isOpen`, toasts are kept.
function engine(on: On, answers: Answer[], options: { isOpen?: boolean; delayMs?: number } = {}) {
  const clock = mock.clock(on, { now: Date.UTC(2026, 9, 8, 12, 0, 0) })
  const world = { isOpen: options.isOpen ?? false, calls: 0, toasts: [] as string[] }
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('command.register', (_$, e) => ({ value: { command: e.name } }))
  on('ui.open', () => {
    world.isOpen = true
    return { value: { isPlaced: true } }
  })
  on('ui.panes', () => ({
    value: world.isOpen
      ? [{ id: PANE, title: 'Sessions', isShown: true, isFocused: false, isPlaced: true }]
      : [],
  }))
  on('ui.toast', (_$, e) => {
    world.toasts.push(e.text)
    return { value: undefined }
  })
  on('tool.call', { tool: 'ListAgents' }, async () => {
    const answer = answers[Math.min(world.calls, answers.length - 1)] ?? { deny: 'no answer' }
    world.calls += 1
    if (options.delayMs !== undefined) await clock.sleep(options.delayMs)
    return 'deny' in answer ? answer : { result: { listing: answer.listing } }
  })
  return { clock, world }
}

const start = ($: Parameters<Parameters<typeof test>[1]>[0]) =>
  $.session.start({ cwd: '/work', surface: 'desktop', isInteractive: true })

const openBoard = ($: Parameters<Parameters<typeof test>[1]>[0]) =>
  $.command.run({
    command: 'board',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })

test('/board opens the pane and draws the waiting session, groups and Other', async ($, on) => {
  const { world } = engine(on, [{ listing: ONE_WAITING }])
  await start($)
  expect(await openBoard($)).toMatchObject({ text: 'Session board opened.' })
  expect(world.calls).toBe(1)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ plugin: 'session-board', surface, component: 'Pane', requestId: PANE, props: PANE_PROPS })
    expect(await ui.find({ type: 'Text', text: 'Needs you' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '  tbagbuild-server-setup' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '5158' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '  serova-pm-5158-shane  PM · idle' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '    add-member-corova-5158 · idle' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '9396  (no PM)' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Other' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^Updated \d\d:\d\d:\d\d$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /No Remote Control sessions/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('names the PM of a waiting worker', async ($, on) => {
  engine(on, [{ listing: WORKER_WAITING }])
  await start($)
  await openBoard($)
  const ui = await $.ui.mount({ plugin: 'session-board', surface: 'desktop', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  expect(await ui.find({ type: 'Text', text: '  sec-2b-1774  (meeting-pm-1774-security)' })).toBeDefined()
})

test('polls every 5 s and toasts a session that starts waiting, but not on the first poll', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ONE_WAITING }, { listing: ONE_WAITING }, { listing: WORKER_WAITING.replace('tbagbuild-server-setup [f9f708]  ·  Remote Control  ·  idle', 'tbagbuild-server-setup [f9f708]  ·  Remote Control  ·  requires_action') }])
  await start($)
  await openBoard($)
  expect(world.toasts).toEqual([])
  await clock.advance(5000)
  expect(world.calls).toBe(2)
  expect(world.toasts).toEqual([])
  await clock.advance(5000)
  expect(world.calls).toBe(3)
  expect(world.toasts).toEqual(['sec-2b-1774 needs you'])
})

test('stops polling once the pane is closed', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ALL_IDLE }])
  await start($)
  await openBoard($)
  world.isOpen = false
  await clock.advance(5000)
  await clock.advance(5000)
  await clock.advance(5000)
  expect(world.calls).toBe(1)
})

test('keeps the last good list and shows the error when ListAgents fails', async ($, on) => {
  const { clock } = engine(on, [{ listing: ONE_WAITING }, { deny: 'ListAgents is not available' }])
  await start($)
  await openBoard($)
  await clock.advance(5000)
  const ui = await $.ui.mount({ plugin: 'session-board', surface: 'desktop', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  expect(await ui.find({ type: 'Text', text: '  tbagbuild-server-setup' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^Last check failed at \d\d:\d\d:\d\d: ListAgents is not available$/ })).toBeDefined()
})

test('hints at Remote Control when only local sessions are listed', async ($, on) => {
  engine(on, [{ listing: LOCAL_ONLY }])
  await start($)
  await openBoard($)
  const ui = await $.ui.mount({ plugin: 'session-board', surface: 'terminal', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  expect(await ui.find({ type: 'Text', text: /No Remote Control sessions listed/ })).toBeDefined()
})

test('resumes polling when the pane is already open at session start (a reload)', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ALL_IDLE }], { isOpen: true })
  await start($)
  await clock.settle()
  expect(world.calls).toBe(1)
  await clock.advance(5000)
  expect(world.calls).toBe(2)
})

test('skips a tick while the previous ListAgents call is still running', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ALL_IDLE }], { delayMs: 7000 })
  await start($)
  const opened = openBoard($)
  await clock.advance(5000)
  expect(world.calls).toBe(1)
  await clock.advance(2000)
  await opened
  await clock.advance(5000)
  expect(world.calls).toBe(2)
})

test('/board again refreshes at once without a second timer', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ALL_IDLE }])
  await start($)
  await openBoard($)
  await openBoard($)
  expect(world.calls).toBe(2)
  await clock.advance(5000)
  expect(world.calls).toBe(3)
})
```

- [ ] **Step 2: Run them to see them fail**

Run: `claude plugin test mods/session-board`
Expected: the 14 Task 1 tests pass; the 9 `pane.test.tsx` tests FAIL (no `/board` command: `command.run` has nothing answering `board`).

- [ ] **Step 3: Implement the module**

`mods/session-board/hooks/register.tsx` (whole file):
```tsx
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Session, Snapshot } from '../types'
import { buildBoard, newlyWaiting, parseListing } from './board'

const PANE = 'session-board'
const POLL_MS = 5000
const EMPTY: Snapshot = { sessions: [], checkedAt: null, error: null }
const SNAPSHOT = { plugin: 'session-board', key: 'snapshot' } as const
const snapshot = atom(SNAPSHOT, EMPTY)

const LABEL: Record<Session['state'], string> = {
  working: 'working',
  'needs-you': 'needs you',
  idle: 'idle',
  unknown: '',
}

const clockTime = (ms: number) => new Date(ms).toTimeString().slice(0, 8)

async function readListing($: EngineInterface): Promise<string> {
  const ran = await $.tool.call({ tool: 'ListAgents' })
  if (ran.deny !== undefined) throw new Error(ran.deny)
  if (ran.isError === true) throw new Error(ran.text ?? 'ListAgents failed')
  const listing = (ran.result as { listing?: unknown } | undefined)?.listing
  if (typeof listing !== 'string') throw new Error('ListAgents returned no listing')
  return listing
}

let timer: Timer | null = null
let isPolling = false

async function poll($: EngineInterface): Promise<void> {
  if (isPolling) return
  isPolling = true
  try {
    const now = await $.clock.now()
    const { value: before = EMPTY } = await $.state.get(SNAPSHOT)
    let sessions: Session[]
    try {
      sessions = parseListing(await readListing($))
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      await update($, snapshot, current => ({ ...current, error: { message, at: now } }))
      return
    }
    if (before.checkedAt !== null) {
      for (const name of newlyWaiting(before.sessions, sessions)) $.ui.toast(`${name} needs you`)
    }
    await update($, snapshot, () => ({ sessions, checkedAt: now, error: null }))
  } finally {
    isPolling = false
  }
}

async function tick($: EngineInterface): Promise<void> {
  const isOpen = (await $.ui.panes()).some(pane => pane.id === PANE)
  if (!isOpen) {
    timer?.cancel()
    timer = null
    return
  }
  await poll($)
}

async function startPolling($: EngineInterface): Promise<void> {
  if (timer === null) timer = $.clock.every(POLL_MS, () => void tick($))
  await poll($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'board',
      description: 'Show running sessions grouped under their PM',
    })
    const started = await next(e)
    if ((await $.ui.panes()).some(pane => pane.id === PANE)) void startPolling($)
    return started
  })

  on('command.run', { command: 'board' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Sessions' })
    await startPolling($)
    return { text: 'Session board opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const snap = await read($, snapshot)
    const board = buildBoard(snap.sessions)

    const row = (session: Session, indent: string, tag: string) => {
      const label = session.isParsed ? LABEL[session.state] || session.status : ''
      const style =
        session.state === 'needs-you'
          ? { color: 'yellow', bold: true }
          : session.state === 'idle'
            ? { dimColor: true }
            : {}
      return (
        <Text {...style}>
          {indent}
          {session.name}
          {tag}
          {label === '' ? '' : ` · ${label}`}
        </Text>
      )
    }

    return (
      <Box flexDirection="column">
        {board.needsYou.length > 0 && (
          <Box key="needs-you" flexDirection="column">
            <Text bold color="yellow">
              Needs you
            </Text>
            {board.needsYou.map(({ session, pmName }) => (
              <Text color="yellow">
                {'  '}
                {session.name}
                {pmName === null ? '' : `  (${pmName})`}
              </Text>
            ))}
          </Box>
        )}
        {board.groups.map(group => (
          <Box key={`group-${group.number}`} flexDirection="column">
            <Text bold>
              {group.number}
              {group.pms.length === 0 ? '  (no PM)' : ''}
            </Text>
            {group.pms.map(session => row(session, '  ', '  PM'))}
            {group.workers.map(session => row(session, '    ', ''))}
          </Box>
        ))}
        {board.other.length > 0 && (
          <Box key="other" flexDirection="column">
            <Text bold>Other</Text>
            {board.other.map(session => row(session, '  ', ''))}
          </Box>
        )}
        {snap.checkedAt !== null && snap.sessions.length === 0 && (
          <Text dimColor>No other sessions running.</Text>
        )}
        {snap.checkedAt !== null && !board.hasRemote && (
          <Text dimColor>
            No Remote Control sessions listed. Turn on Remote Control in this session to see your
            other machines.
          </Text>
        )}
        {snap.error !== null && (
          <Text dimColor>
            Last check failed at {clockTime(snap.error.at)}: {snap.error.message}
          </Text>
        )}
        <Text dimColor>
          {snap.checkedAt === null ? 'Checking…' : `Updated ${clockTime(snap.checkedAt)}`}
        </Text>
      </Box>
    )
  })
}
```

`mods/session-board/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "es2023", "lib": ["es2023"], "types": [],
    "module": "esnext", "moduleResolution": "bundler",
    "strict": true, "noUncheckedIndexedAccess": true,
    "noEmit": true, "skipLibCheck": true,
    "jsx": "react", "jsxFactory": "h", "jsxFragmentFactory": "Fragment"
  },
  "include": [".claude-plugin/types", "hooks", "types", "tests"]
}
```

- [ ] **Step 4: Run the tests and the validator**

Run: `claude plugin test mods/session-board`
Expected: `23 pass`, `0 fail`.

Run: `claude plugin validate mods/session-board`
Expected: `✔ Validation passed with warnings`, and its notes list `calls: $.clock.every (via startPolling), $.clock.now (via poll), $.command.register, $.state.get (via poll), $.state.set, $.tool.call (via readListing), $.ui.open, $.ui.panes, $.ui.resolve, $.ui.toast (via poll)`.

- [ ] **Step 5: Type-check if TypeScript is installed**

Run: `npx --no-install tsc --version`
If that fails, TypeScript isn't installed: skip this step and say so in your report (do not install it). Otherwise run `npx --no-install tsc -p mods/session-board`; it type-checks only once Claude Code has loaded the mod and written `.claude-plugin/types/`, so if it reports `claude-code` as an unknown module, say so in your report and move on.

- [ ] **Step 6: Commit**

```bash
git add mods/session-board
git commit -m "mods: session-board /board pane polling ListAgents"
```

---

### Task 3: Link mods from `setup.sh`, ignore generated types, document

**Files:**
- Modify: `setup.sh` (whole file below)
- Create: `.gitignore`
- Modify: `README.md` (new `mods/` section after the `skills/` section; install line)

**Interfaces:**
- Consumes: `mods/session-board/.claude-plugin/plugin.json` from Task 1.
- Produces: `./setup.sh` links every `mods/*/` holding `.claude-plugin/plugin.json` into `~/.claude/skills/`.

- [ ] **Step 1: Write the check script and see it fail**

Run from the repo root:
```bash
TMP_HOME="$(mktemp -d)"
HOME="$TMP_HOME" ./setup.sh
test "$(readlink "$TMP_HOME/.claude/skills/session-board")" = "$PWD/mods/session-board" && echo "LINKED"
test -L "$TMP_HOME/.claude/skills/tdk-1-start" && echo "SKILLS STILL LINKED"
HOME="$TMP_HOME" ./setup.sh | grep -q "0 linked" && echo "IDEMPOTENT"
mkdir -p "$TMP_HOME/other/.claude/skills/session-board"
HOME="$TMP_HOME/other" ./setup.sh | grep -q "session-board: real directory" && echo "CONFLICT KEPT"
rm -rf "$TMP_HOME"
```
Expected before the change: `SKILLS STILL LINKED` only (no `LINKED`, no `CONFLICT KEPT`; `IDEMPOTENT` may print).

- [ ] **Step 2: Rewrite `setup.sh`**

`setup.sh` (whole file; the skill loop's body moves into `link()`, a second loop covers mods):
```bash
#!/usr/bin/env bash
# Machine setup for this toolkit: symlink every skill in skills/ and every mod in
# mods/ into ~/.claude/skills so Claude Code discovers them (a folder there holding
# .claude-plugin/plugin.json loads as a plugin). Idempotent — run it after every
# pull that adds a skill or mod; existing correct links are just refreshed.
#
#   git clone git@github.com:theunisdk/ai-dev.git && cd ai-dev && ./setup.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_ROOT="$HOME/.claude/skills"
mkdir -p "$DEST_ROOT"

linked=0; kept=0; conflicts=0

link() {
  local src="$1" name dest
  name="$(basename "$src")"
  dest="$DEST_ROOT/$name"

  if [ -L "$dest" ]; then
    ln -sfn "${src%/}" "$dest"
    kept=$((kept + 1))
  elif [ -e "$dest" ]; then
    # A real directory here means a local copy that may have diverged from the
    # repo — exactly the drift this script exists to prevent. Never clobber it.
    echo "  ! $name: real directory at $dest — compare with 'diff -r', then"
    echo "      rm -rf '$dest' and re-run to adopt the repo copy"
    conflicts=$((conflicts + 1))
  else
    ln -sn "${src%/}" "$dest"
    echo "  + linked $name"
    linked=$((linked + 1))
  fi
}

for src in "$REPO_DIR"/skills/*/; do
  [ -f "$src/SKILL.md" ] && link "$src"
done
for src in "$REPO_DIR"/mods/*/; do
  [ -f "$src/.claude-plugin/plugin.json" ] && link "$src"
done

echo "skills and mods: $linked linked, $kept refreshed, $conflicts conflict(s)"

command -v codex >/dev/null 2>&1 || echo "note: codex CLI not on PATH — the review kit needs it (then: codex login)"
command -v jq >/dev/null 2>&1 || echo "note: jq not installed — the review kit needs it"
exit 0
```

- [ ] **Step 3: Run the check script again**

Run the Step 1 script again.
Expected: `LINKED`, `SKILLS STILL LINKED`, `IDEMPOTENT`, `CONFLICT KEPT`.

- [ ] **Step 4: Ignore the generated types and document mods**

`.gitignore`:
```
mods/*/.claude-plugin/types/
```

`README.md`: insert this section directly before `### [wsl-cli-tools/](wsl-cli-tools/)`:
```markdown
### [mods/](mods/)

Claude Code mods: plugins whose function hooks draw UI inside Claude Code (the
terminal and the desktop Code tab). `./setup.sh` links each one into
`~/.claude/skills/`, where Claude Code loads it as a plugin in every session; in
a session that is already open, run `/reload-plugins` to pick up a new one.

| Mod | Purpose |
|-----|---------|
| `session-board` | `/board` opens a pane listing running sessions grouped under their PM (`<project>-pm-<number>-…`, workers carry the same number), with the ones waiting on you on top. The session showing it needs Remote Control on to see other machines |
```

and in the `skills/` section change the install sentence's opening from

```markdown
Install all skills on a machine: `./setup.sh` (idempotent — re-run after any
pull; it symlinks every skill into `~/.claude/skills` and never clobbers a
```

to

```markdown
Install all skills and mods on a machine: `./setup.sh` (idempotent — re-run after any
pull; it symlinks every skill and mod into `~/.claude/skills` and never clobbers a
```

- [ ] **Step 5: Confirm the whole mod still passes**

Run: `claude plugin test mods/session-board && claude plugin validate mods/session-board`
Expected: `23 pass`, `0 fail`; `✔ Validation passed with warnings`.

- [ ] **Step 6: Commit**

```bash
git add setup.sh .gitignore README.md
git commit -m "setup: link mods into ~/.claude/skills; document mods/"
```

---

### After the tasks (controller, with the user)

Run the real `./setup.sh`, have the user run `/reload-plugins` then `/board` in a session with Remote Control on, and compare the pane with `ListAgents`.
