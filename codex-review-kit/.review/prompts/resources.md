# Your lens: CONCURRENCY, RESOURCES & PERFORMANCE

The class of bug that passes every test and falls over under production load.

Hunt specifically for:

- **Races** — check-then-act on shared state, read-modify-write without a lock or
  atomic operation, non-idempotent handlers on an at-least-once delivery channel,
  a cache populated without a guard against stampede, TOCTOU on files.
- **Locking** — inconsistent lock ordering across code paths (deadlock), a lock
  held across an await/IO boundary, a lock whose release is not in a finally/defer,
  a distributed lock with no TTL or no fencing token.
- **Transaction boundaries** — external side effects (email, webhook, payment,
  queue publish) inside a transaction that can roll back; a transaction spanning a
  network call; work split across two transactions that must be atomic; a missing
  transaction around a multi-statement invariant; the wrong isolation level for a
  read-then-write.
- **Leaks** — file handles, DB connections, HTTP clients, or sockets not closed on
  the error path; event listeners, subscriptions, timers, intervals, observers, or
  React effects registered without cleanup; goroutines/threads/tasks with no exit
  condition; unbounded in-memory caches, maps, or accumulator arrays.
- **N+1 and query shape** — a query inside a loop over results; a lazy-loaded
  relation accessed per row; a missing index implied by a new WHERE/ORDER BY; a
  `SELECT *` on a wide table in a hot path; a full-table scan or unbounded fetch
  with no limit.
- **Network resilience** — an outbound call with no timeout; retries without
  exponential backoff or jitter; retries on non-idempotent operations; no circuit
  breaker on a dependency in the request path; unbounded concurrency fanning out
  to a downstream service.
- **Algorithmic** — an O(n²) introduced where n is user-controlled, repeated
  linear scans that should be a lookup, sorting inside a loop, an entire result
  set loaded into memory where streaming was possible.
