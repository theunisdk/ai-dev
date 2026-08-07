# Expo / React Native Implementation Patterns

Copy-adaptable code patterns for fixing each audit category. Adapt names, tokens, and icon sets to the project's existing conventions — never paste these verbatim over an app's design system.

## Contents

1. [expo-router Tabs — well-configured baseline](#expo-router)
2. [@react-navigation/bottom-tabs equivalent](#react-navigation)
3. [Safe area handling](#safe-area)
4. [Active/inactive state with two visual cues](#states)
5. [Inactive contrast via opacity compositing](#contrast)
6. [Separation from content](#separation)
7. [Badges](#badges)
8. [Tap targets in custom bars](#tap-targets)
9. [Micro-interactions (Reanimated + haptics)](#motion)
10. [Screen transitions](#transitions)
11. [Centered CTA tab](#cta)

<a name="expo-router"></a>
## 1. expo-router Tabs — well-configured baseline

`app/(tabs)/_layout.tsx`:

```tsx
import { StyleSheet } from 'react-native';
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,        // brand color for active
        tabBarInactiveTintColor: colors.tabInactive,  // verified ≥3:1 vs bar bg
        tabBarStyle: {
          backgroundColor: colors.tabBarBg,           // neutral, ≠ content bg
          borderTopWidth: StyleSheet.hairlineWidth,   // subtle separation
          borderTopColor: colors.border,
        },
        tabBarLabelStyle: { fontSize: 11 },           // 10–12pt window
        // Active label bolder = second visual cue alongside tint:
        // (set per-screen or via tabBarLabel render fn — see §4)
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',                              // short, single line
          tabBarIcon: ({ color, focused }) => (
            <Ionicons
              name={focused ? 'home' : 'home-outline'} // outline → filled
              size={24}
              color={color}
            />
          ),
        }}
      />
      {/* 3–5 Tabs.Screen entries total */}
    </Tabs>
  );
}
```

Notes: expo-router's `<Tabs>` wraps `@react-navigation/bottom-tabs`, so all `tabBar*` options below apply to both. The default tab bar already handles safe-area bottom insets and 44pt+ item heights — custom bars must do this themselves.

To keep a route out of the bar without deleting it (e.g. a settings or help screen wrongly given a tab): `options={{ href: null }}` on that `Tabs.Screen`, then link to it from Profile.

<a name="react-navigation"></a>
## 2. @react-navigation/bottom-tabs

Same options via `createBottomTabNavigator`:

```tsx
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

const Tab = createBottomTabNavigator();

export default function Tabs() {
  return (
    <Tab.Navigator screenOptions={{ /* same tabBar* options as above */ }}>
      <Tab.Screen name="Home" component={HomeScreen} options={{ /* icon etc. */ }} />
    </Tab.Navigator>
  );
}
```

<a name="safe-area"></a>
## 3. Safe area handling

Built-in bars from expo-router / react-navigation add the bottom inset automatically — do **not** also add manual padding (double-spacing is its own defect). For **custom** bars:

A custom bar receives `{ state, descriptors, navigation }` and must rebuild everything the default bar gave you for free — insets, 44pt targets, and correct press semantics:

```tsx
import { View, Pressable, Text, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

function CustomTabBar({ state, descriptors, navigation }) {
  const insets = useSafeAreaInsets();
  return (
    <View style={{
      flexDirection: 'row',
      paddingBottom: Math.max(insets.bottom, 8),   // never a fixed height that ignores insets
      borderTopWidth: StyleSheet.hairlineWidth,
      borderTopColor: colors.border,
      backgroundColor: colors.surface,
    }}>
      {state.routes.map((route, index) => {
        const { options } = descriptors[route.key];
        const focused = state.index === index;
        const label = options.tabBarLabel ?? options.title ?? route.name;

        // emit tabPress and respect preventDefault — this is what makes
        // scroll-to-top / pop-to-root behave like the built-in bar
        const onPress = () => {
          const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
          if (!focused && !event.defaultPrevented) navigation.navigate(route.name, route.params);
        };
        const onLongPress = () => navigation.emit({ type: 'tabLongPress', target: route.key });

        return (
          <Pressable
            key={route.key}
            onPress={onPress}
            onLongPress={onLongPress}
            accessibilityRole="button"
            accessibilityState={{ selected: focused }}
            accessibilityLabel={options.tabBarAccessibilityLabel}
            style={{ flex: 1, minHeight: 44, alignItems: 'center', justifyContent: 'center', paddingTop: 8 }}
          >
            {options.tabBarIcon?.({ focused, color: focused ? colors.active : colors.inactive, size: 24 })}
            <Text style={{ fontSize: 11, color: focused ? colors.active : colors.inactive, fontWeight: focused ? '700' : '400' }}>
              {label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
```

Wire it up with `<Tabs tabBar={(props) => <CustomTabBar {...props} />}>` (expo-router) or the identical `tabBar` prop on `Tab.Navigator`. Swap `colors` for your theme tokens.

Never `position: 'absolute'; bottom: 0` without adding `insets.bottom`. Never set a fixed bar height that ignores insets. Android: ensure `react-native-safe-area-context` provider wraps the app; with edge-to-edge enabled the same insets logic applies.

<a name="states"></a>
## 4. Active state with two visual cues

Cue 1 — icon fill swap (see `focused ? 'home' : 'home-outline'` above) plus tint via `tabBarActiveTintColor`. Cue 2 — bolder active label:

```tsx
tabBarLabel: ({ focused, color, children }) => (
  <Text style={{ fontSize: 11, color, fontWeight: focused ? '700' : '400' }}>
    {children}
  </Text>
),
```

If the icon set has no outline/filled pairs, keep outline everywhere and rely on tint + bold label — still two cues, still passes.

<a name="contrast"></a>
## 5. Inactive contrast via opacity compositing

Prefer deriving the inactive color from the active/text color at reduced opacity, then verify the composited result ≥ 3:1 against the bar background:

```js
// contrast-check.js — run with node during the audit
// Expand shorthand/alpha hex first so a malformed color fails loudly instead of returning NaN.
const norm = (hex) => {
  let h = String(hex).trim().replace(/^#/, '');
  if (h.length === 3) h = [...h].map((c) => c + c).join('');
  if (h.length === 8) h = h.slice(0, 6);            // drop alpha; composite it explicitly instead
  if (!/^[0-9a-fA-F]{6}$/.test(h)) throw new Error(`Unsupported color: ${hex} — convert to #RRGGBB first`);
  return '#' + h;
};
const lum = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(norm(hex).slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};
const composite = (fg, bg, alpha) => '#' + [1, 3, 5].map((i) =>
  Math.round(parseInt(norm(fg).slice(i, i + 2), 16) * alpha +
             parseInt(norm(bg).slice(i, i + 2), 16) * (1 - alpha))
    .toString(16).padStart(2, '0')).join('');
// Example: inactive = text color at 55% over bar bg
console.log(ratio(composite('#111111', '#F7F7F7', 0.55), '#F7F7F7')); // want ≥ 3
```

Run for light and dark themes. If a theme fails, raise opacity or darken/lighten the inactive tone until it passes.

<a name="separation"></a>
## 6. Separation from content — pick ONE

```tsx
// (a) hairline top border
tabBarStyle: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border }

// (b) background tone offset: content #FFFFFF → bar #F7F7F8 (light gray)

// (c) subtle upward shadow / elevation
tabBarStyle: {
  elevation: 8,                                   // Android
  shadowColor: '#000', shadowOpacity: 0.06,       // iOS — keep it soft
  shadowOffset: { width: 0, height: -2 }, shadowRadius: 8,
  borderTopWidth: 0,
}
```

Keep shadows soft (opacity ≤ ~0.08). Don't stack all three techniques — one subtle cue is the goal.

<a name="badges"></a>
## 7. Badges

Built-in support:

```tsx
options={{
  tabBarBadge: unreadCount > 0 ? (unreadCount > 99 ? '99+' : unreadCount) : undefined,
  tabBarBadgeStyle: {
    backgroundColor: colors.badge,       // stands out, fits palette
    color: '#fff', fontSize: 10,
    borderWidth: 1.5, borderColor: colors.tabBarBg,   // outline ring polish
  },
}}
```

`undefined` hides the badge — never render a permanent empty badge. Wire the count to essential signals only (unread messages), not every minor update.

<a name="tap-targets"></a>
## 8. Tap targets in custom bars

```tsx
<Pressable
  style={{ minWidth: 44, minHeight: 44, flex: 1, alignItems: 'center', justifyContent: 'center' }}
  hitSlop={8}
  accessibilityRole="tab"
  accessibilityState={{ selected: focused }}
  accessibilityLabel={label}
>
  <Icon size={24} color={color} />
  <Text style={{ fontSize: 11 }}>{label}</Text>
</Pressable>
```

The icon stays 24; the pressable region must reach ≥44×44. Add the accessibility props while you're there — screen-reader users navigate tabs by role and selected state.

<a name="motion"></a>
## 9. Micro-interactions (Reanimated + optional haptics)

Check `package.json` first — `react-native-reanimated` ships with most Expo templates; `expo-haptics` may need `npx expo install expo-haptics`. Ask before adding dependencies.

Tap feedback + active-state spring on a custom tab button:

```tsx
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';

import { Pressable } from 'react-native';
import { useReducedMotion } from 'react-native-reanimated';

// `tabBarButton` props carry NO `focused` field — read selection off the a11y props,
// and keep spreading the rest (style carries the navigator's flex:1 tab sizing).
function TabButton({ onPress, children, style, ...props }) {
  const focused = props['aria-selected'] ?? props.accessibilityState?.selected ?? false;  // v7 ?? v6
  const reduced = useReducedMotion();
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    // Press feedback only. Do NOT fade inactive tabs here: the inactive *color* already
    // carries that cue and was verified at ≥3:1 in §5 — stacking an opacity on top
    // recomposites it below 3:1 and fails the rule this skill audits for.
    transform: [{ scale: reduced ? 1 : scale.value }],
  }));
  const press = (to, damping) => { if (!reduced) scale.value = withSpring(to, { damping, stiffness: 300 }); };
  return (
    <Pressable
      {...props}
      onPressIn={() => press(0.9, 15)}
      onPressOut={() => press(1, 12)}
      onPress={(e) => { Haptics.selectionAsync(); onPress?.(e); }}
      style={[{ minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }, style]}
    >
      <Animated.View style={animStyle}>{children}</Animated.View>
    </Pressable>
  );
}
```

`stiffness: 300` keeps the spring settling inside the ~150ms tap-feedback budget; an undamped default spring rings on well past 200ms. `useReducedMotion()` collapses the motion to an instant state change without removing the active cue (which lives in color and weight, not motion).

With the built-in bar, inject via `tabBarButton: (props) => <TabButton {...props} />`. Verify the active tab actually renders at full opacity after wiring this up — dropping `style` or reading a non-existent `focused` prop are the two ways this "fix" silently reintroduces the weak-active-state defect you were auditing for. A sliding active-indicator underline is also effective: animate `translateX` of a small bar to `tabIndex * tabWidth` with `withSpring`. Keep in-bar motion fast (≤200ms) and subtle — screen transitions get their own slightly longer budget in the motion table in `design-rules.md`.

<a name="transitions"></a>
## 10. Screen transitions

Avoid hard teleports between tab screens. With `@react-navigation/bottom-tabs` v7+ (used by current expo-router):

```tsx
screenOptions={{ animation: 'fade' }}   // or 'shift'
```

On older versions, a lightweight alternative is a brief `FadeIn` (Reanimated entering animation) on each screen's root view. Keep it soft and quick — the goal is connectedness, not spectacle.

<a name="cta"></a>
## 11. Centered CTA tab (Create / Post / Order)

A raised center button is a sanctioned pattern. Implement as a middle `Tabs.Screen` with a custom `tabBarButton` that renders a circular elevated button (brand color, white icon, slight negative top margin), sized ≥56pt so the target is generous. If tapping should open a modal rather than switch tabs, keep the `Tabs.Screen` (so the button keeps its slot in the bar) and intercept the press: give `tabBarButton` its own `onPress` that calls `router.push('/create')` without calling through to navigation. Do **not** reach for `href: null` here — that removes the route from the bar entirely, which is the opposite of what you want for a centered CTA. Keep the rest of the bar neutral so the CTA is the single point of color.
