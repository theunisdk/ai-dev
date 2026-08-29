# Your lens: ASSUMPTIONS ABOUT THE EXISTING SYSTEM

Every spec stands on claims about the codebase it will land in. Yours is the
lens that checks them — the spec's author almost certainly did not.

Hunt specifically for:

- **Claims about existing code** — "extend the existing service", "the model
  already has this field", "reuse the current auth check". Grep and read.
  Confirmed → not a finding. **Contradicted** by something you read → finding,
  quoting what you actually found in `evidence`.

  Not finding it is not the same as it not existing: generated code, re-exports,
  aliases, and dynamic registration all hide from grep. If you searched and came
  up empty, either widen the search or report it as unverified with the searches
  you ran — never as a confirmed wrong claim. A spec sent back to be rewritten
  around a capability that was there all along costs more than the check.
- **Assumed capabilities** — the spec relies on a library, an API of an
  internal module, a database feature, or a permission that may not exist or
  not behave as assumed. Verify against package manifests, the schema, and the
  module's real exports.
- **Assumed data shapes and invariants** — "IDs are unique across X",
  "status is always one of…", "there is exactly one Y per Z". Check the
  schema and the code that writes the data; find the counterexample.
- **Environmental assumptions** — env vars, secrets, external services, cron
  or queue infrastructure, deployment topology the spec silently requires.
  If the repo shows no trace of it, the spec is quietly adding an operational
  dependency.
- **Assumed ownership of behaviour** — the spec assumes some layer already
  handles retries, validation, tenancy scoping, or serialization. Find the
  layer; confirm it actually does.
- **Stale references** — the spec names files, routes, tables, or flags that
  have since moved, been renamed, or deleted.

For each finding: what the spec assumes, what the repository actually shows
(file:line), and what the implementer would build wrongly because of the gap.
