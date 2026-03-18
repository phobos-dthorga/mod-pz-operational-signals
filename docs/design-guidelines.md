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
  (`FontScaleWithWindow`; default: false). When enabled, the font adjusts
  ±1 step based on window width (<600 = smaller, >900 = larger). This is
  independent of PZ's global font settings, though they still have an effect.
- Four **colour themes** are provided via sandbox option
  (`TerminalColourTheme`): Classic Green, Amber, Cool White, IBM Blue.
- Theme changes take effect on next terminal open.

### 2.5 Terminal Window Sizing

- Default terminal size: **1080x1170** pixels (1.5x the original 720x780).
- Minimum resizable size: **720x780** pixels (the old default).
- Resizability is enabled via `PhobosLib.makeWindowResizable()`. Skips
  automatically if the "Resize Any Window" mod is active.
- Content panels anchor to window edges on resize.
- All screen content must use **relative widths** (`contentPanel:getWidth()`)
  rather than hardcoded pixel values. Button widths: `pw - 10`.
- `maxChars` for wrapped text should adapt to panel width where practical.
- Separator character count (currently 40) is acceptable at the default
  size but should scale with width in future if needed.

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
- `POS_BuildingCache.passiveScan()` scans a 50-tile radius around the
  player every game-minute — inherently explored territory.
- `POS_MailboxScanner` uses passive scanning (30-tile radius every
  game-minute) to discover mailboxes automatically.
- On **first mod load**, both caches perform a one-time retroactive
  250-tile radius scan to catch locations the player explored before
  enabling POSnet. Gated by modData flags (`POS_BuildingScanDone`,
  `POS_MailboxScanDone`).
- Any future mission generators must enforce this constraint.

---

## 7. Screen Implementation Standards

### 7.1 Layout Initialisation

All screens **must** use `POS_TerminalWidgets.initLayout(contentPanel)` to obtain a
layout context (`ctx`) rather than declaring local layout variables. The context
provides:

| Field      | Type   | Description                                    |
|------------|--------|------------------------------------------------|
| `ctx.panel`| ISPanel| The content panel reference                    |
| `ctx.pw`   | number | Panel width                                    |
| `ctx.y`    | number | Current Y cursor (mutable — advance after each element) |
| `ctx.lineH`| number | Line height derived from actual font metrics   |
| `ctx.btnH` | number | Standard button height (`lineH + 8`)           |
| `ctx.btnW` | number | Standard button width (`pw - 10`)              |
| `ctx.btnX` | number | Standard button X offset (`5`)                 |

**Never hardcode line height to 20 or any other pixel value.** All vertical
spacing must derive from `ctx.lineH` to adapt to font size changes.

### 7.2 Screen Structure

Every screen must follow this structure:

1. **`screen.create(contentPanel, _params, _terminal)`**:
   - Call `W.initLayout(contentPanel)` to get `ctx`
   - Call `W.drawHeader(ctx, "UI_POS_<Screen>_Header")` to render title
   - Render screen-specific content using `ctx` values
   - Call `W.drawFooter(ctx)` for non-root screens (adds separator + back button)

2. **`screen.destroy`** — assign `POS_TerminalWidgets.defaultDestroy` directly:
   ```lua
   screen.destroy = POS_TerminalWidgets.defaultDestroy
   ```

3. **`screen.refresh`** — for screens that rebuild on refresh, use:
   ```lua
   function screen.refresh(_params)
       POS_TerminalWidgets.dynamicRefresh(screen, _params)
   end
   ```
   For static screens, use an empty function:
   ```lua
   function screen.refresh(_params) end
   ```

### 7.3 No Duplicate Utilities

- **`safeGetText()`** — use `POS_TerminalWidgets.safeGetText()`. Never redefine
  locally. In screen files where `W = POS_TerminalWidgets`, use `W.safeGetText()`.
  In non-screen files, use `POS_TerminalWidgets.safeGetText()` directly.
- **Colours** — use `POS_TerminalWidgets.COLOURS.*`. Never define local colour
  tables that duplicate existing palette entries (e.g. use `C.success` instead of
  defining a local "success green").
- **Destroy/refresh patterns** — use the shared helpers. Never copy-paste the
  `clearPanel` or `destroy+create` patterns.

### 7.4 Constants

- Cross-file strings (commands, screen IDs, item types, modData keys) must use
  `POS_Constants.*` — never inline string literals.
- Per-file magic numbers must be extracted to `local UPPER_CASE` constants at the
  top of the file, after requires.
- Values that affect game balance should be sandbox-configurable if the benefit is
  MEDIUM or higher. Use `POS_Sandbox` accessors with the constant as fallback.
