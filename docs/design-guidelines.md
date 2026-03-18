# POSnet Design Guidelines

This document defines the design rules for all POSnet terminal screens,
missions, windows, and sandbox options. All new features must comply.

---

## 1. Mission Design

### 1.1 Cancellation

- Missions are **cancelable at any stage** via the terminal.
- **Tier I** (low risk) missions incur **no reputation penalty** on cancel.
- **Tiers II-IV** incur a **scaling reputation penalty**:
  - Tier II: `BaseCancelPenalty * 0.5`
  - Tier III: `BaseCancelPenalty * 1.0`
  - Tier IV: `BaseCancelPenalty * 1.5`
- Delivery cancellation uses a separate `BaseCancelPenaltyDelivery` base;
  the penalty **doubles** if the player has already picked up the package.
- A **progress discount** of 25% applies if the player has started objectives
  (e.g. entered the target, taken a photograph).
- Cancellation penalties are gated by the `EnableCancellationPenalty` sandbox
  option (default: true).
- The cancel button must preview the penalty:
  `"Cancel (-15 rep)"` or `"Cancel (no penalty)"`.

### 1.2 Barter / Negotiation

- Before accepting any mission, the player may **negotiate terms** via the
  terminal.
- Negotiation options:
  - Request higher pay (+20% reward, -1 day deadline).
  - Request more time (+2 days, -15% reward).
  - Accept current terms.
  - Decline (go back).
- Success chance is **reputation-weighted**:
  - Tier I: 30%, Tier II: 50%, Tier III: 70%, Tier IV: 85%.
  - Modified by `NegotiationSuccessBonus` sandbox option.
- Maximum **3 negotiation attempts** per mission.
- Failed attempts do not change terms; the player may retry or accept as-is.
- Gated by `EnableNegotiation` sandbox option (default: true).

### 1.3 Physical Item Trading (Future)

- Certain missions may include a **contact location** for physical item
  exchange at a world location.
- The player travels to the contact point and uses a right-click context
  menu to open a trade panel.
- Trade offers are generated at mission creation time and are
  tier-appropriate.
- Gated by `EnableContactTrading` sandbox option (default: true).

---

## 2. Window & UI Design

### 2.1 Navigation

- Every non-root screen **must** have a `[0] Back` button.
- The screen manager navigation stack handles back traversal.
- Page changes (pagination) use `replaceCurrent()` to avoid polluting the
  back stack.

### 2.2 Menu Hierarchy

- The **main menu** must remain uncluttered. Use sub-menus.
- **BBS** is the hub for all operational content:
  - `[1] Investments`
  - `[2] Operations`
  - `[3] Courier Service`
- Placeholder items (IRC, Journal, Profile, Stockmarket) remain at the
  main menu level until implemented.

### 2.3 Pagination

- When a screen's content exceeds one page, show pagination controls:
  `[ Previous ]  Page X/Y  [ Next ]`
- Pagination buttons appear at the bottom of the content area.
- The `[Back]` button (navigation) remains separate from pagination.
- Default page size: 5 items.

### 2.4 Font & Theme

- Terminal **font size** is controllable via sandbox option
  (`TerminalFontSize`: Small / Medium / Code / Large; default: Code).
- **Font-size-to-window-size scaling** is available via sandbox option
  (`FontScaleWithWindow`; default: false). This is independent of PZ's
  global font settings, though they still have an effect.
- Four **colour themes** are provided via sandbox option
  (`TerminalColourTheme`): Classic Green, Amber, Cool White, IBM Blue.
- Theme changes take effect on next terminal open.

---

## 3. Sandbox Options Philosophy

- Any mechanic that could be considered **harsh or opinionated** must have
  a sandbox toggle or adjustment.
- This includes: cancellation penalties, negotiation availability, mission
  difficulty scaling, expiry penalties, and reward multipliers.
- The goal is **maximum player choice with minimum grief**.
- Boolean toggles for feature gates; integer sliders for tunable values.
- All sandbox options must have translated labels and tooltips.

---

## 4. Translation

- Every user-visible string must use a translation key via `getText()` or
  the `safeGetText()` wrapper.
- Keys follow the pattern: `UI_POS_<Screen>_<Element>`.
- Sandbox keys follow: `POS_<OptionName>` (label) and
  `POS_<OptionName>_tooltip` (tooltip).
- Translation files are JSON in `42/media/lua/shared/Translate/EN/`.

---

## 5. Radio & Signal Strength

### 5.1 AZAS Dependency

POSnet requires **AZAS Frequency Index** as a hard dependency. Frequencies
are assigned dynamically per-world — there is no static frequency sandbox
option.

POSnet registers **two stations** with AZAS:
- `POSnet_Operations` (amateur band) — civilian ops content
- `POSnet_Tactical` (military band) — combat/tactical content

### 5.2 Band-Based Content Gating

Radio hardware determines which band the player can access:
- **Ham radios** receive amateur + military → full content
- **Military handhelds** receive military only → tactical content only
- **Commercial radios** receive neither → cannot connect

The terminal stores the connected band and filters content accordingly.

### 5.3 Signal Strength

Radio hardware quality determines connection quality via inverse square
law: `signal = clamp(0, 1, (power / reference)^2)`.

Effects:
- Below `MinSignalThreshold` (default 15%): connection refused
- Above threshold: rewards scale from 50% to 100%
- Terminal displays signal strength with colour-coded quality indicator
- Gated by `EnableSignalStrength` sandbox toggle

See `docs/radio-power-table.md` for the full power reference table.

### 5.4 Signal Strength Mission Influence (Future)

Radio signal strength should influence mission generation parameters:
- Lower signal = shorter mission range (closer targets)
- Higher signal = longer range, better rewards
- Signal quality affects the "clarity" of mission briefings
- Gated by `SignalAffectsMissionRange` sandbox toggle (placeholder, not yet wired)

---

## 6. Location Display

### 6.1 Street Addresses

All mission locations must be displayed as human-readable street addresses
using `PhobosLib_Address.resolveAddress()`. Raw coordinates are the
fallback if street resolution fails (e.g. modded maps without
`streets.xml`).

### 6.2 Show on Map

Active missions with a location must offer a `[MAP]` button that opens
the PZ world map centered on the target via `PhobosLib.showOnWorldMap()`.
The MAP button appears on active mission views only (not negotiate).

### 6.3 Explored-Only Locations

Missions must only target locations the player has already explored:
- `POS_BuildingCache.passiveScan()` restricts to 50-tile radius around
  the player — inherently explored territory.
- `POS_MailboxScanner` requires player right-click interaction — inherently
  explored.
- Any future mission generators must enforce this constraint.
