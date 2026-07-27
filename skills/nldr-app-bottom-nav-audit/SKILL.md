---
name: nldr-app-bottom-nav-audit
description: Audit and fix bottom navigation (tab bar) UI in Expo / React Native codebases against proven mobile design principles — tab count and content, sizing, tap targets, active/inactive states, icon consistency, color discipline, safe-area handling, content separation, badges, accessibility contrast, and micro-interactions. Use this skill whenever the user asks to audit, review, improve, redesign, fix, or polish their bottom navigation, tab bar, bottom tabs, or navbar — and also when building a NEW tab bar or modifying tab navigation in a React Native or Expo app, even if they don't say "audit". Triggers include mentions of expo-router Tabs, @react-navigation/bottom-tabs, tabBar, tab bar design, or "my navigation looks bad/messy".
---

# Bottom Navigation Audit & Fix (Expo / React Native)

Audit a codebase's bottom navigation against battle-tested mobile design principles, report violations with severity, and apply fixes. The bottom nav is the most-tapped surface in an app and represents its top-level structure — small defects here compound into daily friction for every user.

## Workflow

Work through these five steps in order. Don't skip the audit and jump straight to editing — the report is what lets the user see *why* each change is made.

### Step 1 — Locate the implementation

Find how the bottom navigation is built. In Expo apps it is almost always one of:

1. **expo-router**: a `(tabs)` route group with `app/(tabs)/_layout.tsx` rendering `<Tabs>` with `screenOptions` / `Tabs.Screen` options.
2. **@react-navigation/bottom-tabs**: `createBottomTabNavigator()` — search for `createBottomTabNavigator` or `Tab.Navigator`.
3. **Custom component**: a hand-rolled bar (search for `tabBar={`, `position: 'absolute'` + `bottom: 0`, or component names like `TabBar`, `BottomNav`).

Useful searches: `Tabs.Screen`, `tabBarIcon`, `tabBarActiveTintColor`, `createBottomTabNavigator`, `useSafeAreaInsets`, `tabBarStyle`. Also read the theme/tokens files (colors, typography) so fixes use the app's existing design system rather than hard-coded values.

### Step 2 — Audit

Evaluate the implementation against every rule in the checklist below. For rules that depend on rendered values (colors, sizes), trace the actual values through the theme. For the contrast rule, compute the ratios (formula in `references/design-rules.md`) — don't eyeball them.

Read `references/design-rules.md` for the full rationale and precise thresholds behind each rule before judging borderline cases.

**The checklist:**

1. **Tab count**: 3–5 tabs (6 absolute max). More causes cramped targets and choice paralysis; 2 or fewer suggests the bar isn't earning its space.
2. **Tab content**: only core, frequently used destinations (home/feed, search, create, messages/notifications, profile). Flag: help/FAQ, logout, legal pages, back buttons, or logos in the bar — these belong elsewhere (Jakob's Law: users expect familiar patterns). A centered CTA tab (Create/Post/Order) is good, not a violation.
3. **Tap targets**: every tab's touch area ≥ 44×44pt. Check custom bars especially — icon-sized (24pt) touchables are a common failure. `hitSlop` or padded `Pressable` areas count toward the target.
4. **Icon size**: ~24pt. Consistent style across all tabs (all outline or all filled) and consistent visual complexity. The one sanctioned exception: outline → filled for the active tab.
5. **Labels**: present unless the audience is clearly young/tech-savvy; 10–12pt; short, single-line, never wrapping.
6. **Active vs inactive state**: at least TWO simultaneous visual cues on the active tab (e.g. filled icon + tint change, or tint change + bolder label). Label-color-only changes fail this rule.
7. **Inactive contrast**: inactive icons/labels ≥ 3:1 contrast against the bar background (WCAG for UI components). Prefer reduced opacity of the same hue over a different washed-out color.
8. **Color discipline**: neutral bar background (white/gray/dark per theme); no per-tab colors; active tint from the brand palette; bar colors consistent with any header/top nav.
9. **Safe area / home indicator**: the bar must sit above the home indicator (~34pt) using safe-area insets — never overlap or suppress it. On Android, handle edge-to-edge/gesture nav insets too.
10. **Separation from content**: at least one of — a subtle 1px top border, a background tone distinct from the content, or a small soft shadow/elevation. A bar that blends invisibly into content fails; a heavy harsh shadow also fails.
11. **Clutter**: no boxes drawn around individual tabs, no decorative noise. Minimal and unobtrusive.
12. **Badges**: if used — top-right of the icon, small but noticeable, legible numbers, ideally a thin outline ring, color that stands out yet fits the palette, and only for essential notifications.
13. **Micro-interactions**: tap feedback (scale/opacity/ripple), animated active-state change, and non-teleporting screen transitions. Absence is a polish gap (low severity), not a defect.

### Step 3 — Report

Present findings as a table before changing anything:

| # | Rule | Status | Severity | Finding | Fix |
|---|------|--------|----------|---------|-----|

Status: ✅ pass / ⚠️ partial / ❌ fail. Severity: **High** (usability/accessibility harm — tap targets, safe area, contrast, indistinct active state, >6 tabs), **Medium** (design-quality harm — icon inconsistency, color chaos, no separation, bad tab content), **Low** (polish — micro-interactions, badge styling). End with a one-paragraph overall assessment.

### Step 4 — Fix

Apply fixes in severity order (High → Medium → Low). Use the code patterns in `references/expo-patterns.md` — they cover expo-router, react-navigation, and custom bars, including safe-area handling, active-state styling, separation, badges, and Reanimated micro-interactions.

Principles while fixing:

- Use the app's existing theme tokens and icon library; introduce no new dependencies unless required (Reanimated for micro-interactions is usually already present in Expo apps — check `package.json` first, and ask before adding anything).
- Preserve behavior: don't rename routes, reorder tabs, or remove destinations without flagging it in the report and getting agreement first (removing a tab is an information-architecture decision, not a style fix).
- Keep changes minimal and reviewable — touch the layout/tab files and theme, not half the app.
- Verify contrast ratios of the *final* chosen colors, in both light and dark themes if the app has both.

### Step 5 — Verify

After editing: run the type-checker / linter if the project has one; re-run the audit checklist against the changed code and confirm each ❌/⚠️ is now ✅; summarize what changed per file. Recommend the user test on a real device (both a small and large screen) — especially tap comfort near the home indicator, which cannot be judged from code alone.

## Reference files

- `references/design-rules.md` — full design rationale, thresholds, and the contrast-ratio formula. Read before auditing.
- `references/expo-patterns.md` — copy-adaptable Expo/React Native code patterns for every fix category. Read before fixing.