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

#### 2.1.1 Root Screen Navigation

Root screens (main menu, or any screen where the navigation stack is empty)
MUST display a `[0] Exit` button that closes the terminal window. Root screens
do NOT show a Back button — there is nowhere to go back to.

#### 2.1.2 Non-Root Screen Navigation

All non-root screens MUST display a `[0] Back` button via `drawFooter()`.
This returns to the previous screen in the navigation stack.

#### 2.1.3 Navigation Guarantee

Every screen MUST call either:
- `POS_TerminalWidgets.drawExitFooter(ctx)` — for root screens
- `POS_TerminalWidgets.drawFooter(ctx)` — for all other screens

No screen should render without a navigation action at the bottom.

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
- Separator character count is dynamically computed from panel width.

### 2.6 Text Overflow Prevention

All button labels MUST be truncated to fit their pixel width using
`PhobosLib.truncateText()`. This prevents text from overflowing button
boundaries and bleeding into adjacent panels.

Rules:
- Button text is truncated with "..." ellipsis if it exceeds button width
- Separator character count is dynamically computed from panel width
- Wrapped text character limits are derived from pixel width via
  `PhobosLib.maxCharsForWidth()`, not hardcoded values
- NavPanel labels are truncated to fit the 172px button width

---

## 3. Sandbox Options Philosophy

- Any mechanic that could be considered **harsh or opinionated** must have
  a sandbox toggle or adjustment.
- This includes: cancellation penalties, negotiation availability, mission
  difficulty scaling, expiry penalties, and reward multipliers.
- The goal is **maximum player choice with minimum grief**.
- Boolean toggles for feature gates; integer sliders for tunable values.
- All sandbox options must have translated labels and tooltips.

### 3.1 Weight Threshold Rule

When exposing category or sub-category weights as sandbox options, only those with
a default weight ≥ 0.5 should be included. This prevents the sandbox options panel
from becoming monolithic. Low-weight categories (cosmetic items, junk) use their
coded defaults silently.

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

### 5.5 Terminal Power Consumption

Desktop terminals consume generator fuel while open, adding real gameplay
cost to terminal usage and giving the shutdown action meaningful purpose.

- **Grid power is free** — drain only applies when grid is off and a
  generator is the power source.
- **Drain rate**: Configurable via `TerminalPowerDrainRate` sandbox option
  (default 0.15%/min, ~11 hours continuous per full generator). Set to 0
  to disable drain entirely.
- **Uses PhobosLib Power API**: `startPowerDrain()` / `stopPowerDrain()`
  handle grid vs generator detection automatically.
- **Power failure**: Terminal auto-closes with `PhobosLib.say()` message
  when power is lost mid-session (generator empty or turned off).
- **Connection gate**: `POS_ConnectionManager.canConnect()` checks
  `square:haveElectricity()` at the desktop computer location. No power
  = greyed-out context menu option with clear reason text.
- **Portable computers**: Use item condition drain (separate system,
  unchanged). Not affected by generator power.
- **Cross-mod drain detection**: Drain rate stored on square modData
  (`POS_PowerDrainRate` / `POS_PowerDrainSession`). If another mod or
  session is already draining at an equal or higher rate, POSnet skips
  its own drain to avoid stacking. If POSnet's rate is higher, it
  replaces the existing drain.

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

---

## 8. Screen Stack Architecture

### 8.1 Architecture Overview

```
POSnet
 ├── POS_API              — Public registration API
 │    ├── registerScreen()
 │    ├── tryRegisterScreen()
 │    ├── registerCategory()
 │    └── checkRequires()
 ├── POS_Registry          — Screen + category storage
 │    ├── screens (by id)
 │    ├── categories (by id)
 │    └── getMenuEntries()
 ├── POS_ScreenManager     — Navigation engine
 │    ├── navigateTo()     — push + guard check
 │    ├── goBack()         — pop
 │    ├── replaceCurrent() — pagination (no stack pollution)
 │    ├── resetTo()        — clear stack
 │    └── getBreadcrumb()  — path from stack
 ├── POS_MenuBuilder       — Dynamic menu generation
 │    └── buildMenu()      — registry → sorted, guarded entries
 └── UI Panels
      ├── ContentPanel     — single reusable ISPanel
      └── StatusPanel      — (future)
```

### 8.2 Screen Registration

