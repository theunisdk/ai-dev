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
