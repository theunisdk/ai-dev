---
name: tdk-1-start
description: Use at the start of every conversation to load project context. Triggers when the user says "start", "begin", "let's go", "tdk-1-start", "tdk-start", or any variation of wanting to kick off a session. Always use this skill when beginning work on a project to ensure you have full context before proceeding.
---

# TDK Start

Read the README.md in the current working directory to understand the project context before doing anything else.

## Steps

1. Use the Read tool to read `README.md` from the project root
2. Briefly summarize the key context you learned (1-3 sentences)
3. Ask the user what they'd like to work on

If no README.md exists, let the user know and ask how they'd like to proceed.
