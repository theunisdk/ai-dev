# Your lens: CONFLICTS — WITH THE RULES, THE CODE, AND ITSELF

A spec can be complete, unambiguous, and still wrong: it collides with an
invariant the repository already enforces, another document, or its own
earlier paragraphs.

Hunt specifically for:

- **House-rule violations** — read `.review/rubric.md` first. A spec that
  requires code the rubric forbids (the wrong data representation, a bypassed
  seam, an unsanctioned access pattern) is a finding at the severity the rule
  carries, even though no code exists yet. Cite the rule.
- **Collisions with enforced invariants** — the codebase enforces things the
  rubric may not spell out: lint rules, guard tests, CI gates, schema
  constraints. Find the enforcement mechanism the specced design would trip.
- **Contradictions with existing behaviour** — the spec redefines semantics
  an existing feature already gives some concept (a status, a permission, a
  calculation) without acknowledging the change or its consumers.
- **Contradictions with sibling documents** — decision logs, other specs and
  plans in the same tree. Two documents that disagree will be implemented in
  whichever order maximises the damage.
- **Internal contradictions** — section 5 forbids what section 2 promised;
  an example that doesn't match its own rule; numbers that don't add up.
- **Unacknowledged breaking changes** — the specced behaviour alters an API
  shape, an event payload, or a stored format that existing code (find it)
  still depends on.

For each finding, cite both sides of the collision — the spec passage
(file:line) and the rule, code, or passage it conflicts with.
