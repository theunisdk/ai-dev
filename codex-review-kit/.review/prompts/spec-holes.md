# Your lens: HOLES — WHAT THE SPEC DOESN'T SAY

The cases the happy-path narrative skips. Each one will be discovered
mid-build and resolved by whoever hits it, under deadline, without review.

Hunt specifically for:

- **Unhandled failure paths** — what happens when the external call fails,
  the record is missing, the user lacks the permission, the payment bounces,
  the job dies halfway? If the spec describes only success, name the failure
  that matters most.
- **Undefined states and transitions** — the spec introduces a state machine
  (explicitly or by implication) but not every entry/exit; what happens to
  in-flight entities when the feature ships; what a rollback leaves behind.
- **Boundary and volume cases** — empty set, exactly one, duplicates,
  maximums, concurrent actors doing the specced flow at once, the same action
  performed twice.
- **Data lifecycle gaps** — creation is specced but not edit, delete,
  expiry, or audit; what happens to existing rows when a shape changes;
  backfill for the data that predates the feature.
- **Missing acceptance criteria** — behaviour described with no way to tell
  if it was built correctly. Name the assertion the spec should contain.
- **Sequencing and rollout holes** — steps that must land in an order the
  spec doesn't state; a migration and code that cannot deploy together;
  feature exposure before its permissions exist.
- **Unspecified integration edges** — the spec's feature touches an existing
  flow (check the code) but doesn't say how the two interact.

Report the hole, why it is load-bearing (not merely conceivable), and the
single question the spec must answer to close it.
