# The Six Principles — Research, Rationale, and Audit Criteria

Use this to judge borderline cases and to explain findings. Each section: the psychology, the evidence, the before/after pattern, and concrete pass/fail criteria.

## Contents

1. [Smart defaults](#defaults)
2. [Goal gradient / endowed progress](#goal-gradient)
3. [Reciprocity](#reciprocity)
4. [IKEA effect / endowment effect](#ikea)
5. [Loss aversion / status quo bias](#loss-aversion)
6. [Contrast effect / anchoring](#contrast)
7. [Ethics: persuasion vs. dark patterns](#ethics)

<a name="defaults"></a>
## 1. Smart defaults

**Psychology.** Every empty field is a decision demanded before the user receives anything. Piling up decisions causes *decision fatigue* — past a point, people make no choice and leave. Columbia's jam study: 24 flavors on display → 3% purchased; 6 flavors → 30%. More choice = harder, not better.

**Why defaults persuade.** 70–90% of users never change defaults — not from laziness but trust: a default reads as "this is what most people pick." The user's task shifts from *compose from scratch* to *scan and adjust*, which is fundamentally easier.

**Before/after.** Booking form with five empty fields + "Search" → same form pre-filled with the most common choices + button "See 12 results" (result count = proof value is already waiting).

**Pass criteria:**
- Every field that has a knowable most-common or most-likely value is pre-filled with it (or with the user's previous selection — an even better default).
- Number of simultaneous required decisions is minimized; optional fields deferred or collapsed.
- Primary CTA states the outcome ("See 12 results", "Get my plan") rather than the mechanism ("Search", "Submit") — when the count/outcome can be truthfully computed.
- Defaults are honest recommendations, not upsells disguised as defaults (pre-checking a paid add-on fails the ethics bar).

**Fail signals:** all-blank forms on first open; dropdowns with no selection; date pickers opening on nothing; generic CTA verbs; required fields that could have been inferred (location from device locale, currency from region, dates defaulting to today/tomorrow).

<a name="goal-gradient"></a>
## 2. Goal gradient / endowed progress

**Psychology.** The closer people feel to a goal, the harder they work toward it. Car-wash loyalty study: a 10-stamp card with 2 pre-filled stamps was completed at nearly **double** the rate of an 8-stamp empty card — identical effort required. The starting line is a design choice.

**Before/after.** Onboarding at "0% — 5 steps ahead" → same flow at "20% — step 1 complete", because account creation was reframed as step one instead of a separate event. 0% feels like standing still; 20% feels like momentum. LinkedIn's profile-strength meter is never at zero.

**Pass criteria:**
- No progress indicator the user ever sees at 0%. Something already done — account created, permission granted, preference auto-detected — is counted as the first completed step.
- Progress is granular enough to move visibly with each step (5 steps beats 2 giant ones for perceived motion).
- The end is visible: users can see how many steps remain, and the count is honest.
- Near the end, remaining effort is minimized/framed small ("1 step left").

**Fail signals:** onboarding starting at 0%; checklists with nothing pre-checked; profile-completeness meters at zero after signup; progress bars that jump erratically or stall without explanation (perceived stall kills the gradient effect).

<a name="reciprocity"></a>
## 3. Reciprocity

**Psychology.** Receiving something first creates an unconscious pull to return the favor — Cialdini ranked it the single most powerful driver of persuasion. Free samples lift grocery purchases up to 2,000%; the sample creates a debt, not a taste preference. Spotify's free month, Notion's free tier, Costco's samples: strategic gifts, not generosity.

**Before/after.** URL-analysis tool blurring the finished report behind "Create an account" (results held hostage — like a restaurant demanding your card before showing the menu) → a genuinely useful partial report (score, top issues, what passed) with a bottom prompt: "Want the complete breakdown? Save your report." Signup stops feeling like a wall because the user already got something worth keeping.

**Pass criteria:**
- The user receives real, usable value before any ask (signup, email, payment, notification permission).
- What's gated is the *complete/persistent* experience (full breakdown, history, sync), never the *first* value moment.
- The partial output is honestly useful on its own — a teaser so thin it's worthless fails the spirit of the rule.
- Permission prompts (notifications, location) arrive after the app has demonstrated why they're worth granting.

**Fail signals:** blur/lock overlays on results the user's own input generated; "sign up to continue" on first launch before any experience; card-upfront trials where the platform doesn't require it; asking for notification permission on first open.

<a name="ikea"></a>
## 4. IKEA effect / endowment effect

**Psychology.** People value what they built significantly more than an identical thing made by someone else (IKEA effect — the furniture *feels* better because you assembled it). Even without building, mere felt ownership raises value (endowment effect). Loss of a made thing hurts; loss of a blank form costs nothing.

**Before/after.** Email + password + "Sign up" (nothing on screen belongs to the user; closing the tab is free) → the user first picks their name, title, palette, card style — building something of theirs — and the button says "Continue", because leaving now means abandoning something they made. Duolingo: language chosen, goal set, first lesson completed, *then* the signup screen — ten minutes invested that nobody throws away.

**Pass criteria:**
- At least one meaningful personalizing choice happens before the account wall (goal, theme, content selection, first creation).
- Pre-signup work is preserved through registration — discarding it at the wall is worse than never offering it.
- Signup CTA copy reads as continuation of what they built ("Continue", "Save my plan"), not a cold transaction ("Sign up", "Register").
- The choices are real (they affect the user's experience), not theater.

**Fail signals:** signup as the very first screen; wizards that only collect data *for the company* (marketing questions) rather than letting the user shape *their* experience; personalization that resets after auth; "Sign up" copy at the moment of maximum investment.

<a name="loss-aversion"></a>
## 5. Loss aversion / status quo bias

**Psychology.** Kahneman's Nobel-winning finding: losing something is roughly **2×** as psychologically powerful as gaining the same thing. Gain-framing uses the weaker motivator. Status quo bias compounds it — people are wired to protect what they already have; make inaction's cost felt.

**Before/after.** Storage upgrade pitch — icon, feature list, "Upgrade now", and an effortless "Maybe later" (nothing at stake, zero psychological weight) → the same offer showing what the user is about to *lose*: their actual files by name, a real deadline, and a dismiss that owns the consequence ("I'll risk it"). The pitch loses to the felt threat.

**Pass criteria:**
- Action screens (upgrade, backup, renewal, retention) name what is concretely at stake — ideally the user's own items by name/count, not abstract feature lists.
- The stake is TRUE: a real deletion policy, a real expiry, a real limit about to be hit. Wire copy to actual data.
- The dismiss option is honest about consequence ("Continue without backup") rather than consequence-free ("Maybe later") — but remains clearly available and unshamed.
- Gain framing is still used where nothing is genuinely at stake — don't loss-frame everything; false threats destroy trust and cross into dark patterns.

**Fail signals:** pure feature-list paywalls with "Maybe later"; upgrade screens that never mention the user's own data; fabricated countdowns or invented scarcity (auto-fail — refuse to implement); guilt-tripping "confirmshaming" copy that mocks the user for declining.

<a name="contrast"></a>
## 6. Contrast effect / anchoring

**Psychology.** The brain evaluates numbers relative to what it saw immediately before, never in absolute terms. $50/month alone → user computes $600/year → "that's a lot." The same $50 directly under a $1,900 laptop with "just 2.6%" → a rounding error. Restaurants list the $90 Wagyu to make the $40 salmon reasonable; realtors show the overpriced house first.

**Before/after.** Protection plan on its own page at $50/month → the plan shown inline beneath the $1,900 item it protects, with a relative label ("2.6% of your laptop's price").

**Pass criteria:**
- No price presented in isolation on a screen with no reference point. Add-ons appear adjacent to the purchase they attach to.
- Relative labels used where truthful: percentage of the main purchase, per-day cost ("less than a coffee a week" only if arithmetically honest), annual-vs-monthly savings.
- Plan lineups are ordered/anchored deliberately: the intended choice sits next to a pricier anchor; annual plans show the monthly-equivalent with the savings computed.
- The anchor is a real price of a real option — decoy options nobody can actually buy, or inflated "was" prices, fail the ethics bar.

**Fail signals:** standalone pricing screens with a single unanchored number; add-on upsells on separate pages disconnected from the cart; identical visual weight on all plans with no anchoring logic; fake strikethrough prices.

<a name="ethics"></a>
## 7. Ethics: persuasion vs. dark patterns

Each principle has a legitimate form and a corrupted form. The test: **is the underlying claim true, and does the user win when the pattern works?**

| Principle | Legitimate | Dark pattern (refuse) |
|-----------|-----------|----------------------|
| Smart defaults | Most-common choice pre-selected | Paid add-on pre-checked |
| Goal gradient | Real completed work counted | Fake progress that resets or inflates |
| Reciprocity | Useful partial value freely given | Worthless teaser dressed as a gift |
| IKEA effect | Real personalization preserved | Sunk-cost theater; work discarded after signup |
| Loss aversion | True, dated consequences named | Fabricated countdowns, invented scarcity, confirmshaming |
| Contrast | Real prices as anchors | Decoy plans, fake "was" prices |

When a proposed fix requires a factual claim the code can't verify (retention policy, result counts, "most common" choice), surface it to the user as needs-confirmation rather than inventing it.
