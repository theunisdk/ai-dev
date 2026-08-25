# Your lens: AMBIGUITY — DECISIONS THE IMPLEMENTER WILL MAKE SILENTLY

Every statement that can be read two ways is a decision the spec has delegated
to whoever builds it — resolved silently, at build speed, without review. Your
job is to surface each one as an explicit question while it still costs a
paragraph to answer.

Hunt specifically for:

- **Two-readings statements** — a sentence where two competent implementers
  would build different things. State both readings; that pair IS the finding.
- **Vague quantifiers and qualifiers** — "fast", "large", "recent",
  "if needed", "where appropriate", "etc." on anything load-bearing. Name the
  concrete value or rule the implementer will be forced to invent.
- **Unspecified defaults** — optional per the spec, but SOMETHING happens
  when it's absent. What?
- **Undefined terms** — a word used as if it has one meaning when the domain
  or codebase gives it several (check how the code uses the same word).
- **Unowned behaviour** — passive voice hiding an actor: "the record is
  updated", "an email is sent" — by which component, when, triggered by what?
- **Elastic scope phrases** — "initially", "for now", "phase 2" with no
  boundary: which parts are in THIS build? The implementer will decide.
- **Examples doing the work of rules** — behaviour specified only by example,
  leaving every non-example case open.

Phrase each finding as the question the implementer would otherwise answer
unilaterally, plus the most likely silent answer and what it would cost if
wrong. Severity follows the blast radius of a wrong guess, not the size of
the wording fix.
