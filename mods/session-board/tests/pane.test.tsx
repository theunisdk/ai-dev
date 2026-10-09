import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

import { ALL_IDLE, LOCAL_ONLY, ONE_WAITING, TODAY, WORKER_WAITING } from './fixtures'

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
    expect(await ui.find({ type: 'Text', text: '▲ Needs you · 1' })).toBeDefined()
    expect((await ui.find({ key: 'wait-0' }))?.text).toMatch(/tbagbuild-server-setup/)
    expect(await ui.find({ type: 'Text', text: '5158' })).toBeDefined()
    expect((await ui.find({ key: 'pm-5158-0' }))?.text).toMatch(/◆ serova-pm-5158-shane.*PM.*○ idle/)
    expect((await ui.find({ key: 'worker-5158-0' }))?.text).toMatch(/└ add-member-corova-5158.*○ idle/)
    expect(await ui.find({ type: 'Text', text: ' · no PM running' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Other' })).toBeDefined()
    expect((await ui.find({ key: 'other-1' }))?.text).toMatch(/pixeljoy-esp32-6d.*● working/)
    expect((await ui.find({ key: 'other-2' }))?.text).toMatch(/tbagbuild-server-setup.*▲ needs you/)
    expect(await ui.find({ type: 'Text', text: /^Updated \d\d:\d\d:\d\d · 11 sessions$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /No Remote Control sessions/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('draws workers on tree lines, the last one closing the branch', async ($, on) => {
  engine(on, [{ listing: TODAY }])
  await start($)
  await openBoard($)
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ plugin: 'session-board', surface, component: 'Pane', requestId: PANE, props: PANE_PROPS })
    expect((await ui.find({ key: 'pm-9396-0' }))?.text).toMatch(/◆ tektons-pm-9396-memebrdb/)
    expect((await ui.find({ key: 'worker-9396-0' }))?.text).toMatch(/├ member-site-9396/)
    expect((await ui.find({ key: 'worker-9396-1' }))?.text).toMatch(/└ member-app-9396/)
    expect(await ui.find({ type: 'Text', text: '▲ Needs you · 2' })).toBeDefined()
    await ui.unmount()
  }
})

test('names the PM of a waiting worker', async ($, on) => {
  engine(on, [{ listing: WORKER_WAITING }])
  await start($)
  await openBoard($)
  const ui = await $.ui.mount({ plugin: 'session-board', surface: 'desktop', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  expect((await ui.find({ key: 'wait-0' }))?.text).toMatch(/sec-2b-1774.*meeting-pm-1774-security/)
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
  expect((await ui.find({ key: 'wait-0' }))?.text).toMatch(/tbagbuild-server-setup/)
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

test('does not toast for sessions already shown when /board reopens the pane', async ($, on) => {
  const { clock, world } = engine(on, [{ listing: ONE_WAITING }, { listing: WORKER_WAITING }, { listing: WORKER_WAITING.replace('tbagdev-help [5e23ee]  ·  Remote Control  ·  idle', 'tbagdev-help [5e23ee]  ·  Remote Control  ·  requires_action') }])
  await start($)
  await openBoard($)
  world.isOpen = false
  await clock.advance(5000)
  await openBoard($)
  expect(world.toasts).toEqual([])
  await clock.advance(5000)
  expect(world.toasts).toEqual(['tbagdev-help needs you'])
})

test('says it has not updated when the first check fails', async ($, on) => {
  engine(on, [{ deny: 'ListAgents is not available' }])
  await start($)
  await openBoard($)
  const ui = await $.ui.mount({ plugin: 'session-board', surface: 'desktop', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  expect(await ui.find({ type: 'Text', text: /^Last check failed at/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Not updated yet' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Checking…' })).toBeUndefined()
})
