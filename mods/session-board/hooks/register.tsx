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