All screens **must** register via `POS_API.registerScreen(def)`. Direct calls to
`POS_ScreenManager.registerScreen()` are deprecated.

**Required fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Dot-namespaced (e.g. `pos.bbs.operations`) |
| `menuPath` | table | Menu hierarchy (e.g. `{"pos.bbs"}`) — empty `{}` for programmatic-only |
| `titleKey` | string | Translation key for screen title (used in breadcrumbs + menus) |
| `create` | function | `(contentPanel, params, terminal) → void` |

**Optional fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `destroy` | function | `defaultDestroy` | Widget cleanup |
| `refresh` | function | empty fn | Periodic data refresh |
| `onEnter` | function | nil | Called after `create` — use for data refresh |
| `onExit` | function | nil | Called before `destroy` — use for state cleanup |
| `sortOrder` | number | 1000 | Menu position (lower = higher) |
| `shouldShow` | function | nil | `(player, ctx) → boolean` — menu visibility |
| `canOpen` | function | nil | `(player, ctx) → boolean, reason` — access gate |
| `requires` | table | nil | `{connected, minSignal, bands}` — declarative gate |
| `isRoot` | boolean | false | Root screens cannot be popped |

### 8.3 Guard System

Two guards control screen access:

- **`shouldShow(player, ctx)`** — Should this screen appear in the menu at all?
  Used for band filtering, sandbox toggles, feature gates. Screens that return
  `false` are completely hidden from the menu.

- **`canOpen(player, ctx)`** — Can the player enter this screen right now?
  Used for signal threshold, hardware checks. Returns `false, reason` where
  `reason` is a translation key. Screen appears in menu but is disabled.

- **`requires`** — Declarative shorthand checked by `POS_API.checkRequires()`:
  - `connected = true` — must have active POSnet connection
  - `minSignal = 0.15` — minimum signal strength
  - `bands = {"amateur"}` — must be on one of these bands

Guards are enforced by `POS_ScreenManager.navigateTo()` and by
`POS_MenuBuilder.buildMenu()`.

### 8.4 Lifecycle Flow

```
[navigateTo("pos.bbs.operations", params)]
  → POS_Registry lookup by screen ID
  → requires check (connected, signal, band)
  → canOpen guard check
  → Old screen: destroy() → onExit()
  → New screen: create(contentPanel, params, terminal) → onEnter()
```

- `onEnter` / `onExit` are **optional** — screens that don't define them
  still work normally. Use `onEnter` when a screen needs to refresh data
  on re-entry (e.g. mission list), and `onExit` to clear transient state.

### 8.5 Breadcrumbs

`POS_ScreenManager.getBreadcrumb()` builds a translated path from the
navigation stack using each screen's `titleKey`. Rendered automatically by
`POS_TerminalWidgets.drawHeader()` when stack depth > 0.

Example: `POSnet > BBS > Operations`

Breadcrumbs do NOT appear on the root screen (Main Menu) and are NOT
affected by `replaceCurrent()` (pagination).

### 8.6 Dynamic Menu Generation

`POS_MenuBuilder.buildMenu(menuPath, player, ctx)` returns an ordered list
of `{ def, enabled, reason }` entries for the given menu path.

```lua
local entries = POS_MenuBuilder.buildMenu({"pos.bbs"}, player, ctx)
for i, entry in ipairs(entries) do
    if entry.enabled then
        W.createButton(ctx.panel, ...)
    else
        W.createDisabledButton(ctx.panel, ...)
    end
end
```

Menus are **never hardcoded**. Future screens registered under a menu path
automatically appear without editing menu code.

### 8.7 Dot-Namespaced ID Convention

Screen IDs use dot-separated namespaces:

| Pattern | Example | Use |
|---------|---------|-----|
| `pos.*` | `pos.bbs.operations` | POSnet core screens |
| `myaddon.*` | `myaddon.blackmarket` | Third-party extension screens |

**Third-party screens must use their own namespace.** IDs without a dot or
using the `pos.` prefix from non-core code will be rejected.

### 8.8 Category Registration

Menu categories are registered via `POS_API.registerCategory()`:

```lua
POS_API.registerCategory({
    id = "pos.bbs",
    parent = "pos.main",
    titleKey = "UI_POS_BBSHub_Header",
    sortOrder = 10,
})
```

