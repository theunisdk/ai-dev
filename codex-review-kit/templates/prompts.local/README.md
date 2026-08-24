# Repo-owned lens overlays

Drop a `<lens>.md` here (`correctness.md`, `security.md`, `contracts.md`,
`resources.md`, `tests.md`, `scope.md`, or any custom lens) and the runner
appends it to that lens's shared prompt on every run.

This is where repo-specific hazards live, so the shared prompts in
`.review/prompts/` stay pristine and updatable via `scripts/review-update.sh`.
Never edit the shared prompts in a repo — the next sync overwrites them.

Convention: start each fragment with

    In this repository, additionally hunt for:

followed by a short, concrete bullet list. Name files, functions, and the
failure mode; don't restate the generic lens. If a hazard would apply to any
repo on your stack, it belongs in the kit's `learnings-shared.md` or base
prompts instead — send it upstream.
