---
name: nldr-setup-docs-ci
description: Use when the user wants PR-triggered documentation updates wired into a repo — "add the pr docs flow", "auto-update docs on PR", "set up docs CI", or adding Claude-powered doc automation to GitHub Actions for the first time.
user-invocable: true
---

# NLDR Setup Docs CI

Install a GitHub Actions workflow that runs the `nldr-pr-docs` skill on every pull request, so documentation is updated automatically as part of the PR.

## Prerequisites (verify, don't assume)

1. Repo is on GitHub with Actions enabled (`gh repo view --json name,owner` works).
2. Project docs exist (`docs/INDEX.md` with a `docs-level` marker). If not, offer to run `nldr-gen-docs-light` or `nldr-gen-docs` first — the CI flow is useless without a baseline.

## Installation checklist

Work through ALL of these; report each as done/blocked:

### 1. Vendor the skill into the repo
CI runners don't have the user's `~/.claude/skills/`. Copy the `nldr-pr-docs` skill from this skill's sibling directory (or `~/.claude/skills/nldr-pr-docs/`) into the target repo:

```
.claude/skills/nldr-pr-docs/SKILL.md
```

This makes the skill available to `claude-code-action` as a project skill — and shares it with all collaborators.

### 2. Add the workflow
Copy [references/github-workflow.yml](references/github-workflow.yml) to `.github/workflows/nldr-pr-docs.yml`. Adjust if the repo already has conventions (runner labels, concurrency groups).

### 3. API key secret
Check: `gh secret list` for `ANTHROPIC_API_KEY`. If missing, tell the user to add it:
```
gh secret set ANTHROPIC_API_KEY
```
(Or via repo Settings → Secrets and variables → Actions.) Never ask the user to paste the key into the chat; have them run the command themselves.

### 4. Workflow permissions
The workflow declares `contents: write` and `pull-requests: write`. Also verify the repo allows it: Settings → Actions → General → Workflow permissions should permit write, or the declared permissions block handles it. If the org restricts Actions, flag it.

### 5. Commit and verify
Commit `.claude/skills/nldr-pr-docs/` and `.github/workflows/nldr-pr-docs.yml` (to a branch/PR if the user prefers). Tell the user: the first PR after merge will exercise the flow; check the Actions tab for the run.

## How the flow behaves

- Triggers on PR open and new commits (`synchronize`).
- Claude checks out the PR branch, assesses the diff's doc impact, updates docs, and commits to the PR branch.
- **Loop safety:** the `nldr-pr-docs` skill is idempotent — when a doc-update commit retriggers the workflow, the next run sees docs already in sync and exits without committing, ending the chain. The workflow also skips runs whose head commit is the bot's own doc commit (`docs:` prefix guard).

## Common mistakes

- Forgetting to vendor the skill into `.claude/skills/` — the workflow then runs with no instructions and improvises.
- Skipping the secret check — the run fails with an auth error on the first PR.
- Using `pull_request_target` — not needed here and a security foot-gun with checked-out PR code. Stick with `pull_request` (secrets are unavailable to forks; document that fork PRs won't get doc updates).
