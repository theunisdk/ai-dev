# Expo / React Native Implementation Patterns

Copy-adaptable patterns for each fix category. Adapt to the project's state management (Zustand/Redux/Context), form library, theme tokens, and copy tone — don't paste verbatim.

## Contents

1. [Smart defaults in forms](#defaults)
2. [Outcome-stating CTAs](#ctas)
3. [Endowed progress indicator](#progress)
4. [Value-before-signup (gated report)](#reciprocity)
5. [Pre-signup personalization preserved through auth](#ikea)
6. [Loss-framed retention/upgrade screen](#loss)
7. [Anchored pricing rows](#anchoring)
8. [Deferred permission prompts](#permissions)

<a name="defaults"></a>
## 1. Smart defaults in forms

Initialize form state with the most likely values, never empty. Sources of good defaults, in order: the user's own previous choice (persist it), device signals (locale, region, timezone), product analytics ("most users pick X" — a product decision, flag for confirmation), then a sensible convention.

```tsx
// react-hook-form example — booking screen
const today = new Date();
const { control, handleSubmit } = useForm({
  defaultValues: {
    location: lastSearch?.location ?? nearestCity,     // previous choice > device signal
    checkIn: addDays(today, 1),                        // tomorrow, not blank
    checkOut: addDays(today, 3),                       // most common stay length — CONFIRM with user
    guests: 2,                                         // most common party size — CONFIRM
    rooms: 1,
  },
});
```

Persist last-used values so the form gets smarter per user:

```tsx
// zustand + AsyncStorage persistence
// note the curried create<T>()(...) form — required for type inference through middleware
const useSearchStore = create<SearchState>()(persist(
  (set) => ({ lastSearch: null, setLastSearch: (s) => set({ lastSearch: s }) }),
  { name: 'search-defaults', storage: createJSONStorage(() => AsyncStorage) },
));
```

Also: collapse optional fields behind a "More options" disclosure so the visible decision count stays small; derive everything derivable (currency from region, country code from SIM/locale via `expo-localization`).

<a name="ctas"></a>
## 2. Outcome-stating CTAs

Replace mechanism verbs with outcomes, computed truthfully:

```tsx
// Before: <Button title="Search" />
const { data: count } = useQuery({ queryKey: ['resultCount', filters], queryFn: fetchResultCount });
<Button title={count != null ? `See ${count} results` : 'Search'} onPress={submit} />
```

Debounce the count query on filter change; fall back to the generic label while loading or on error — never show a stale or invented number. Same pattern for other flows: "Get my plan", "Save 3 items", "Start my 7-day streak".

<a name="progress"></a>
## 3. Endowed progress indicator

Count already-completed work as step one and render progress from a step model, so 0% is structurally impossible after signup:

```tsx
const STEPS = [
  { id: 'account',  label: 'Create account' },   // completed by definition once they're here
  { id: 'goal',     label: 'Pick your goal' },
  { id: 'profile',  label: 'Set up profile' },
  { id: 'first',    label: 'First action' },
  { id: 'notify',   label: 'Turn on reminders' },
] as const;

function useOnboardingProgress(state: OnboardingState) {
  // 'account' is complete by definition — count it whether or not the caller recorded it,
  // so the bar starts at 0.2 and 0% is genuinely unreachable
  const completed = new Set([...state.completed, 'account']);
  const done = STEPS.filter((s) => completed.has(s.id)).length;
  return { done, total: STEPS.length, pct: done / STEPS.length };
}
```

Animate the bar so each completion is felt:

```tsx
const width = useSharedValue(pct);
useEffect(() => { width.value = withSpring(pct, { damping: 18 }); }, [pct]);
const barStyle = useAnimatedStyle(() => ({ width: `${width.value * 100}%` }));
// Render: filled track + "1 of 5 done" + checkmarks on completed steps
```

Show remaining count near the end ("1 step left") and pre-check the completed steps visually (✓), not just the bar.

<a name="reciprocity"></a>
## 4. Value-before-signup (gated report pattern)

Deliver a genuinely useful partial result, then offer persistence/completeness as the reason to sign up. Structure the screen as real content + an inline save prompt — never a blur overlay:

```tsx
function AnalysisResult({ report, isAuthed }) {
  const shown = report.issues.slice(0, 3);
  const more = report.issues.length - shown.length;      // never negative
  return (
    <ScrollView>
      <ScoreRing value={report.score} />                 {/* real value, unlocked */}
      <TopIssues issues={shown} />                       {/* useful on its own */}
      <PassedChecks items={report.passed} />
      {!isAuthed && (
        /* cta saves THEIR work — endowment stacked on top of reciprocity */
        <SavePrompt
          title="Want the complete breakdown?"
          body={more > 0 ? `${more} more issues + step-by-step fixes` : 'Step-by-step fixes for every issue'}
          cta="Save my report"
          onPress={() => router.push({ pathname: '/auth', params: { intent: 'save-report' } })}
        />
      )}
    </ScrollView>
  );
}
```

Keep the anonymous result in local state/storage and attach it to the account after auth (see §5) — the user must never lose the thing that motivated them to sign up.

<a name="ikea"></a>
## 5. Pre-signup personalization preserved through auth

Run personalizing steps before the account wall, store them locally, and merge into the account on signup:

```tsx
// Local draft store — works before any auth
const useDraftStore = create(persist(
  (set) => ({
    draft: { name: '', goal: null, theme: null, language: null },
    updateDraft: (patch) => set((s) => ({ draft: { ...s.draft, ...patch } })),
  }),
  { name: 'onboarding-draft', storage: createJSONStorage(() => AsyncStorage) },
));

// Flow order in expo-router:
// /welcome → /personalize/goal → /personalize/theme → /first-lesson → /auth
// NOT: /auth first.

// After successful signup/login — merge, then clear:
async function onAuthSuccess(userId: string) {
  const { draft } = useDraftStore.getState();
  await api.saveProfile(userId, draft);      // their work survives the wall
  useDraftStore.persist.clearStorage();
}
```

CTA copy at the wall continues their momentum: `Continue` / `Save my plan` — and show a recap of what they built ("Your plan: Spanish · 10 min/day · Dark theme") right above the auth form so the endowment is visible at the decision moment.

<a name="loss"></a>
## 6. Loss-framed retention/upgrade screen

Name the user's actual items and the real consequence. Every fact rendered must come from real data — if the backend has no deletion policy, this screen must not claim one (flag to the user instead).

```tsx
function StorageFullScreen({ filesAtRisk, deleteDate }) {
  return (
    <View>
      <Title>These files lose backup on {format(deleteDate, 'd MMM')}</Title>
      {filesAtRisk.slice(0, 4).map((f) => (
        <FileRow key={f.id} name={f.name} thumb={f.thumb} />   // THEIR files, by name
      ))}
      {filesAtRisk.length > 4 && <Muted>+{filesAtRisk.length - 4} more</Muted>}
      <PrimaryButton title="Keep my files protected" onPress={upgrade} />
      <TextButton title="Continue without backup" onPress={dismiss} />
      {/* honest consequence, not "Maybe later" — but visible, tappable, unshamed */}
    </View>
  );
}
```

Guardrails: no fabricated countdowns; the dismiss stays one tap and normal-sized; don't loss-frame screens where nothing is actually at stake — keep gain framing there.

<a name="anchoring"></a>
## 7. Anchored pricing rows

Attach add-on prices to their anchor and label them relatively (computed, not hardcoded):

```tsx
function ProtectionOffer({ cartItem, plan }) {
  // compare like with like: the monthly price you display against the anchor's price
  const pct = ((plan.monthly / cartItem.price) * 100).toFixed(1);
  return (
    <OfferRow
      title={`Protect your ${cartItem.name}`}
      price={`$${plan.monthly}/mo`}
      sub={`Just ${pct}% of your ${cartItem.shortName}'s price`}  // truthful relative label
    />
  );
  // Render directly beneath the cart item — same screen, never its own page.
}
```

Plan lineup anchoring: order plans premium-first or place the intended plan beside the pricier one; show annual plans as monthly-equivalent with computed savings (`$96/yr → "$8/mo — save 33%"`); highlight the recommended plan ("Most popular") only if it truly is. All anchors must be purchasable real options — no decoys, no fake strikethroughs.

<a name="permissions"></a>
## 8. Deferred permission prompts (reciprocity applied to permissions)

Never fire OS permission dialogs on first launch. Ask after the value is demonstrated, with a pre-prompt explaining the benefit in the user's terms:

```tsx
// After the user completes their first lesson / sets a goal:
async function offerReminders() {
  const wants = await showPrePrompt({
    title: 'Protect your streak?',
    body: "We'll remind you at your chosen time so day 2 happens.",
    yes: 'Turn on reminders', no: 'Not now',
  });
  if (wants) await Notifications.requestPermissionsAsync();  // OS dialog only after soft yes
}
```

The pre-prompt preserves the one-shot OS dialog: a "no" on your soft prompt costs nothing and you can ask again later at a better moment.
