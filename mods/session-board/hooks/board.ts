import type { Board, Group, Session, SessionState } from '../types'

// A ListAgents row: `  <name> [<ref>]  ·  <kind>  ·  <status>[  ·  started …]`
const ROW = /^\s*(?:[-*]\s+)?(.+?)(?: \[[^\]]+\])?\s+·\s+(.+?)\s+·\s+([^\s·]+)(?:\s+·.*)?$/
const HEADER = /^(\S.*?) \(\d+\):$/
const SKIPPED_SECTION = /^(subagents|teammates)/i
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
  let isSkipped = false
  for (const line of listing.split(/\r?\n/)) {
    const header = HEADER.exec(line)
    if (header !== null) isSkipped = SKIPPED_SECTION.test(header[1] ?? '')
    if (isSkipped || line.trim() === '') continue
    if (!/^\s/.test(line) && !line.includes(' · ')) continue
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
