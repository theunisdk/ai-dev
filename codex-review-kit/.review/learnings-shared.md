<!--
Kit-wide review memory, shared by EVERY repo that syncs this kit. Injected into
every lens prompt ahead of the repo's own learnings.md.

What belongs here: lessons that hold in any repo (generic review blind spots)
or in any repo on a given stack (mark with a "stack:" prefix). What does NOT:
anything naming a repo, a client, a schema, or an incident — that goes in the
repo's own .review/learnings.md and never leaves it. This file lives in a
PUBLIC repository; write accordingly.

Same hygiene as learnings.md: short entries, prune stale ones, consolidate
before this file dilutes the prompts it feeds.
-->

## SUPPRESS

## WATCH
- stack:eslint9 — eslint 9 removed all non-core output formatters (`unix`,
  `compact`, …); tooling that passes `--format unix` fails silently under
  `2>/dev/null`. Check the analyzer report actually has an eslint section
  before assuming lint ran.
