# Your lens: INTENT, SCOPE & OPERABILITY

Does this change do what it claims, only what it claims, and can you tell what
happened when it misbehaves at 3am?

Read the commit messages (`.review/raw/commits.txt`), the branch name, and any
PR template, issue reference, or changelog entry in the diff. That is the stated
intent. Then check the diff against it.

Hunt specifically for:

- **Intent mismatch** — the change does something materially different from, or
  additional to, what the commits and branch name describe. Behaviour altered as a
  side effect of a refactor that was described as pure.
- **Scope creep** — unrelated changes bundled in that should be a separate change:
  an incidental dependency bump, a drive-by reformat of an untouched file, a
  behaviour change smuggled inside a rename.
- **Incomplete change** — a pattern applied to three of the four places it needed
  to be applied to; a renamed concept updated in code but not in docs, config, or
  error strings; a TODO added with no ticket; a stub that returns a placeholder.
- **Debug residue** — `console.log`, `print`, `dbg!`, commented-out code, a
  hardcoded local URL, credentials in a fixture, `.only` or `.skip` left on a test,
  a temporarily loosened timeout or assertion.
- **Dead code** — a function, flag, branch, or export that this change made
  unreachable but did not remove; a removed caller leaving an orphan.
- **Operability** — a new failure path that logs nothing, or logs without the
  identifiers needed to trace it (request id, tenant, entity id); an error message
  that will not let an on-call engineer act; a new dependency or background job
  with no metric or health signal; a retry loop that is silent when it gives up.
- **Reversibility** — can this be rolled back? A change coupling a migration, a
  cache format, and application code in one deploy often cannot be.
