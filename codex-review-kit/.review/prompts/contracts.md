# Your lens: CONTRACTS, COMPATIBILITY & MIGRATIONS

Everything here is about breaking something outside this repository's HEAD:
deployed clients, other services, historical data, or the previous release still
running during a rolling deploy.

Hunt specifically for:

- **API breaking changes** — a removed or renamed field, a widened or narrowed
  type, a field that became required, a status code or error shape change, a
  changed default, an altered pagination or sort contract. Check whether the
  change is versioned; if not, that is the finding.
- **Schema and event payloads** — changes to queue messages, webhooks, pub/sub
  events, or protobuf/Avro schemas that old consumers cannot parse. Removing a
  field from a producer before every consumer stops reading it.
- **Database migrations** — non-backwards-compatible changes deployed in one step
  (drop or rename a column still read by the running version); `NOT NULL` added
  without a default or backfill; a new index created without `CONCURRENTLY` on a
  large table; a migration that takes a long lock on a hot table; a data migration
  with no batching; no down-migration or a down-migration that loses data;
  migration and code change that must be deployed together but cannot be.
- **Config and environment** — a new required env var or config key with no
  default and no documentation, so the next deploy crashes on boot; a changed
  default that silently alters behaviour in environments that never set it.
- **Persistence format drift** — a serialised structure (cache entry, session
  blob, stored JSON) whose shape changed while old records still exist. What
  happens when the new code reads an old record?
- **Cross-repo and public surface** — changes to a shared library's exported
  symbols, a CLI flag, a published SDK, or anything with consumers you cannot see.
- **Feature flags** — new behaviour behind no flag, or a flag with no off path.

For each finding, name what breaks and at what moment: "during rolling deploy,
old pods reading the new row shape will…"