Categories define the menu hierarchy. Screens target a category via `menuPath`.

### 8.9 Extension Contract

Third-party POSnet terminal screens **must**:

1. Register during client init via `POS_API.tryRegisterScreen()`
2. Provide only translated user-facing strings (via `getText()`)
3. Respect the current theme and relative sizing (use `POS_TerminalWidgets`)
4. Never mutate the navigation stack directly
5. Use POSnet services for player state, signal state, and mission data
6. Degrade gracefully when dependencies are absent
7. Use a namespaced screen ID (e.g. `myaddon.feature.screen`)

### 8.10 Safety Measures

- **`tryRegisterScreen()`** — pcall wrapper for third-party safety
- **Protected hooks** — all lifecycle calls (`create`, `destroy`, `onEnter`,
  `onExit`) are wrapped in `pcall`
- **Lazy construction** — screens are only constructed when navigated to
- **Version handshake** — `POS_Constants.API_VERSION` for future compat checks

---

## 9. Terminal Panel Layout

### 9.1 Three-Column Architecture

The terminal window uses a 3-column layout:

```
POSnetWindow
 ├── NavPanel      (left,  fixed 180px)
 ├── ContentPanel  (center, flex width)
 └── ContextPanel  (right, fixed 200px, collapsible)
```

- **NavPanel** — persistent navigation sidebar showing signal strength indicator,
  connected band, and registry-driven menu items. Highlights the current screen.
- **ContentPanel** — the main screen area where all screen widgets render
  (existing behavior, unchanged).
- **ContextPanel** — context-sensitive detail inspector populated by the current
  screen's `getContextData()` callback.

### 9.2 Panel Clipping (Mandatory)

All three panels use **stencil clipping** to prevent content from bleeding
into adjacent panels. This is enforced at panel creation time via
`setStencilRect()` / `clearStencilRect()` in the panel's `prerender` /
`postrender` hooks.

**Content bleed-over between panels is never acceptable.** If content is too
wide for its panel, it must be clipped (truncated) — not allowed to overflow
into neighboring panels. Clipping is always preferred over overflow.

This applies to:
- Labels that exceed panel width
- Buttons wider than their parent panel
- Wrapped text that miscalculates available width
- Any widget added to a panel

### 9.3 Panel Constants

All panel dimensions are named constants in `POS_TerminalUI.lua`:

| Constant | Value | Description |
|----------|-------|-------------|
| `NAV_PANEL_WIDTH` | 180 | Fixed width of the navigation sidebar |
| `CONTEXT_PANEL_WIDTH` | 200 | Fixed width of the context panel |
| `CONTEXT_COLLAPSE_THRESHOLD` | 900 | Window width below which context hides |
| `PANEL_GAP` | 4 | Gap between adjacent panels |

**Never hardcode panel widths.** Always reference the constants.

### 9.4 Responsive Collapse

- **Full mode** (window width >= 900px): All 3 panels visible.
- **Compact mode** (window width < 900px): NavPanel + ContentPanel only.
- The `contentPanel:getWidth()` changes dynamically — screens already use
  relative sizing via `ctx.pw` from `initLayout()`, so no screen changes needed.
- NavPanel never collapses (always visible when enabled).

### 9.5 Sandbox Toggle

Both side panels can be disabled by the player:
- `EnableNavPanel` (default: true)
- `EnableContextPanel` (default: true)

When both are disabled, the terminal reverts to a single full-width content
panel (original behavior).

### 9.6 NavPanel Contents

The NavPanel is rendered by `POS_NavPanel.render()` and shows:

1. **Signal strength** — colour-coded bar + percentage (red/yellow/green/bright)
2. **Connected band** — amateur/tactical/etc.
3. **Separator**
4. **Menu items** — from `POS_MenuBuilder.buildMenu({"pos.main"}, ...)`, with
   the current screen highlighted via `>` prefix and bright colour.

NavPanel re-renders on every screen transition and refresh cycle.

### 9.7 ContextPanel and `getContextData()` Provider API

Each screen can optionally define `getContextData(params)` that returns
structured data for the context panel:

```lua
screen.getContextData = function(params)
    return {
        { type = "header",    text = "UI_POS_Context_MissionInfo" },
        { type = "kv",        key = "UI_POS_Context_Tier", value = "II" },
        { type = "kv",        key = "UI_POS_Context_Chance", value = "58%",
                              colour = "success" },
        { type = "separator" },
        { type = "bar",       key = "UI_POS_Context_Signal", value = 62 },
    }
end
```

