---
name: tdk-start
description: Use this skill when the user says "tdk-start", "tdk start", or wants to kick off a new working session. It reminds Claude to read the README.md and docs/INDEX.md for project context, and to confirm the starting branch, before doing anything else.
user-invocable: true
---

# TDK Start

When this skill is invoked, respond with:

> "Read the README.md and docs/INDEX.md for context before we start."

Then, before proceeding with any other work:

1. Read `README.md` in the current working directory.
2. Read `docs/INDEX.md` if it exists.
3. Ask whether to branch off `dev` before starting.
