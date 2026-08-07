# Bottom Navigation Design Rules — Rationale & Thresholds

The detailed reasoning behind each audit rule. Use this to judge borderline cases and to explain findings to the user.

## Contents

1. [Why the bottom nav matters](#why)
2. [Rule 1–2: Tab count & content](#content)
3. [Rule 3: Tap targets](#tap-targets)
4. [Rule 4–5: Icons & labels](#icons-labels)
5. [Rule 6–7: States & contrast](#states)
6. [Rule 8: Color discipline](#color)
7. [Rule 9: Safe area & home indicator](#safe-area)
8. [Rule 10–11: Separation & clutter](#separation)
9. [Rule 12: Badges](#badges)
10. [Rule 13: Micro-interactions](#motion)
11. [Creative layouts](#creative)
12. [Contrast ratio formula](#contrast-math)

<a name="why"></a>
## Why the bottom nav matters

The bottom navigation represents the top-level structure of the app: it tells users what's important and lets them move between core sections. It is one of the most tapped areas in the entire app — prime real estate. Every icon, label, and interaction must be strategic. A good bar makes the app feel effortless; a bad one drives users away. Fundamentals come before polish: no micro-interaction can save a bar with broken basics.

<a name="content"></a>
## Rules 1–2: Tab count & content

**3–5 tabs, absolute max 6.** Excess tabs shrink each target (harder to tap accurately), crowd the space, and cause choice paralysis. Fewer tabs = breathing room, fewer accidental taps, a more organized feel.

**Good candidates**: Home / main feed / dashboard; Search / Discover (when browsing is core); Add / Create (when users regularly post content); Messages / Notifications (when social interaction is central); Profile (account, settings, history, saved items).

**Bad candidates**: Help/FAQ (put in profile or a menu), Log out (rare action), legal pages (nobody needs terms at their fingertips). Never place traditionally top-of-screen elements — back/forward buttons, logos — in the bottom bar. **Jakob's Law**: users spend most of their time in other apps and expect yours to follow the patterns they already know; violating them creates confusion.

**Sanctioned exception**: a centered CTA button (Create / Post / Order). Center placement gives prominence and easy reach on large devices. This is a strength, not a violation — don't flag it.

**Audience shapes decisions.** Before judging labels/minimalism, consider who the users are: age, tech comfort, devices, the problem being solved. Tech-savvy young audiences tolerate icons-only; older or less app-familiar users need labels to feel confident. When the codebase gives no signal about audience, default to recommending labels — they're the safer choice.

<a name="tap-targets"></a>
## Rule 3: Tap targets

Minimum **44×44pt** touch area per tab — based on average human thumb size. Larger targets reduce mis-taps (usability) and serve users with varying motor abilities (accessibility). A 24×24pt touchable (icon-sized) is a common defect in custom bars and causes frequent mis-taps. The *visual* icon can stay 24pt; it's the *touchable region* that must reach 44pt, via padding or `hitSlop`.

<a name="icons-labels"></a>
## Rules 4–5: Icons & labels

**Icon size ~24pt** — large enough to recognize, small enough not to dominate. Adapt per device; a compact bar suits small screens better than a bulky one that eats content space. Design/check at 2–3 device widths.

**Familiarity and simplicity win.** A magnifying glass says "search"; binoculars don't. Complex or overly artistic icons force users to think. The goal is recognition at a glance with zero effort.

**One style, consistently.** All outline or all filled — mixing styles in the same bar is a visual mismatch ("black-tie event, someone in beachwear"). The single sanctioned exception: switching the active tab's icon from outline to filled as a selection cue. Consistency also covers complexity: a minimal icon next to an intricate one breaks harmony.

**Labels: 10–12pt, short, single line.** Below 10pt causes accessibility/readability problems; above 12pt draws attention from content and bloats the bar. Wrapping two-line labels clutter the screen and throw off the bar's height. Labels guide — they must not overshadow.

<a name="states"></a>
## Rules 6–7: Active state & inactive contrast

**Active tab: at least TWO simultaneous visual changes.** Examples: outline→filled icon + tint color change; tint change + bolder/darker label. A text-only change is not distinct enough — users take longer to locate themselves, which slows and frustrates navigation. Keeping the icon outlined is fine *if* the color change plus a second cue makes the active tab unmistakable.

**Inactive tabs: visible, not ghostly.** Poor contrast on inactive elements hurts users with visual impairments and makes the bar look broken. Prefer slightly reduced opacity of a coherent color over drastically different faint colors — this keeps the scheme cohesive while clearly separating states. Threshold: **≥ 3:1 contrast ratio** against the bar background (WCAG requirement for graphical objects and UI components). Verify computationally (formula below), in both light and dark themes.

<a name="color"></a>
## Rule 8: Color discipline

Per-tab colors or a rainbow of hues turn navigation into a guessing game and pull attention from content — the bar should feel like part of the app, seamless, not loud. It also dilutes brand recognition. Keep the bar **neutral** (white, gray, or dark tones matching the theme) and reserve bright/primary colors for key actions in the main content so they stand out. Keep top and bottom navigation palettes consistent with each other — mismatched chrome feels disjointed. A brand color on the bar is acceptable when it strengthens identity *and* doesn't overpower content.

<a name="safe-area"></a>
## Rule 9: Safe area & home indicator

On buttonless devices the home indicator (~34pt zone) sits directly below the bar. Never hide, restyle, or overlap it. A bar that crowds the indicator causes accidental home-gestures when tapping tabs, hurts one-handed use, and reads as broken/unfinished. The bar must respect the safe area with clear spacing. Code cannot fully prove this — always recommend a real-device check. On Android, edge-to-edge mode and gesture navigation create the equivalent inset problem; handle both platforms.

<a name="separation"></a>
## Rules 10–11: Separation & clutter

**The mistake even professionals make: no visual separation between bar and content.** Any one of these subtle techniques passes:

- a soft **1px top border** in a low-contrast tone;
- a **background tone** slightly different from the content (e.g. light gray bar on white content) creating depth;
- a **small soft shadow / elevation** above the bar for a floating feel.

A heavy or harsh shadow over-corrects and distracts — subtlety is the point. Concretely: shadow opacity **≤0.08**, radius ≤8, Android `elevation` ≤8. Anything heavier is itself a finding. Note that `StyleSheet.hairlineWidth` (0.5pt on 2x screens, 0.33pt on 3x) is the idiomatic React Native spelling of the 1px border and passes this rule — don't flag it.

Separately, avoid visual noise *inside* the bar: no boxes drawn around individual tabs, no decorative extras. Minimal, unobtrusive, content-first.

<a name="badges"></a>
## Rule 12: Badges

Badges (dot or numbered circle) signal updates well when disciplined: positioned **top-right of the icon** (naturally eye-catching); small enough to stay subtle, large enough to notice; numbers in a plain legible font (never tiny or stylized); a thin outline ring around the badge adds polish and separation; color must stand out against the bar yet fit the app palette. **Only badge essential notifications** — badging every minor update causes notification fatigue and destroys the signal's value.

Thresholds to judge against:

| Property | Pass | Fail |
|---|---|---|
| Dot diameter | 8–10pt | <6pt (invisible) or >12pt (shouty) |
| Numbered badge | 16–18pt min diameter, pill-shaped past 2 digits | smaller than the text it holds |
| Number font size | **10pt floor** (badges are the one sanctioned exception to the 10–12pt label window — never go below 10) | ≤9pt, or a stylized/condensed face |
| Outline ring | 1–2pt, in the bar's background color | none against a busy icon, or a heavy ring |
| Overflow | cap at `99+` | unbounded counts that widen the badge |
| Badge text contrast | ≥4.5:1 against the badge fill | anything less — it's small text |

<a name="motion"></a>
## Rule 13: Micro-interactions

A static bar works but feels like "a light switch with no click". Three layers of motion, all subtle and fast:

1. **Tap feedback** — quick scale-up, opacity/color change, or ripple on press.
2. **Tab-switch animation** — don't snap; slide an underline/indicator or animate the icon into place.
3. **Screen transitions** — a soft fade or slide between tab screens so switching doesn't feel like teleporting.

Duration budget — motion in the bar must read as instant, never as animation you wait on:

| Layer | Pass | Fail |
|---|---|---|
| Tap feedback | 100–150ms (a spring passes if damped/stiff enough to settle in that window) | >200ms, or none at all |
| Tab-switch indicator | ≤200ms (spring is fine if it settles inside that) | >300ms, or bouncy overshoot |
| Screen transition | 150–250ms fade/shift | >300ms, or a hard cut with no transition |

Also respect `useReducedMotion()` / `AccessibilityInfo.isReduceMotionEnabled()` — fall back to an instant state change rather than removing the active cue entirely.

These are polish (Low severity when absent) but they're what separates functional apps from ones that feel great. Only add them once fundamentals pass.

<a name="creative"></a>
## Creative layouts

Unconventional shapes, positions, or dynamic interactions can make an app memorable — experimentation is legitimate. The hard constraint: **never sacrifice usability for aesthetics.** If a striking layout confuses users or makes navigation harder, it fails the audit regardless of beauty. Judge creative bars by the same rules: tap targets, states, contrast, safe area.

<a name="contrast-math"></a>
## Contrast ratio formula (WCAG)

Contrast ratio = (L1 + 0.05) / (L2 + 0.05), where L1/L2 are the relative luminances of the lighter/darker color.

Relative luminance: for each sRGB channel c in [0,1]: c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4, then L = 0.2126·R + 0.7152·G + 0.0722·B.

When an inactive color is produced by opacity over the bar background, first composite: result = fg·α + bg·(1−α), then compute the ratio against the bar background. Requirement: **≥ 3:1** for icons and UI components (WCAG 1.4.11). Compute with a quick script rather than estimating; check light and dark themes separately.