**Item types:**

| Type | Fields | Description |
|------|--------|-------------|
| `header` | `text` (translation key) | Bright section title |
| `kv` | `key` (translation key), `value`, `colour` (optional) | Key-value pair |
| `separator` | — | Dim horizontal line |
| `bar` | `key` (translation key), `value` (0-100), `colour` (optional) | Text progress bar |

**Colour** values reference `POS_TerminalWidgets.COLOURS` keys by name
(e.g. `"success"`, `"warn"`, `"error"`, `"text"`).

Screens without `getContextData` leave the context panel empty.

### 9.8 Content That Does NOT Belong in Side Panels

Per the design philosophy (terminal, not dashboard):

- **No persistent player HUD** (money, reputation, stats) — POSnet is a
  terminal application, not a character screen.
- **No mini-maps** — the `[MAP]` button opens the PZ world map directly.
- **No mission spam lists** — mission lists belong in the content panel
  with proper pagination.

### 9.9 Vertical Design Awareness

The CRT bezel consumes 13% top + 30% bottom = 43% of vertical space.
At 1170px default, usable height is ~667px (~33 lines at 20px lineH).

- Pagination page sizes should adapt to available vertical space using
  `PhobosLib_Pagination`'s `maxHeight` option.
- Headers + footers + breadcrumbs should not exceed ~6 lines combined.
- Screens should test at the minimum window height (780px, ~22 usable lines).

---

## 10. Item Selection & Market Intelligence

### 10.1 Weight-Based Selection

All item selection in the market system uses `PhobosLib.weightedRandom()` with
category/sub-category weights. Higher-weight categories appear more frequently
in both field reconnaissance and broadcasts.

### 10.2 Off-Category Chance

A small randomness factor (`POS_Constants.ITEM_POOL_OFF_CATEGORY_CHANCE`, default 5%)
introduces items from unrelated categories. This simulates the unpredictable nature
of post-apocalyptic trade and prevents market data from being perfectly predictable.

### 10.3 Reputation Influence

Player reputation tier scales price variance:
- Low reputation → wide variance (prices are unreliable estimates)
- High reputation → tight variance (prices are accurate)

This is controlled by the `ReputationAffectsVariance` sandbox option.

### 10.4 Essential Goods Priority

When enabled (`EssentialGoodsPriority` sandbox option), essential categories
(fuel, medicine, food) receive a 1.5× broadcast frequency multiplier, making
survival-critical market data more available to players.

### 10.5 Sub-Category Drill-Down

Terminal screens allow filtering by sub-category (e.g., "Rifle Ammo" within
"Ammunition"). This adds one navigation level but keeps screens uncluttered
with 4-5 sub-categories per parent, paginated if needed.

---

## 11. Data Persistence Rules

### 11.1 World-Scoped State

- Market intelligence is stored in world-scoped Global ModData (`POSNET.World`).
- Building and mailbox caches are stored in `POSNET.Buildings` and `POSNET.Mailboxes`.
- Exchange and wholesaler data live in `POSNET.Exchange` and `POSNET.Wholesalers`.
- Schema version and migration flags are tracked in `POSNET.Meta`.

### 11.2 Player ModData Scope

Player modData is limited to per-player **scalar** state only:
- Reputation, cash balance, intel access bands, UI preferences, cooldowns.
- Growth-prone arrays (watchlist, alerts, orders, holdings) are stored in
  per-player flat files via `POS_PlayerFileStore` (see `persistence-architecture.md`
  Layer 2b). VHS tape entries are in the event log; only a summary is in item modData.

### 11.3 Authority Model

- **Server-authoritative**: only the server (or SP host) writes canonical market
  state via `POS_MarketDatabase.addRecord()`.
- MP clients receive snapshots via `sendServerCommand` (`CMD_MARKET_SNAPSHOT`)
  and store them in an ephemeral local cache. Clients never write world state.
- Clients request snapshots on init and after each `CMD_ECONOMY_TICK_COMPLETE`
  notification.

### 11.4 Rolling Window Caps

