import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Session, Snapshot } from '../types'
import { buildBoard, newlyWaiting, parseListing } from './board'

const PANE = 'session-board'
const POLL_MS = 5000
const EMPTY: Snapshot = { sessions: [], checkedAt: null, error: null }
const SNAPSHOT = { plugin: 'session-board', key: 'snapshot' } as const
const snapshot = atom(SNAPSHOT, EMPTY)

const STATE_VIEW: Record<Session['state'], { label: string; style: Record<string, unknown> }> = {
  working: { label: '● working', style: { color: 'success' } },
  'needs-you': { label: '▲ needs you', style: { color: 'warning', bold: true } },
  idle: { label: '○ idle', style: { dimColor: true } },
  unknown: { label: '', style: {} },
}

const clockTime = (ms: number) => new Date(ms).toTimeString().slice(0, 8)
const plural = (count: number, noun: string) => `${count} ${noun}${count === 1 ? '' : 's'}`

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

async function poll($: EngineInterface, isQuiet = false): Promise<void> {
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
    if (before.checkedAt !== null && !isQuiet) {
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

async function startPolling($: EngineInterface, isQuiet = false): Promise<void> {
  if (timer === null) timer = $.clock.every(POLL_MS, () => void tick($))
  await poll($, isQuiet)
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
    const wasOpen = (await $.ui.panes()).some(pane => pane.id === PANE)
    await $.ui.open({ id: PANE, title: 'Sessions' })
    await startPolling($, !wasOpen)
    return { text: 'Session board opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const snap = await read($, snapshot)
    const board = buildBoard(snap.sessions)

    const row = (key: string, session: Session, branch: string, isPm = false) => {
      const view = STATE_VIEW[session.state]
      const label = view.label || (session.isParsed ? session.status : '')
      return (
        <Box key={key} justifyContent="space-between" columnGap={2}>
          <Box flexShrink={1}>
            <Text dimColor>{branch}</Text>
            <Text wrap="truncate-end">{session.name}</Text>
            {isPm && <Text dimColor> PM</Text>}
          </Box>
          <Text {...view.style}>{label}</Text>
        </Box>
      )
    }
    const ruleWidth = Math.max(0, e.props.bodyColumns - 2)

    return (
      <Box flexDirection="column" rowGap={1} paddingX={1}>
        {board.needsYou.length > 0 && (
          <Box key="needs-you" flexDirection="column" borderStyle="round" borderColor="warning" paddingX={1}>
            <Text bold color="warning">
              ▲ Needs you · {board.needsYou.length}
            </Text>
            {board.needsYou.map(({ session, pmName }, i) => (
              <Box key={`wait-${i}`} justifyContent="space-between" columnGap={2}>
                <Text color="warning" wrap="truncate-end">
                  {session.name}
                </Text>
                <Text dimColor>{pmName ?? ''}</Text>
              </Box>
            ))}
          </Box>
        )}
        {board.groups.map(group => (
          <Box key={`group-${group.number}`} flexDirection="column">
            <Box>
              <Text bold color="suggestion">
                {group.number}
              </Text>
              {group.pms.length === 0 && <Text dimColor> · no PM running</Text>}
            </Box>
            {group.pms.map((session, i) => row(`pm-${group.number}-${i}`, session, '  ◆ ', true))}
            {group.workers.map((session, i) =>
              row(
                `worker-${group.number}-${i}`,
                session,
                i === group.workers.length - 1 ? '    └ ' : '    ├ ',
              ),
            )}
          </Box>
        ))}
        {board.other.length > 0 && (
          <Box key="other" flexDirection="column">
            <Text bold dimColor>
              Other
            </Text>
            {board.other.map((session, i) => row(`other-${i}`, session, '  '))}
          </Box>
        )}
        <Box key="footer" flexDirection="column">
          <Text dimColor wrap="truncate-end">
            {'─'.repeat(ruleWidth)}
          </Text>
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
            {snap.checkedAt !== null
              ? `Updated ${clockTime(snap.checkedAt)} · ${plural(snap.sessions.length, 'session')}`
              : snap.error !== null
                ? 'Not updated yet'
                : 'Checking…'}
          </Text>
        </Box>
      </Box>
    )
  })
}
