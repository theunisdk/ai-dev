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
