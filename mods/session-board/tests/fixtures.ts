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