All rolling windows are capped by sandbox options with constants as fallbacks:
- `MAX_OBSERVATIONS_PER_CATEGORY` (default 24)
- `MAX_ROLLING_CLOSES` (default 14)
- `MAX_GLOBAL_EVENTS` (default 100)
- `MAX_PLAYER_ALERTS` (default 20)
- `MAX_PLAYER_ORDERS` (default 10)

---

## 12. Passive Recon Device Rules

### 12.1 Device Equip Requirement

Passive scanning only activates when a device is equipped in the appropriate slot.
Merely carrying the device in inventory provides a confidence bonus to manual
note-taking but does NOT trigger passive scanning.

| Device | Equip Slot | Passive Scan | Carry Bonus |
|--------|-----------|--------------|-------------|
| Recon Camcorder | Secondary hand | Yes | +15% confidence |
| Field Survey Logger | Belt/holster | Yes | +10% confidence |
| Data Calculator | N/A | N/A | +5% confidence |
| Vanilla Radio | N/A (must be ON) | Yes | N/A |

### 12.2 VHS Tape Rules

- Tapes are the primary storage medium for passive recon data
- Each tape has a fixed capacity (20/15/8/4 entries by quality tier)
- Tapes degrade with each upload-and-erase cycle (sandbox-configurable rate)
- Tapes become "Worn" when degradation reaches 100% and must be recycled
- VHS tapes CANNOT be used with the Data Calculator (user requirement)
- Minimum continuous operation: 3 in-game days per tape (sandbox-configurable)

### 12.3 Performance Rules

- Passive scanning runs on EveryOneMinute (NOT EveryTick)
- Only one device scans per minute cycle (staggered if multiple equipped)
- Buildings already on current tape are skipped (deduplication)
- Chunk-based detection avoids scanning stationary players repeatedly

### 12.4 Scanner Radio Specifics

- NOT a new item -- any vanilla or modded radio gains passive scanning via POSnet
- Radio MUST be powered on: battery > 0 OR grid electricity on the parent square
- Tier is derived from `TransmitRange` at runtime using `POS_Constants` thresholds:
  - Tier 1 (TransmitRange=0): FM receiver, broadcast listening only, no active scan
  - Tier 2 (1--2000): Basic two-way radio, small scan radius, low confidence
  - Tier 3 (2001--10000): Advanced scanner, medium radius and confidence
  - Tier 4 (>10000): Military-grade, large radius, tactical band access
- **No hardcoded item names** -- detection is fully dynamic via `getDeviceData()`,
  so any radio (vanilla or modded) works automatically without code changes
- Scan radius formula: `floor(TransmitRange / RADIO_RANGE_DIVISOR)`, clamped 1--40
- Confidence modifiers are in BPS (basis points), converted to percentage adjustment
- Only one radio scans per minute cycle (stagger rule, same as other devices)
- FM receivers (TransmitRange=0) receive market broadcasts but do NOT scan buildings
- Military radios (TransmitRange>10000) can access the tactical band

### 12.5 VHS Tape Review Workflow

VHS tapes must be reviewed at a **TV station** (CraftBench entity) to extract
intelligence. The TV station uses vanilla TvWideScreen and TvBlack sprites,
excluding TvAntique (no VCR compatibility).

**Review Process:**
1. Player stands near a TV (vanilla TvWideScreen or TvBlack)
2. Uses `ReviewVHSTape` craftRecipe (requires recorded tape + pen + paper)
3. Each entry review takes 5 minutes (sandbox-configurable)
4. Creates one `RawMarketNote` per entry with category-specific items
5. Paper consumed: SheetPaper2 fully consumed, Notebook loses condition
6. Tape entry count decremented; when 0, tape is blank for reuse

**Universal Intelligence Pipeline:**

| Source | Review Location | Action | Output |
|--------|----------------|--------|--------|
| VHS Tape | TV with VCR | Review VHS Tape (5 min/entry) | RawMarketNote x N |
| Field Logger | Any (right-click) | Transcribe Data (future) | RawMarketNote x N |
| Radio Intercept | VHS tape records | Same as VHS review | RawMarketNote x N |
| Manual Observation | In-field | Gather Intel (5 min) | RawMarketNote x 1 |

Pen and paper is ALWAYS the final medium before POSnet terminal upload.

---

## 13. Journal & Document System

### 13.1 Readable Market Notes

