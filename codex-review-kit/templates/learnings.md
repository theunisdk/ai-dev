<!--
Accumulated review memory. Injected verbatim into every Codex lens prompt.

Two kinds of entry:
  SUPPRESS — a class of finding this repo does not want. Added by /review-tune
             when the same rejection reason recurs.
  WATCH    — a class of defect that reached CodeRabbit or production because the
             local pass missed it. Added by /review-postmortem.

Keep entries short and specific. Prune anything stale. If this file grows past
roughly 60 lines it is diluting every prompt — consolidate.
-->

## Repository facts
<!-- Durable context a reviewer needs and cannot infer quickly. Examples: -->
<!-- - `src/legacy/` is frozen; report only critical findings there. -->
<!-- - All DB access goes through `repo/` — direct driver use is intentional in `scripts/`. -->

## SUPPRESS
<!-- - Do not report missing input validation in `handlers/internal/` — it runs behind the mesh. -->

## WATCH
<!-- - 2026-03-12: missed an unclosed DB connection on the error path in a retry helper. -->
