---
name: nldr-app-ux-audit
description: Audit and improve an app's key conversion flows — onboarding, signup, forms, upgrade/paywall screens, pricing, and empty states — against six UX psychology principles (smart defaults, goal gradient/endowed progress, reciprocity, IKEA/endowment effect, loss aversion, contrast effect/anchoring), with Expo / React Native implementation patterns. Use this skill whenever the user asks to audit, review, improve, or redesign onboarding, signup, registration, a paywall, upgrade screen, pricing screen, checkout, or any form-heavy flow — or asks why users drop off, don't convert, don't finish onboarding, or abandon signup. Also use it when BUILDING any of these flows from scratch in a React Native/Expo app, even if psychology isn't mentioned.
---

# UX Psychology Audit & Fix (Expo / React Native)

Audit an app's conversion-critical flows against six research-backed psychology principles, report violations with severity, and apply fixes. Screens can look beautiful and still fail because they ignore how people decide: every blank field, 0% progress bar, premature signup wall, and isolated price is a measurable drop-off point.

## Ethical boundary (read first)

These principles amplify motivation that should already be legitimate. Apply them only where the underlying claim is true: pre-select defaults that genuinely are the most common choice; count progress the user really has made; warn about losses that will actually happen; anchor against real prices. Never fabricate countdowns, invent scarcity, hide the decline option, or dark-pattern the user — that erodes the trust these patterns depend on, and this skill must refuse to add deceptive versions even if a finding could be "fixed" that way. When a fix depends on a factual claim (e.g. "12 results available", "files deleted in 30 days"), wire it to real data or flag it for the user to confirm.

## Workflow

### Step 1 — Locate the flows

Find the screens where these principles apply. Typical Expo app locations:

- **Onboarding / signup**: routes or groups named `onboarding`, `auth`, `(auth)`, `sign-up`, `register`, `welcome`; look for multi-step wizards and progress indicators.
- **Forms**: search `TextInput`, `Picker`, form libraries (`react-hook-form`, `formik`), booking/search/filter screens.
- **Upgrade / paywall / pricing**: `paywall`, `subscribe`, `upgrade`, `premium`, `Purchases` (RevenueCat), `react-native-iap`, price strings (`$`, `/month`).
- **Gated content**: blur overlays, lock icons, `isLoggedIn ?` conditionals that hide results behind auth.
- **Empty states & progress**: `ProgressBar`, `progress`, streak/completion components.

Map each screen to the principles it touches before auditing. Read `references/psychology-principles.md` for the full rationale, research, and pass/fail criteria per principle.

### Step 2 — Audit against the six principles

1. **Smart defaults** — Do forms open pre-filled with the most common/likely choice (or the user's previous choice), or blank? Are there more simultaneous decisions than necessary (decision fatigue)? Do CTAs communicate what's waiting ("See 12 results") or stay generic ("Search", "Submit")?
2. **Goal gradient** — Does any progress indicator ever show 0%? Is already-completed work (account creation, a granted permission, an auto-detected setting) counted as progress? Is the number of remaining steps visible and honest?
3. **Reciprocity** — Does the user receive real value *before* being asked for signup/email/payment? Flag: results blurred behind an account wall, "sign up to continue" before any value delivered, trials that demand a card upfront when not necessary. Partial-but-useful output first, then a save/upgrade prompt, is the passing pattern.
4. **IKEA / endowment effect** — Can users make personalizing choices (name, goal, theme, content) *before* the account wall? Does the signup CTA read as continuation ("Continue") rather than a cold start ("Sign up")? Is pre-signup work preserved through registration (never discarded)?
5. **Loss aversion** — Are upgrade/retention screens framed only as gains ("Get more storage") with a free escape hatch ("Maybe later")? The passing pattern names what's concretely at stake — ideally the user's own data by name — and makes the dismissal honest about the consequence ("Continue without backup"). Only where the loss is real (see ethical boundary).
6. **Contrast effect** — Is any price shown in isolation on its own screen? Passing patterns: show add-on prices adjacent to the anchor purchase with a relative label ("2.6% of your laptop"), express costs per-day/per-use where truthful, order plans so the intended choice benefits from the anchor.

### Step 3 — Report

Before changing anything, present findings as a table:

| # | Screen/Flow | Principle | Status | Severity | Finding | Proposed fix |
|---|-------------|-----------|--------|----------|---------|--------------|

Status: ✅ / ⚠️ / ❌. Severity: **High** (a conversion-critical flow actively fights the principle — e.g. results hostage behind signup, 0% onboarding start, all-blank booking form), **Medium** (missed opportunity — generic CTA labels, gain-only upgrade framing, price without anchor), **Low** (polish — CTA microcopy, progress animation). Mark any fix that depends on a factual claim or product decision (default values, deletion policies, pricing display) as **needs-user-confirmation** — propose it, don't silently implement it.

### Step 4 — Fix

Apply agreed fixes in severity order using the patterns in `references/expo-patterns.md` (pre-filled form state, endowed progress components, gated-report layouts, pre-signup personalization with state preserved through auth, loss-framed paywalls, anchored pricing rows).

While fixing: use the app's existing state management, theme, and copy tone; keep diffs minimal and per-flow; never move business logic — smart defaults come from data or product knowledge, so when the "most common choice" is unknowable from code, choose a sensible placeholder and flag it. Copy changes are cheap and high-leverage — fix button labels and framing text even when the layout is fine.

### Step 5 — Verify

Run the project's type-checker/linter; re-run the checklist and confirm each finding is resolved; list changed files per flow. Recommend the user A/B test the highest-impact changes where they have the infrastructure — these principles are directional, and their own funnel data is the ground truth.

## Reference files

- `references/psychology-principles.md` — research, rationale, and detailed pass/fail criteria per principle. Read before auditing.
- `references/expo-patterns.md` — Expo/React Native code patterns for each fix category. Read before fixing.