RawMarketNote items are PZ Literature-type documents that can be "Read"
by the player. Each note contains a formatted market intelligence report
with category, location, price observations, and stock assessment.

Document pages are created via `PhobosLib.createReadableDocument()` at
note creation time. The page content mirrors the dynamic tooltip data
but in a more detailed, journalistic format.

### 13.2 Price Formatting

All prices displayed to the player MUST use `PhobosLib.formatPrice(value)`
which ensures consistent 2-decimal-place formatting (e.g., "$0.60" not "$0.6").

### 13.3 Location Display

Locations should display resolved street addresses when available
(via PhobosLib_Address). When no street data exists, raw room names
are title-cased via `PhobosLib.titleCase()` (e.g., "grocery" -> "Grocery").

### 13.4 Item Filtering

The item pool only includes vanilla (`Base.*`) items by default.
Cross-mod items (PCP, PIP) are registered separately via
`POS_ItemPool.registerItem()` to prevent modded items with incorrect
DisplayCategories from appearing in wrong market categories.

---

## 14. Danger Detection

### 14.1 PhobosLib.isDangerNearby()

All POSnet actions requiring concentration (intel gathering, passive recon scanning,
VHS tape review) are gated by `PhobosLib.isDangerNearby(player, radius)`.

Threats detected:
- **Live zombies** within radius tiles (cell zombie list iteration)
- **Active fires** on nearby squares (IsoFire instanceof check)
- **Player in combat** (isInCombat API if available)

### 14.2 Context Menu Integration

The intel gathering context menu uses a 6-state priority system:

| Priority | State | Colour | Tooltip |
|----------|-------|--------|---------|
| 1 | System disabled | Hidden | -- |
| 2 | Wrong location | Yellow | No relevant intel to gather here |
| 3 | Danger nearby | Red | Threats detected -- clear area first |
| 4 | Missing items | Yellow | Need writing implements |
| 5 | On cooldown | Grey | Intel recently gathered here |
| 6 | Ready | Green | Gather intel |

### 14.3 Passive Recon Gate

Passive recon devices (camcorder, field logger, scanner radio) pause scanning
when danger is detected. A debug log message is emitted for diagnostics.

### 14.4 Sandbox Control

`DangerCheckRadius` (default 15, range 5-30) controls the detection range.
Players in safer areas can reduce this for less restrictive gameplay.

---

## 15. Data Externalization

### 15.1 Principle

ModData (Global or player) is reserved for **capped, bounded** data only.
Unbounded data (discovery caches, event logs) is stored in external flat files
under `Zomboid/Lua/`.

### 15.2 External Files

| File | Format | Contents | Writer |
|------|--------|----------|--------|
| `POSNET_buildings.dat` | Pipe-delimited | Building discovery cache | Server/SP |
| `POSNET_mailboxes.dat` | Pipe-delimited | Mailbox discovery cache | Server/SP |
| `POSNET_economy_day{N}.log` | Pipe-delimited | Market event log (per day) | Server/SP |
| `POSNET_snapshot_economy.txt` | Pipe-delimited | Economy state snapshot | Server/SP |

### 15.3 Migration

On first load after the externalization update, `POS_WorldState.migrateModDataCaches()`
checks for building/mailbox data in ModData, writes to external files, clears ModData,
and sets `meta.cachesMigrated = true` to prevent re-migration.

### 15.4 Disposability

Event log files and cache files are **not the source of truth** -- that remains
in ModData (capped observations, rolling closes). If external files are deleted,
the game continues normally. Caches rebuild through natural exploration.

---

## 16. Release & Tagging Doctrine

All Phobos PZ mods follow the release architecture defined in
[`docs/release-architecture.md`](release-architecture.md).

### Key Rules

1. **Annotated tags only**: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
2. **Tags are immutable**: never delete, re-tag, or edit a published tag
3. **Pre-release for dev branches**: use `-beta.N` or `-rc.N` suffixes
4. **Stable from main only**: bare `vX.Y.Z` tags only on `main`
5. **SemVer**: `MAJOR.MINOR.PATCH` — commit prefixes determine bump level
6. **ZIP artifacts**: every release includes a clean mod ZIP + `manifest.json`
7. **Dependency declarations**: `dependencies.json` at repo root declares hard deps
8. **Conventional commits**: `feat:`, `fix:`, `docs:`, `chore:` prefixes required
