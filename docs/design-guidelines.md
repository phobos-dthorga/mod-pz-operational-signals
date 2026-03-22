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

### 2.7 Overflow Prevention Rule

Every screen MUST fit within ~22 visible lines at 780px minimum height.
Dynamic content (loops, conditional sections) MUST use pagination or compact
summaries when the item count is unbounded. Before adding content to a screen,
count the existing lines and verify the footer (`drawFooter`) remains visible.

Rules:
- Unbounded lists (categories, indices, operations) → `PhobosLib_Pagination`
  when count exceeds the page-size constant
- Summary screens → compact single-line aggregates instead of per-item listings
  (e.g. "Rising: 4  Stable: 8  Falling: 3" instead of 16 individual lines)
- Early-exit states (empty, cooldown, error) MUST still call `drawFooter(ctx)`

### 2.8 Progress Bars

Use `POS_TerminalWidgets.drawProgressBar(ctx, labelKey, value, colour)` for
any 0-100 range value (power, buffer capacity, XP progress, signal strength,
investment maturity). Text-based rendering (`[####----] 65%`) matches the CRT
aesthetic. Prefer progress bars over raw numeric labels for values that players
need to glance-assess.

For standalone (non-ctx) usage:
`POS_TerminalWidgets.createProgressBar(parent, x, y, w, value, colour, bgColour)`

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
- **Connection gate**: `POS_ConnectionManager.canConnect()` checks power
  at the desktop computer location via `PhobosLib.hasPower(square)`. No
  power = greyed-out context menu option with clear reason text.
- **Power detection**: All wall-power checks (radio and desktop) use
  `PhobosLib.hasPower(square)` which covers grid power, generators, and
  any custom power sources registered by other mods. Do NOT call
  `square:haveElectricity()` directly.
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

### 5.6 Satellite Wiring Connection

The satellite dish can be physically wired to a desktop terminal using `Base.ElectricWire`. This replaces the wireless 50-tile range scan with a persistent wired link stored in world modData.

**Wire cost formula:**
```
wireCount = |dx| + |dy| + (|dz| × SATELLITE_WIRING_Z_PENALTY)
```
Where `SATELLITE_WIRING_Z_PENALTY = 5` (extra wires per floor difference).

**Requirements:**
- `Base.Screwdriver` and `Base.Pliers` in inventory (not consumed)
- Electrical skill ≥ `SATELLITE_WIRING_MIN_ELECTRICAL` (default 2)
- Sufficient `Base.ElectricWire` in inventory (consumed on wire)

**Storage:** Flat keys in `ModData.getOrCreate("POS_Satellite")` keyed by satellite building key. Schema: `targetX`, `targetY`, `targetZ`, `wireCount`, `createdDay`, `linkType`.

**Validation:** `hasTerminalLink()` checks wired link first (Priority 1), then falls back to wireless scan (Priority 2). Stale wiring (desktop removed) is auto-cleared. Unloaded chunks are treated as valid to avoid false negatives.

**Disconnect:** Returns `SATELLITE_WIRING_RETURN_PCT` (75%) of wires rounded down.

**Timed action:** Duration scales with wire count (`SATELLITE_WIRING_TIME_PER_TILE` × wireCount, clamped to `TIME_MIN`–`TIME_MAX`).

**Anti-patterns:**
- ❌ Checking `hasTerminalLink` without considering wired links
- ❌ Using magic numbers for wire cost — always use `PhobosLib.manhattanDistance` with `SATELLITE_WIRING_Z_PENALTY`
- ❌ Storing wiring data as nested tables in modData — use flat keys with prefix

**Implementation references:** `POS_SatelliteService.lua` (wiring CRUD, validation), `POS_SatelliteWiringAction.lua` (timed action), `POS_SatelliteContextMenu.lua` (menu options).

---

## 6. Location Display

### 6.1 Street Addresses

All mission locations must be displayed as human-readable street addresses
using `PhobosLib_Address.resolveAddress()`. Raw coordinates are the
fallback if street resolution fails (e.g. modded maps without
`streets.xml`).

For **player-facing location strings** that combine street address and room
name (e.g. "Rosewood Ave (Kitchen)"), use
`PhobosLib.formatPlayerLocation(player, opts)` instead of manually
assembling address + room. It handles the full format priority chain
(street name, room name fallback, title-casing) in a single call.

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

### 7.5 UI / Business Logic Separation

Screen files (`client/POS_Screen_*.lua`) are **presentation only**. They must:

- **Read** data from services and logs (query, format, display).
- **Delegate** all state mutations to shared service modules.
- **Never** set `op.status`, mutate objectives, grant reputation, pay rewards,
  apply penalties, roll chances, or perform any game-state side effects directly.

All business logic must live in **shared service modules** (`shared/POS_*Service.lua`):

| Service                    | Responsibility                                       |
|----------------------------|------------------------------------------------------|
| `POS_OperationService`     | Operation lifecycle: generate, activate, complete, cancel, expire, tick |
| `POS_NegotiationService`   | Haggling: attempt rolls, reward/deadline adjustments  |
| `POS_InvestmentService`    | Investment lifecycle: fund, expire, create records, resolve |
| `POS_MarketNoteGenerator`  | Market note creation: populate modData, build readable docs |

Screen button callbacks should be **one-liners** that call a service function:

```lua
-- Good: delegate to service
POS_OperationService.completeOperation(op, player)

-- Bad: inline business logic in screen
op.objectives[1].completed = true
op.status = "completed"
POS_RewardCalculator.payReward(player, op.scaledReward, op.baseReputation)
```

This separation ensures:

1. Business rules are testable and reusable without UI dependencies.
2. Multiple screens or entry points (terminal, context menu, tick handler) share
   the same logic path — no risk of divergent behaviour.
3. Screen files remain short, readable, and focused on layout.

Generic utilities that benefit multiple Phobos mods (e.g. `rollChance`,
`getItemDisplayName`) belong in **PhobosLib**, not in POSnet services.

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

#### Equipment-Gated Screens

Screens that depend on physical equipment (Data Recorder, Camera Workstation,
Satellite Dish) must use **`canOpen`** — never `shouldShow`. This ensures the
player can see the screen exists and understands what they need to unlock it,
rather than being unaware the feature is there at all.

- **Visible but locked**: the menu entry appears greyed-out with a short reason
  (e.g., `"Requires Data Recorder"`).
- **Soft prerequisite**: check for the equipment OR its output (raw intel items
  for Analysis, compiled reports for Reports). If the player has the output but
  not the equipment, they should still be able to use the screen.
- **Reason keys**: use `POS_Constants.ERR_*` constants pointing to `UI_POS_Error_*`
  translation keys. Keep reasons concise — the menu renders them inline as
  `"    Screen Title  (Reason)"`.

**Guard hierarchy summary**:

| Guard          | When to use                             | Effect        |
|---------------|-----------------------------------------|---------------|
| `shouldShow`  | Sandbox toggles, band filtering         | Hidden        |
| `canOpen`     | Equipment, processed-data prerequisites | Disabled      |
| `requires`    | Connection, signal, band (declarative)  | Disabled      |

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
- **Strict mode** — see §25 for pcall classification and safecall migration rules

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

## 10. Context Menu Sub-Menu Rule

### 10.1 Grouping Principle

When multiple context-menu actions exist on a single inventory object, they
**must** be grouped into a sub-menu rather than cluttering the top-level
context menu. This applies to all POSnet items — existing and new.

Examples:
- **Data-Recorder** → "Data-Recorder" sub-menu containing: Media Management
  (nested), View Recorder Status
- **Source devices** (camcorder, logger, radio) → "POSnet" sub-menu
  containing: Record Using Data-Recorder
- Any future item with 2+ POSnet context actions must follow this pattern

Full Data-Recorder hierarchy:

```
Data-Recorder (L1)
  ├── Media Management (L2)
  │    ├── Insert Media > (L3, family-grouped)
  │    ├── Eject Media
  │    ├── Auto-Feed [ON/OFF]
  │    ├── Flush Buffer → Media
  │    └── View Media Status
  └── View Recorder Status
```

The Media Management sub-menu groups all media-related operations at L2,
with Insert Media expanding to an L3 family-grouped list of compatible media
items. This keeps the top-level Data-Recorder sub-menu clean (two entries)
while providing full media control one level deeper.

### 10.2 Nested Sub-Menus

When a sub-menu action itself has multiple choices (e.g., "Insert Media"
with multiple compatible media items), use a nested sub-menu. Maximum
nesting depth: 2 levels (top → sub-menu → nested sub-menu).

### 10.3 Auto-Feed & Deep Inventory Search

Auto-feed is a per-recorder toggle stored in recorder modData under the key
`POS_Constants.MD_RECORDER_AUTO_FEED`. It controls whether the recorder
automatically ejects spent media and searches for a replacement when the
current media fills up.

**Behaviour when auto-feed is enabled:**

1. When `appendChunk()` detects the current media is full, it auto-ejects
   the spent media and performs a deep inventory search for a replacement.
2. The deep search uses `PhobosLib.findItemByFullTypeRecurse()` and iterates
   over `USABLE_MEDIA_SEARCH_ORDER` (the ordered list of compatible media
   full-types, cheapest first).
3. If a replacement is found, it is inserted automatically.
4. If **no** replacement is found, auto-feed auto-disables itself and sends
   a PhobosNotifications (PN) warning to the player.

**Behaviour when toggling auto-feed ON with no media loaded:**

- An immediate deep search is performed. If compatible media is found, it is
  inserted into the recorder in the same action. If none is found, the toggle
  reverts to OFF and the player is warned.

**Notification rule:** All outcomes (insert, eject, auto-disable, toggle
state changes) notify via `PhobosLib.notifyOrSay()`.

**Anti-pattern — shallow search only:**
Do **not** use `getItemsFromFullType()` on the main inventory alone. Players
routinely carry media inside bags and containers. Always use
`PhobosLib.findItemByFullTypeRecurse()` to search the full inventory tree.

**Implementation reference:**
`POS_DataRecorderService.findUsableMediaDeep()`,
`POS_DataRecorderService.tryAutoFeedMedia()`.

---

## 11. Data Source Registration

### 11.1 Pattern

All devices that generate passive recon data must register as data sources
via `POS_DataSourceRegistry.register()`. The recorder queries available
sources during the scan cycle rather than hardcoding device logic.

### 11.2 Registration Contract

Each source provides:
- `id` — unique string identifier (e.g., `"camcorder"`)
- `type` — category constant from `POS_Constants.DATA_SOURCE_*`
- `displayNameKey` — translation key for UI display
- `canRecord(player, item)` — returns boolean, whether source can currently record
- `getSignalQuality(player, item)` — returns BPS confidence modifier
- `generateChunk(player, item)` — returns chunk table or nil

### 11.3 Component Crafting Philosophy

The Data-Recorder system follows a component-based crafting philosophy:
- **Tier 0 (Improvised)**: Craftable from scrap — low quality, high availability
- **Tiers 1-3**: Loot/progression — higher quality, rarer
- Sub-components are crafted separately, then assembled into the final device
- Repair recipes restore condition using Electronics skill + scrap materials

---

## 12. Item Selection & Market Intelligence

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

## 13. Data Persistence Rules

### 11.1 World-Scoped State

- Market intelligence is stored in world-scoped Global ModData (`POSNET.World`).
- Building and mailbox caches are stored in `POSNET.Buildings` and `POSNET.Mailboxes`.
- Exchange and wholesaler data live in `POSNET.Exchange` and `POSNET.Wholesalers`.
- Schema version and migration flags are tracked in `POSNET.Meta`.

### 11.2 Player ModData Scope

Player modData is limited to per-player **scalar** state only:
- Reputation, cash balance, intel access bands, UI preferences, cooldowns.
- Growth-prone arrays (watchlist, alerts, orders, holdings) are stored in
  player modData via `PhobosLib.getPlayerModDataTable()` (see §27.6).
  VHS tape entries are in the event log; only a summary is in item modData.

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

## 14. Passive Recon Device Rules

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

## 15. Journal & Document System

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

Locations should use `PhobosLib.formatPlayerLocation(player, opts)` to
produce combined "Street (Room)" strings. This replaces manual address
resolution + room name assembly. When no street data exists, raw room
names are title-cased automatically (e.g., "grocery" -> "Grocery").

### 13.4 Item Filtering

The item pool only includes vanilla (`Base.*`) items by default.
Cross-mod items (PCP, PIP) are registered separately via
`POS_ItemPool.registerItem()` to prevent modded items with incorrect
DisplayCategories from appearing in wrong market categories.

---

## 16. Danger Detection

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

### 14.2a Intel Cooldown Scope

The cooldown is **per room zone**, not per tile. The visit key is:

```
POS_IntelVisit_<buildingDefX>_<buildingDefY>_<roomName>
```

This means:
- Moving to a different tile within the **same room** does NOT reset the cooldown.
- A **different room type** in the same building (e.g. pharmacy vs office) has its
  own independent cooldown.
- A **different building** always has a fresh cooldown.
- Default cooldown: 12 game days (sandbox-configurable via `IntelCooldownDays`).

The key uses `BuildingDef.getX()/getY()` for stable building identity across
save/loads, combined with `IsoRoom.getName()` for room type discrimination.

### 14.3 Passive Recon Gate

Passive recon devices (camcorder, field logger, scanner radio) pause scanning
when danger is detected. A debug log message is emitted for diagnostics.

### 14.4 Sandbox Control

`DangerCheckRadius` (default 15, range 5-30) controls the detection range.
Players in safer areas can reduce this for less restrictive gameplay.

---

## 17. Data Externalization

### 15.1 Principle

ModData (Global or player) is reserved for **capped, bounded** data only.
Unbounded data (discovery caches, event logs) is stored in external flat files
under `Zomboid/Lua/`.

### 15.2 External Files

| File | Format | Contents | Writer |
|------|--------|----------|--------|
| `POSNET_buildings.dat` | Pipe-delimited | Building discovery cache | Server/SP |
| `POSNET_mailboxes.dat` | Pipe-delimited | Mailbox discovery cache | Server/SP |
| `POSNET_market_data.dat` | Section-header + pipe-delimited | Market observations + rolling closes | Server/SP |
| `POSNET_economy_day{N}.log` | Pipe-delimited | Market event log (per day) | Server/SP |
| `POSNET_snapshot_economy.txt` | Pipe-delimited | Economy state snapshot | Server/SP |

### 15.3 Migration

On first load after the externalization update, `POS_WorldState.migrateModDataCaches()`
checks for building/mailbox data in ModData, writes to external files, clears ModData,
and sets `meta.cachesMigrated = true` to prevent re-migration.

Market observations and rolling closes are migrated separately by
`POS_WorldState.migrateMarketDataToFile()`. This moves ~105 KB of data from
`POSNET.World.categories[*].observations[]` and `.rollingCloses[]` to
`POSNET_market_data.dat`, guarded by `meta.marketDataMigrated`. Category
aggregates (~0.6 KB) remain in ModData for MP client snapshot delivery.

### 15.4 Disposability

Discovery caches (buildings, mailboxes) are **disposable** -- if deleted, they
rebuild through natural exploration. Event log files are similarly disposable.

`POSNET_market_data.dat` is the **authoritative store** for market observations
and rolling closes. If deleted, historical intel is lost but the system continues
functioning (aggregates in ModData allow screens to display cached summaries until
new intel is gathered).

### 15.5 Cache Persistence Rules

All discovery caches (buildings, mailboxes) **must** persist to their `.dat` file
after every code path that adds entries: initial scan, passive periodic scan, and
interactive discovery (e.g. right-click mailbox). This avoids data loss between
sessions. The building cache follows this pattern correctly; the mailbox cache
must do the same.

---

## 18. Release & Tagging Doctrine

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

---

## 19. Notification Integration

### 19.1 PhobosLib.notifyOrSay() Pattern

All transient user feedback (action confirmations, warnings, informational
messages) **must** use `PhobosLib.notifyOrSay(player, opts)` instead of raw
`PhobosLib.say()` or direct `PhobosNotifications.toast()` calls.

This wrapper tries PhobosNotifications toast first, then falls back to
`PhobosLib.say()` overhead speech bubble. Players without PN installed still
receive feedback.

Always pass `channel = POS_Constants.PN_CHANNEL_ID` so notifications appear
under the POSnet channel in PN's filter settings.

### 19.2 Channel Registration

POSnet registers one PN channel (`"POSnet"`) via `POS_NotifyInit.lua` on
`Events.OnGameStart`. The channel label key is
`POS_Constants.PN_CHANNEL_LABEL_KEY` (`"UI_POS_Channel_POSnet"`).

If PhobosNotifications is not installed, registration is silently skipped.

### 19.3 Feedback Philosophy

| Mechanism | Use Case | Example |
|-----------|----------|---------|
| `notifyOrSay()` success | Action completed | Upload notes, process chunks |
| `notifyOrSay()` warning | Action had issues | 0 notes ingested |
| `notifyOrSay()` info | Status/informational | Media ejected |
| `PhobosLib.say()` raw | Player-requested inline info | View recorder status |
| Modal popup | Important one-time info | Guide, changelog |

### 19.4 Colour & Priority Guidelines

- **success**: Positive completion (green toast / green text).
- **warning**: Something unexpected or degraded (yellow toast).
- **info**: Neutral status change (default toast colour).
- **error**: Failure that blocks a player goal (red toast). Use sparingly.
- Priority `"normal"` for all routine notifications.
  Reserve `"high"` for time-sensitive alerts (e.g. watchlist price spikes).

---

## 20. Four-Tier Intelligence Hierarchy

POSnet's intelligence pipeline is structured as a four-tier hierarchy. Each tier
represents a distinct level of sophistication, location, and strategic value.
All tiers are independently useful — no tier is a hard dependency on another.

### 20.1 Tier Overview

| Tier | Node | Location | Artifact | Primary Modifier |
|------|------|----------|----------|-----------------|
| I — Capture | Field | Anywhere | Raw Market Notes, recorded media | Equipment quality |
| II — Analysis | Terminal | Radio + computer | Intel Fragments | **SIGINT skill** |
| III — Compilation | Camera Workstation | TV stations | Compiled reports, bulletins | Location + SIGINT |
| IV — Broadcast | Satellite Uplink | Rooftops, military | Regional market effects | SIGINT credibility |

### 20.2 Design Principles

1. **No mandatory bottlenecks.** Raw Market Notes can skip Tiers II-IV and go
   directly into the market database. Each tier is an optional premium path.
2. **Progressive investment.** Higher tiers require more travel, infrastructure,
   materials, and time — but produce proportionally more impactful results.
3. **Independent value.** A player using only Tier I (pen and paper) has a
   complete, functional experience. Each additional tier adds depth, not fixes
   a deficiency.
4. **SIGINT as throughline.** The SIGINT skill connects all tiers as an
   analytical progression — minimal effect at Tier I, primary domain at Tier II,
   secondary influence at Tier III, tertiary influence at Tier IV.

### 20.3 Design Documents

| Tier | Design Document |
|------|----------------|
| I | `passive-recon-design.md`, `data-recorder-design.md` |
| II | `terminal-analysis-design.md` |
| III | `camera-workstation-design.md` |
| IV | `satellite-uplink-design.md` |
| Skill | `sigint-skill-design.md` |

---

## 21. SIGINT Skill Rules

### 21.1 Perk Registration

SIGINT is a custom PZ perk registered under the `Passiv` (passive skills)
parent category. It scales from Level 0 to Level 10 with qualitative tier
names: Noise Drowner (0-2), Pattern Seeker (3-5), Analyst (6-8), Intelligence
Operator (9-10).

### 21.2 Skill Expression Per Tier

| Tier | SIGINT Effect | Strength |
|------|--------------|----------|
| I — Capture | +1 confidence per 3 levels (max +3) | Minimal |
| II — Analysis | Yield, noise filter, time, cross-correlation | **Primary** |
| III — Compilation | Confidence bonus, verification strength | Secondary |
| IV — Broadcast | Credibility weight, persistence | Tertiary |

### 21.3 XP Rules

- XP is earned through **analytical work**, not passive accumulation.
- Primary source: Terminal Analysis (15-25 XP per action).
- XP awards are NOT modified by SIGINT level (no runaway progression).
- Skill books follow the standard PZ pattern (5 books, 2 levels each).
- See `sigint-skill-design.md` Section 5 for the complete XP table.

### 21.4 Trait Rules

- 3 positive traits (Analytical Mind, Radio Hobbyist, Systems Thinker) and
  3 negative traits (Impatient, Disorganised Thinker, Signal Blindness).
- Traits are registered in `POS_Registries.lua`.
- Signal Blindness imposes a hard cap at Level 5 — the only SIGINT-limiting
  trait.
- See `sigint-skill-design.md` Section 7 for costs and effects.

### 21.5 Cross-Mod

- ZScienceSkill: optional XP mirror (0.5x ratio) + 3 SIGINT specimens.
- Dynamic Trading: high-SIGINT discount on information trades (optional).
- See `sigint-skill-design.md` Section 8 for integration details.

---

## 22. Multi-Category Room Intelligence

### 22.1 Concept

Some PZ building room types contain multiple commodity sources. A mall has
food courts, pharmacies, gun shops, hardware stores, and electronics vendors.
A military base has ammunition, tools, medical supplies, and communications
equipment. These rooms should offer intel-gathering for **all** applicable
categories, not just the first pattern match.

### 22.2 MULTI_CATEGORY Table

Multi-category mappings are defined in `POS_RoomCategoryMap.lua` in the
`MULTI_CATEGORY` table. This table takes **precedence** over the `PATTERNS`
table when `getCategories()` is called.

| Room Type | Categories |
|-----------|-----------|
| `mall` | food, medicine, ammunition, tools, radio |
| `military` | ammunition, tools, medicine, radio |
| `hospital` | medicine, food, radio |
| `policestation` | ammunition, radio |
| `firestation` | tools, medicine |
| `industrial` | tools, fuel |

### 22.3 Adding New Multi-Category Rooms

New multi-category rooms must be added to the `MULTI_CATEGORY` table in
`POS_RoomCategoryMap.lua`. Do **not** add duplicate `PATTERNS` entries for
the same room type — `MULTI_CATEGORY` is the authoritative source for rooms
with multiple commodity types.

The `PATTERNS` table retains a single-category fallback entry for backward
compatibility with `getCategory()` (singular), which returns the first match.

### 22.4 Context Menu Behaviour

Per the sub-menu rule (§10.1):

- **1 category** → flat option: `"Gather Market Intel (Food)"`
- **2+ categories** → sub-menu:
  ```
  Gather Market Intel >
    Food
    Medicine
    Ammunition
    ...
  ```

All sub-options share the same cooldown, danger, and item-availability
state. Only the category (and resulting note content) differs.

Category display labels use the existing `UI_POS_Market_Cat_*` translation
keys from `POS_MarketRegistry`.

### 22.5 Room Detection

Room type detection **must** use `PhobosLib.getPlayerRoomName(player)` which
resolves via `getRoom() → getRoomDef() → getName()`. Direct calls to
`IsoRoom:getName()` return an instance identifier, not the room type string,
and must **never** be used for category lookup.

---

## 23. Tutorial & Guidance System

All player-facing tutorials and progressive hints use the milestone-driven
architecture described below.

### 23.1 Milestone-Driven Architecture

- All tutorials are gated by `PhobosLib_Milestone` (`PhobosLib.registerMilestone`,
  `PhobosLib.awardMilestone`, `PhobosLib.hasMilestone`).
- Business logic calls `POS_TutorialService.tryAward(player, milestoneId)`.
- Delivery is decoupled via `triggerEvent("PhobosLib_MilestoneAwarded")`.
- `POS_TutorialService` listens for the event, dispatches toasts, and sets
  popup-ready modData flags.

### 23.2 Delivery Balance

- **Major tier transitions** → Notice Popups (5 total): first connection,
  first operation completed, SIGINT L3, first camera compile, first satellite
  broadcast.
- **Incremental achievements** → toast notifications (9 total): first op
  received, first market note, first analysis, SIGINT L6, SIGINT L9, first
  investment, first delivery, first data recorder use, first cross-correlation.
- Toasts use the `"tutorial"` colour preset (teal) from PhobosNotifications.

### 23.3 Sandbox Gate

- All tutorial activity respects `POS.EnableTutorialHints` (default: true).
- `POS_TutorialService.isEnabled()` is checked before every award attempt.
- When disabled, the system is completely inert — no modData writes, no
  events, no UI.

### 23.4 Idempotency

- `tryAward()` is safe to call from hot paths (every tick, every action).
- After first award, `PhobosLib.awardMilestone()` returns `false` immediately.
- Popup `shouldShow()` gates check both `PopupReady` and `PopupShown` flags.

### 23.5 Translation

- Every tutorial message uses `PhobosLib.safeGetText()`.
- Toast keys: `UI_POS_Tutorial_Toast_*`
- Popup keys: `UI_POS_Tutorial_Popup_*_Title`, `*_Line1` through `*_Line4`
- Sandbox keys: `Sandbox_POS_EnableTutorialHints`, `*_tooltip`

### 23.6 Constants

- All milestone IDs use `POS_Constants.TUTORIAL_*`. No inline strings.
- Milestone groups: `TUTORIAL_GROUP_CORE`, `TUTORIAL_GROUP_SIGINT`,
  `TUTORIAL_GROUP_INTEL`.
- ModData prefixes: `TUTORIAL_POPUP_READY_PREFIX`, `TUTORIAL_POPUP_SHOWN_PREFIX`.

### 23.7 Legacy Migration

- `POS_TutorialService.init()` checks for existing `MD_RECORDER_TUTORIAL_SHOWN`
  modData and auto-awards `first_data_recorder_use` if set.

---

## 24. Living Market & Autonomous Economy

> Full design: `docs/living-market-design.md`

### 24.1 Layer 0 Principle

The market system adds **Layer 0: World Economy** beneath the existing
three-layer architecture. The world produces economic data autonomously;
the player intercepts and exploits it through existing intelligence
pipelines.

### 24.2 Market Agents

- Seven archetypes: Scavenger Trader, Quartermaster, Wholesaler, Smuggler,
  Military Logistician, Speculator, Specialist Crafter.
- Agents are **invisible** — the player infers their existence through
  patterns in observations, not through direct identification.
- Each archetype differs not just by price but by **relationship to
  truth**: some know more than they say, some say more than they know.

### 24.3 Observation Pipeline

- Agents emit observations in the **same schema** as existing intel
  records (`market-exchange-design.md` § 4). The simulation layer is a
  producer of familiar inputs, not a rewrite.
- Three signal classes: **hard** (database records), **soft** (rumours/
  bulletins), **structural** (invisible modifiers to other agents).

### 24.4 Wholesaler Design Rules

- Wholesalers shape the **environment** that observations emerge from.
  They do not directly generate UI data.
- Use **abstract bulk state** (stockLevel, pressure, disruption) — never
  exact crate inventories.
- Six operational states: Stable, Tight, Strained, Dumping, Withholding,
  Collapsing.
- Downstream influence propagates with **delay** (day 1: rumours →
  day 2: stock changes → day 3+: price impact).

### 24.5 Market Zones

- Economy is **geographically fractured**, not global. Each zone tracks
  localised supply, demand, and pressure per category.
- Wholesaler influence may spill over into adjacent zones.

### 24.6 Module Files

The Living Market simulation is split across three shared modules:

| Module | Purpose |
|--------|---------|
| `POS_MarketAgent.lua` | Agent factory, archetype profile accessors, category affinity lookups |
| `POS_WholesalerService.lua` | Wholesaler lifecycle, operational state machine, supply pressure contribution |
| `POS_MarketSimulation.lua` | Simulation orchestrator — agent registry, zone state, per-tick loop |

Archetype profiles, zone tuning, and event definitions live in data-only Lua
files under `Definitions/` (see §26). Schema definitions live alongside the
modules that consume them (`POS_ArchetypeSchema.lua`, `POS_ZoneSchema.lua`,
`POS_EventSchema.lua`, `POS_WholesalerSchema.lua`). Engine-level constants
(archetype IDs, state enums, simulation defaults) remain in `POS_Constants.lua`.
Sandbox accessors live in `POS_SandboxIntegration.lua`.

### 24.7 Sandbox Gate

All Living Market code MUST be gated behind the experimental sandbox option:

```lua
if POS_Sandbox.isLivingMarketEnabled() then
    -- simulation code here
end
```

The simulation tick is integrated into `POS_EconomyTick.lua` Phase 5.75,
wrapped in `PhobosLib.safecall()`. When enabled, it runs every
`POS_Sandbox.getSimulationTickInterval()` game minutes.

### 24.8 Translation Key Conventions

All user-facing Living Market strings use translation keys:

| Domain | Key pattern | Example |
|--------|-------------|---------|
| Agent archetypes | `UI_POS_Agent_<Suffix>` | `UI_POS_Agent_ScavengerTrader` |
| Market zones | `UI_POS_Zone_<Suffix>` | `UI_POS_Zone_WestPoint` |
| Wholesaler states | `UI_POS_Wholesaler_State_<Suffix>` | `UI_POS_Wholesaler_State_Stable` |
| Market events | `UI_POS_MarketEvent_<Suffix>` | `UI_POS_MarketEvent_BulkArrival` |
| Signal classes | `UI_POS_Signal_<Suffix>` | `UI_POS_Signal_Hard` |

Display name accessors (`POS_MarketAgent.getDisplayName()`,
`POS_WholesalerService.getStateDisplayName()`,
`POS_MarketSimulation.getZoneDisplayName()`,
`POS_MarketSimulation.getEventDisplayName()`) read the `name` field from the
definition registry, falling back to the raw ID. Callers should use these
accessors, never hard-coded strings.

### 24.9 Anti-Patterns

- No exact inventories — abstract only.
- No routefinding convoys — abstract transit state.
- No direct player-wholesaler UI — felt through market effects.
- No wholesaler-to-wholesaler commerce in Phase 1.
- Smugglers must be risky, not clownish.
- Speculators must be rare — too many makes the economy silly.
- Old keys are preserved (not deleted) for backward compatibility.

### 24.10 Signal Emission Rules

Hard signal emission (`POS_WholesalerService.emitSignals()`) converts wholesaler
runtime state into observation records that feed `POS_MarketDatabase`. The
following rules govern how those records are produced.

**Visibility gate** — Not every wholesaler emits every tick. High-secrecy
wholesalers are filtered probabilistically:

```lua
if PhobosLib.randFloat(0, 1) > wholesaler.visibility then return end
```

A `visibility` of `1.0` means always visible; `0.3` means 70% of ticks are
silent.

**Price formula** — Observation prices are derived, never hardcoded:

```
price = CATEGORY_BASE_PRICE[catId]
      * (1 + markupBias)
      * WHOLESALER_PRICE_MULTIPLIER[state]
      * (1 +/- SIGNAL_PRICE_NOISE)
```

- `CATEGORY_BASE_PRICE` is a constant table keyed by commodity category ID.
  It includes cross-mod categories: PCP (chemicals, agriculture, biofuel) and
  PIP (specimens, biohazard).
- `markupBias` comes from the wholesaler definition.
- `WHOLESALER_PRICE_MULTIPLIER` maps each of the 6 operational states to a
  multiplier (e.g. Dumping < 1.0, Withholding > 1.0).
- `SIGNAL_PRICE_NOISE` is a small constant (±%) applied via `randFloat` to
  prevent identical prices across ticks.

**Stock bucketing** — The `stockLevel` float is converted to a human-readable
tier via `PhobosLib.getQualityTier()` using the `STOCK_LEVEL_TIERS` threshold
table (abundant / moderate / low / scarce).

**Confidence mapping** — Observation `confidence` is derived from the
wholesaler's `reliability` field, bucketed via `PhobosLib.getQualityTier()`
using `CONFIDENCE_TIERS` (high / medium / low).

**Display names** — All emitted observations use
`PhobosLib.getRegistryDisplayName()` (see §25.5) to resolve human-readable
source and location strings. Every definition file MUST include a
`displayNameKey` field pointing to a valid translation key.

**Source tier** — All Living Market observations are tagged with
`POS_Constants.SOURCE_TIER_BROADCAST`. This places them in the broadcast
intelligence tier alongside satellite and relay data.

**Anti-patterns:**

- Never hardcode price values — always derive from `CATEGORY_BASE_PRICE` and
  multipliers.
- Never hardcode stock strings ("abundant", "scarce") — always bucket via
  `PhobosLib.getQualityTier()` with the canonical `STOCK_LEVEL_TIERS` table.
- Never bypass the visibility gate — even in tests, respect the probabilistic
  filter to avoid unrealistic signal density.

**Zone Pressure Price Bias** — When the Living Market is enabled, zone
pressure from the simulation biases the supply/demand factor inside
`POS_PriceEngine.generatePrice()`.

Formula:

```
pressureFactor = getZonePressure(zoneId, categoryId) * PRICE_ZONE_PRESSURE_WEIGHT
pressureFactor = clamp(pressureFactor, -PRICE_ZONE_PRESSURE_CLAMP, PRICE_ZONE_PRESSURE_CLAMP)
sdFactor       = sdFactor + pressureFactor
```

- The bias is **additive** to the existing `sdFactor`, not multiplicative.
  This preserves the S/D composite's bounded range and prevents runaway
  feedback loops.
- Gated behind the `EnableLivingMarket` sandbox option. When the option is
  OFF, the pressure term is zero and `generatePrice()` behaves identically to
  pre-Living-Market builds.
- Callers pass `zoneId` in the `ctx` table. If `ctx.zoneId` is `nil`, the
  pressure term is skipped entirely (graceful fallback — no error, no bias).
- Constants: `PRICE_ZONE_PRESSURE_WEIGHT = 0.05`,
  `PRICE_ZONE_PRESSURE_CLAMP = 0.10`.

Anti-pattern: never multiply zone pressure directly into `basePrice`. The
pressure effect MUST flow through the S/D composite so that all price
modifiers interact through a single authoritative channel.

### 24.11 Soft Signal Rules (Rumours)

Rumours are the soft-signal counterpart to hard observations. They are
generated when **soft-class events** fire during Phase 4 of
`tickWholesaler()` and provide players with vague, unverified hints about
upcoming market shifts.

**Generation** — When a soft-class event fires (e.g. `convoy_delay`,
`strategic_withholding`), a rumour record is created containing the event ID,
affected region, affected categories, and an impact hint. Hard-class events
(e.g. `bulk_arrival`) MUST NOT generate rumours.

**Storage** — Rumours are stored in world ModData and accessed via
`POS_WorldState.getRumours()`. This follows the same pattern as
`getWholesalers()` and `getMarketZones()`.

**Expiry and cap:**

- `RUMOUR_EXPIRY_DAYS = 7` — rumours older than 7 in-game days are pruned
  during the next tick.
- `RUMOUR_MAX_ACTIVE = 20` — if the cap is exceeded, the oldest rumours are
  discarded first.

**Impact hints** — The hint direction is derived from the event's
`pressureEffect` sign:

- Positive `pressureEffect` → shortage/tightening hint.
- Negative `pressureEffect` → surplus/easing hint.
- Zero `pressureEffect` → neutral/ambiguous hint.

The hint text MUST remain vague (e.g. "supplies may tighten") and never
expose precise numerical values.

**Confidence** — Rumour confidence is always `"low"`. Rumours are unverified
intelligence; they hint at possible conditions but carry no guarantees.

**BBS display** — The BBS screen displays all active (non-expired) rumours in
a paginated list. Each entry shows: event message, region, affected
categories, impact hint, and days remaining until expiry. The BBS hub entry
shows a count badge of active rumours.

**Anti-patterns:**

- Never treat rumours as hard data — they hint, they do not confirm. No
  gameplay system should read rumour records as authoritative price or stock
  signals.
- Never expose the underlying event ID or numerical `pressureEffect` to the
  player. The UI shows only the translated hint string.
- Never generate rumours from hard-class events. The signal class on the
  event definition is the sole discriminator.

### 24.12 Agent Observation Rules

Agent observations are the per-agent counterpart to wholesaler hard signals.
Each tick, every agent in a zone may produce observations for the categories
it has affinity with. These observations reflect the agent's personality
(archetype) and hidden internal state, making each agent a biased lens on the
underlying market conditions.

**Generation** — Each agent iterates its `categories` list weighted by
affinity. For each category that passes a `refreshDays` cooldown and a
probability roll, the agent produces an observation record. Higher-affinity
categories are more likely to generate observations; low-affinity categories
may be skipped entirely.

**Visibility gate** — Before any observations are generated for an agent, a
reliability check is performed. If the agent fails the reliability roll
(based on archetype `reliability` and the current `exposure` meter), the
entire tick is skipped for that agent. This prevents unreliable agents from
flooding the database with low-quality data.

**Hidden state modifiers** — The agent's five hidden-state meters bias the
generated observations:

- High `greed` inflates the reported price (positive price bias).
- High `surplus` deflates the reported price and inflates the reported stock
  level.
- High `exposure` reduces observation confidence (the agent's secrecy is
  compromised, so its reports are less trustworthy).
- Non-zero `trustShift` applies a temporary reliability modifier that decays
  over time.
- `pressure` influences the probability of generating observations at all —
  high pressure increases generation frequency.

**Archetype-specific behaviour:**

- **Smuggler** — Observations have inherently low confidence. Occasional
  "ghost stock" inversion: the agent reports stock in a category where it
  actually has none, producing misleading signals.
- **Speculator** — Price markup bias is amplified beyond what `greed` alone
  would produce. Stock claims may be understated to create artificial scarcity
  signals.
- **Specialist crafter** — Only generates observations for categories where
  affinity exceeds a threshold. Observations in those categories are
  higher-quality (elevated confidence) but narrow in scope.
- **Scavenger** — Extra noise is added to all observation fields. Price and
  stock values jitter more than other archetypes, reflecting the chaotic
  nature of scavenging.

**Source tier** — All agent-generated observations use
`POS_Constants.SOURCE_TIER_FIELD` as the source tier. The observation key is
prefixed with `"agent_"` to distinguish agent observations from wholesaler
hard signals in the database.

**Anti-patterns:**

- Never generate observations from agent meters directly into the UI. All
  agent observations MUST be routed through `POS_MarketIngestion` into
  `POS_MarketDatabase`. The terminal reads from the database, never from
  agent state.
- Never bypass the visibility gate. If the reliability check fails, the
  agent produces zero observations for that tick — no partial output.
- Never expose the agent's hidden meter values to the player. The player
  sees only the resulting observation records (price, stock, confidence).

### 24.13 SIGINT Integration with Living Market

When the Living Market is enabled, the SIGINT intelligence pipeline connects
to the simulation layer. This section defines how each SIGINT tier interacts
with Living Market data.

**Passive recon sampling** — `POS_MarketReconAction` samples zone pressure
via `POS_MarketSimulation.getZonePressure()` with SIGINT-scaled noise added
to the reading. High SIGINT skill produces low noise (accurate pressure
readings); low SIGINT skill produces high noise (readings may diverge
significantly from true zone state). The noise formula is:
`actualPressure + PhobosLib.randFloat(-noiseRange, noiseRange)` where
`noiseRange = BASE_RECON_NOISE * (1 - skillFraction)`.

**SIGINT XP from market events** — When a wholesaler emits a soft-class
event (e.g. state transition, convoy disruption) and the player has an
active passive recon scan in that zone, SIGINT XP is awarded. XP amount is
scaled by the wholesaler's current operational state:

- `Collapsing` / `Dumping` — full XP multiplier (significant event).
- `Strained` / `Withholding` — reduced XP multiplier.
- `Tight` — minimal XP.
- `Stable` — no XP awarded (nothing noteworthy happened).

**Field notes from state transitions** — When a wholesaler transitions into
`Collapsing` or `Dumping` operational state, a field note is generated via
`POS_MarketNoteGenerator`. The note describes the zone and affected
categories in vague terms (no numerical values). A cooldown of once per
in-game day per wholesaler prevents note spam. Only one note is generated
per transition regardless of how many categories the wholesaler covers.

**Camera and satellite analysis** — When the Living Market is enabled,
camera-tier and satellite-tier analysis screens include zone pressure
summaries alongside their standard intelligence output:

- Camera-tier analysis of a zone produces a per-category pressure breakdown
  with trend indicators (rising/falling/stable).
- Satellite-tier broadcast propagates zone state summaries to all connected
  POSnet terminals, showing the aggregate picture across all zones.

**Anti-patterns:**

- Never award SIGINT XP without first checking `POS_Sandbox.isLivingMarketEnabled()`.
  All Living Market XP paths are gated behind the sandbox option.
- Never expose raw zone pressure values in field notes or camera summaries.
  Always use qualitative descriptors (e.g. "tightening", "oversupplied")
  resolved through the stock-tier bucketing system.

---

## 25. Error Handling & Strict Mode

### 25.1 pcall Classification

All pcall usage falls into exactly two categories:

| Type | Purpose | Strict mode | Example |
|------|---------|-------------|---------|
| **NECESSARY** | API probing — checking if a method exists across PZ builds | Always wrapped | `pcall(getDebug)`, `PhobosLib.probeMethod()` |
| **DEFENSIVE** | Protecting against edge cases in gameplay logic | Bypassed in strict mode | Inventory iteration, trait lookup, modData access |

### 25.2 Rules

1. **New defensive pcalls** MUST use `PhobosLib.safecall(fn, ...)` — never raw `pcall()`.
2. **New defensive method calls** MUST use `PhobosLib.safeMethodCall(obj, method, ...)`.
3. **API probing** (testing if a method exists, trying multiple method signatures) keeps raw `pcall()`.
4. **`PhobosLib.pcallMethod`** is reserved for API probing only. Do not use it for defensive wrapping.
5. Strict mode is enabled via sandbox option `PhobosLib.EnableStrictMode`. Default OFF.
6. Before OnGameStart, strict mode is always OFF — boot-phase code is always safe.

### 25.3 Migration Pattern

```lua
-- BEFORE (hides bugs):
local ok, result = pcall(function() return obj:riskyMethod(arg) end)

-- AFTER (strict-mode-aware):
local ok, result = PhobosLib.safecall(function() return obj:riskyMethod(arg) end)

-- Or for method calls:
local ok, result = PhobosLib.safeMethodCall(obj, "riskyMethod", arg)
```

### 25.4 When to Use Strict Mode

- **Development**: Always ON — surfaces hidden errors with full stack traces.
- **Bug reports**: Ask players to enable it and reproduce the crash for better diagnostics.
- **Normal play**: OFF (default) — defensive pcalls protect against edge-case crashes.

### 25.5 Math & Table Utilities

PhobosLib provides generic utilities for simulation formulas. Do NOT
reimplement these locally — use the PhobosLib versions:

| Function | Purpose |
|----------|---------|
| `PhobosLib.clamp(value, min, max)` | Bound a value to [min, max] |
| `PhobosLib.lerp(a, b, t)` | Linear interpolation |
| `PhobosLib.randFloat(min, max)` | ZombRand-based random float |
| `PhobosLib.round(value, decimals)` | Decimal rounding |
| `PhobosLib.map(tbl, fn)` | Array transform |
| `PhobosLib.filter(tbl, predicate)` | Array filter |
| `PhobosLib.lazyInit(initFn)` | Deferred one-shot initialisation (see §27) |
| `PhobosLib.throttle(fn, intervalMinutes)` | Rate-limit an EveryOneMinute handler (see §27) |
| `PhobosLib.formatPlayerLocation(player, opts)` | Combined "Street (Room)" location string (see §6.1) |
| `PhobosLib.hasPower(square)` | Grid + generator + custom power check (see §5.5) |
| `PhobosLib.getRegistryDisplayName(registry, id, fallback)` | Resolve a definition's `displayNameKey` via `getText()`, with fallback (see §26) |
| `PhobosLib.manhattanDistance(x1,y1,z1, x2,y2,z2, zPenalty)` | 3D Manhattan distance with Z penalty (see §5.6) |
| `PhobosLib.consumeItems(player, fullType, count)` | Remove N items from inventory (see §5.6) |
| `PhobosLib.grantItems(player, fullType, count)` | Add N items to inventory (see §5.6) |
| `PhobosLib.checkRequirements(player, opts)` | Composite item/tool/skill check (see §5.6) |

### 25.6 Empty-Data Return Convention

Two rules govern what functions return when they have no data:

1. **Functions that compute/aggregate data** (`getSummary`, `getCommoditySummary`,
   `resolveAddress`) MUST return `nil` when input data is empty — never a table
   with nil-valued named fields.
2. **Functions that list/collect items** (`getRecords`, `getNotes`, `getCache`)
   MAY return `{}` (empty array) — downstream code handles via `#result == 0`
   or `ipairs()`.

**Anti-pattern (BAD):**

```lua
-- BAD: returns non-nil table with nil fields — callers treat as valid data
local summary = { low = nil, high = nil, avg = nil, sourceCount = 0 }
if #records == 0 then return summary end
```

**Correct (GOOD):**

```lua
-- GOOD: forces callers to nil-check before field access
if #records == 0 then return nil end
```

**Why:** In Kahlua, passing `nil` from a named field into string concatenation
or arithmetic triggers a Java `RuntimeException` that `pcall`/`safecall` cannot
catch, causing a silent JVM crash (CTD with no stack trace).

**Implementation references:**
`POS_MarketDatabase.getSummary`, `PhobosLib_Address.resolveAddress`,
`PN_ChannelRegistry.getMutedSet`

---

## 26. Data-Pack Architecture

POSnet uses a **data-pack architecture** for all extensible content. Schemas,
data, and engine logic are cleanly separated so that players and addon mods
can add content without editing core files.

### 26.1 The Pipeline

Every extensible entity type follows the same four-stage pipeline:

1. **Schema** — Declarative field definitions (`POS_ArchetypeSchema.lua` etc.)
2. **Validator** — `PhobosLib.validateSchema()` checks types, ranges, enums, required fields
3. **Registry** — `PhobosLib.createRegistry()` stores validated definitions, rejects duplicates
4. **Loader** — `PhobosLib.loadDefinitions()` batch-loads data-only Lua files via `require`

### 26.2 Data-Only Lua Files

All content definitions use the **data-only Lua** format:

```lua
return {
    schemaVersion = 1,
    id = "scavenger_trader",
    name = "Backroad Scavenger",
    description = "A small-time regional opportunist.",
    behaviour = "baseline_trader",
    tuning = {
        reliability = 0.55,  -- 0.0 to 1.0
        volatility  = 0.45,  -- 0.0 to 1.0
    },
    affinities = {
        food  = 1.0,
        tools = 1.0,
    },
}
```

**Rules:**
- Files contain ONLY a `return { ... }` table — no logic, no functions, no globals
- All files include `schemaVersion` for forward compatibility
- Comments are welcome and encouraged (Lua supports them; JSON does not) —
  inline range hints (e.g. `-- 0.0 to 1.0`) make files self-documenting
- Nesting must not exceed **2 levels** deep (e.g. `tuning.reliability`,
  `affinities.food`). Deeper nesting (3+) quickly becomes hostile to non-coders
- Human-readable `name` fields, not localisation token IDs — the engine
  generates i18n fallbacks internally when needed
- **Behaviour references are always string identifiers** (e.g. `"baseline_trader"`),
  never function pointers or callback names

### 26.3 File Layout

```
common/media/lua/shared/
    Definitions/
        Archetypes/
            scavenger_trader.lua
            quartermaster.lua
            wholesaler.lua
            _template.lua          -- commented reference, never loaded
        Zones/
            muldraugh.lua
            west_point.lua
            ...
            _template.lua
        Events/
            bulk_arrival.lua
            ...
            _template.lua
        Wholesalers/
            _template.lua          -- no built-ins yet
    POS_ArchetypeSchema.lua        -- schema definitions
    POS_ZoneSchema.lua
    POS_EventSchema.lua
    POS_WholesalerSchema.lua
```

### 26.4 What Is Extensible vs. What Is Not

| Extensible (definition files) | Not extensible (engine constants) |
|-------------------------------|----------------------------------|
| Agent archetype profiles & affinities | Archetype ID string constants |
| Market zone tuning & adjacency | Wholesaler operational state enums |
| Market event effects & probabilities | Signal class enums |
| Wholesaler definitions | Simulation parameter defaults |
| (Future: commodity categories) | World ModData keys |

### 26.5 Addon Mod Integration

Third-party mods register content via the registry API — no file scanning, no
manifests, no directory listing:

```lua
-- In addon mod's shared Lua file (loaded after POSnet via loadModAfter)
require "POS_MarketAgent"
local myAgent = require "MyAddonMod/my_custom_agent"
POS_MarketAgent.getRegistry():register(myAgent)
```

Similarly for zones, events, and wholesalers:
```lua
require "POS_MarketSimulation"
POS_MarketSimulation.getZoneRegistry():register(require "MyMod/my_zone")
POS_MarketSimulation.getEventRegistry():register(require "MyMod/my_event")
```

### 26.6 Template Files

Every `Definitions/` subdirectory includes a `_template.lua` with:
- All fields shown with comments explaining purpose and valid ranges
- `enabled = false` so it is never active if accidentally loaded
- Players copy and rename the template, then change values

Players learn by copying and editing — templates are the primary onboarding
surface. Ship ready-made examples alongside templates where practical.

### 26.7 Error Messages

Invalid definitions are **rejected, not crashed**. The validator logs clear,
actionable messages that tell the player exactly what to fix:

```
[POS:Archetype] "road_king" rejected: tuning.volatility: must be at most 1.0 (got: 1.5)
[POS:Zone] "my_zone" rejected: missing required field: id
```

Never surface raw Lua errors to the player (e.g. `attempt to index nil value`).
Every validation failure must state: the entity type, the entity ID, the field
name, the rule that was violated, and the actual value when relevant. This
standard determines whether the system feels **moddable or hostile**.

### 26.8 Schema Versioning

Every definition file includes `schemaVersion = 1`. When schemas evolve:
- The validator warns on version mismatch but does not reject
- Future migrations can read `schemaVersion` to apply transforms
- This applies to all data formats (definition files, event logs, world ModData)

### 26.9 Two-Tier Extensibility

The data-pack system supports two tiers of content creators:

| Tier | Audience | What they do | Skills required |
|------|----------|-------------|-----------------|
| **Simple** | Players | Copy a `_template.lua`, change numeric values and string IDs | Text editor, no coding |
| **Advanced** | Addon modders | Ship definition packs as separate PZ mods, register via `getRegistry():register()` | Basic Lua, PZ mod structure |

Simple-tier users stay in the shallow water (editing values in flat tables).
Advanced-tier users can add entirely new content packs, new behaviour
drivers, and new categories. Both tiers interact only with data and the
registry API — neither touches engine logic.

### 26.10 Schema Compactness

Schemas should start compact. A definition with 10–15 strong, expressive
fields is far better than one with 80 knobs. Add fields only when the engine
actually reads them. Unused schema fields create false promises and
maintenance burden.

When a schema does evolve, the `schemaVersion` field enables safe migration
(see §26.8).

### 26.11 Anti-Patterns

- **Never let players inject functions** — data-only means identifiers, numbers,
  tags, lists, flags, text, and category mappings. No `tickFunction = function(...) end`.
- **Never require players to edit POS_Constants.lua** — that causes merge conflicts,
  update pain, and corruption risk.
- **Never auto-discover files** — PZ Lua has no directory listing API. Use explicit
  `require` paths for built-ins and the registry API for addons.
- **Never over-nest** — if a data structure reaches 3+ levels deep, flatten it.
  Deep nesting turns content files into puzzles.
- **Never skip validation** — every code path that loads external data must
  pass through schema validation. "Trust but verify" is not acceptable;
  **verify unconditionally**.

---

## 27. Init-Time Performance

POSnet modules must not do expensive work during the bootstrap phase
(OnGameStart / frame 0). The PZ engine processes OnGameStart callbacks
synchronously on the main thread — heavy work here causes visible load-screen
stalls and blocks other mods.

### 27.1 Rules

1. **Never run expensive spatial scans at OnGameStart.** Functions like
   `findNearbyBuildings`, `findWorldObjectsBySprite`, and any radius-based
   world queries must be deferred to the **first EveryOneMinute tick** or to
   first user interaction (e.g. terminal open).

2. **Use `PhobosLib.lazyInit(initFn)` for heavy catalogue work.** Modules
   that iterate large datasets (e.g. all game items via `ScriptManager`) but
   are only accessed on user interaction (terminal open, mission generation)
   must wrap their initialisation in `lazyInit`. The init function runs once
   on first access, not at load time.

3. **Use `PhobosLib.throttle(fn, intervalMinutes)` for spatial tick
   handlers.** Any EveryOneMinute handler that performs world scans must be
   throttled. The default throttle interval is **5 game-minutes** unless
   gameplay requires tighter cadence.

4. **Defer file I/O writes to first EveryOneMinute tick.** Only reads are
   needed during the bootstrap phase. Writes (ModData persistence, file-store
   flushes) must wait until the world is fully loaded.

5. **Defer server command requests to first EveryOneMinute tick.**
   `sendClientCommand` calls at frame 0 trigger synchronous processing during
   init and can stall both client and server. Issue them on the first tick
   instead.

### 27.2 Anti-Patterns

- Iterating all game items via `ScriptManager:getAllItems()` at OnGameStart
- Running 250-tile radius spatial scans at frame 0
- Requesting market snapshots from the server during `init()`
- Running `findWorldObjectsBySprite` every 1 game-minute when every 5 suffices

### 27.3 Implementation Reference

| Module | Technique |
|--------|-----------|
| `POS_ItemPool.lua` | Lazy-init via `PhobosLib.lazyInit()` — item catalogue built on first access |
| `POS_DeliveryContextMenu.lua` | Deferred initial scan + throttled passive scans |
| `POS_RadioInterception.lua` | Deferred snapshot request (first tick, not init) |
| `POS_ReconScanner.lua` | Cached active operation to avoid O(n) per-tick scan |

### 27.4 Chunked File Writes

Large file-store saves (e.g. market categories, ledger history) must not
serialise all data in a single `getFileWriter` / `close` cycle. Writing
dozens of categories in one frame causes a visible hitch, especially on
slower hardware or when save data grows over a long-running world.

**Rules:**

1. **Use `PhobosLib.createChunkedWriter` for any save that iterates more
   than a handful of entries.** The writer spreads serialisation across
   multiple `EveryOneMinute` ticks, keeping each frame's cost bounded.

2. **Chunk size must be sandbox-configurable.** Expose the value as a
   sandbox option (default **4**) so server operators can tune the
   trade-off between save latency and per-tick cost.

3. **Guard against overlapping writes.** Check
   `PhobosLib.isChunkedWriteActive(writer)` before starting a new write.
   If a previous write is still in progress, skip or defer.

**Anti-pattern:**

```lua
-- BAD: blocks the main thread for the entire category list
local fw = getFileWriter("POSnet/market_data.txt", true, false)
for _, cat in ipairs(allCategories) do
    serializeCategory(cat, fw)
end
fw:close()
```

**Implementation reference:** `POS_MarketFileStore.lua` —
`serializeCategory` pattern with a chunked writer whose chunk size is
read from `SandboxVars.POS.MarketSaveChunkSize`.

### 27.5 SP-Safe Server Commands

Singleplayer and multiplayer share the same Lua API surface, but the
networking layer behaves differently. Careless `sendServerCommand` calls
can crash the JVM silently during early game frames in SP, and are
unnecessary since the SP client and server share the same process.

**Rules:**

1. **Never call `sendServerCommand` in singleplayer.** It can crash the
   JVM silently during early game frames and serves no purpose when
   client and server share the same process.

2. **All server-to-client broadcasts must go through
   `POS_BroadcastSystem.broadcastToAll()`.** In SP this routes directly
   to `POS_RadioInterception.handleCommand()`, bypassing the network
   layer entirely. In MP it delegates to `sendServerCommand` as normal.

3. **Never duplicate the `broadcastToAll` helper locally.** Individual
   modules must delegate to `POS_BroadcastSystem.broadcastToAll()`
   rather than reimplementing the SP/MP routing logic.

4. **Client-to-server commands that fire at `OnGameStart` must be
   deferred to the first `EveryOneMinute` tick.** Use a one-shot boolean
   flag to ensure the command fires exactly once, after the server-side
   state is fully initialised.

**Anti-patterns:**

```lua
-- BAD: direct sendServerCommand in a server module
sendServerCommand(player, "POSnet", "broadcast", args)
-- GOOD: use the central SP-safe helper
POS_BroadcastSystem.broadcastToAll("broadcast", args)
```

```lua
-- BAD: sendClientCommand inside OnGameStart (may fire before server is ready)
Events.OnGameStart.Add(function()
    sendClientCommand(getPlayer(), "POSnet", "requestPayouts", {})
end)
-- GOOD: defer to first EveryOneMinute tick with a one-shot flag
local _pendingRequest = true
Events.EveryOneMinute.Add(function()
    if _pendingRequest then
        _pendingRequest = false
        sendClientCommand(getPlayer(), "POSnet", "requestPayouts", {})
    end
end)
```

```lua
-- BAD: local copy of broadcastToAll in a module
local function broadcastToAll(cmd, args)
    if isClient() then sendServerCommand(...) else ... end
end
-- GOOD: delegate to the authoritative implementation
POS_BroadcastSystem.broadcastToAll(cmd, args)
```

**Implementation references:**

| File | Role |
|------|------|
| `POS_BroadcastSystem.lua` | Central SP-safe `broadcastToAll` implementation |
| `POS_RadioInterception.lua` | `handleCommand()` — public entry point for SP direct routing |
| `POS_InvestmentLog.lua` | Deferred payout request pattern (one-shot `EveryOneMinute`) |
| `POS_EconomyTick.lua` | Phase 7 uses `broadcastToAll` unconditionally (SP + MP safe) |

### 27.6 Per-Player Data Storage

Per-player data (watchlist, alerts, orders, holdings) MUST use player modData
via `PhobosLib.getPlayerModDataTable(player, key)`, NOT custom file I/O via
`getFileReader`/`getFileWriter`.

**Why:** `getFileReader` causes silent JVM crashes in multiple PZ lifecycle
contexts (OnGameStart, render frames, event ticks). Player modData is
engine-managed, auto-persisted on save, and safe to access at any time.

**Pattern:**

```lua
-- GOOD: engine-managed, safe at any time
local wl = PhobosLib.getPlayerModDataTable(player, POS_Constants.MODDATA_WATCHLIST) or {}

-- BAD: getFileReader crashes the JVM silently in render frames and OnGameStart
local reader = getFileReader("POSNET/player_" .. username .. ".dat", false)
```

**When file I/O IS acceptable:** World-level data (market observations,
building caches) that is NOT tied to a specific player and is accessed from
server-side tick handlers (not render frames). These use
`getFileReader`/`getFileWriter` during `EveryOneMinute` or `OnSave` events.

**Implementation references:**

| File | Role |
|------|------|
| `POS_PlayerState.lua` | Per-player modData access (canonical pattern) |
| `POS_MarketFileStore.lua` | World-level file I/O (acceptable use of getFileReader/getFileWriter) |

---

## 28. Interoperability Principles

### 28.1 Canonical Identity Rule

Every entity (category, zone, archetype, device, event, signal, artifact) must
have a stable string ID defined in `POS_Constants.lua`. Never use display names,
ad-hoc strings, or translation keys as lookup identifiers. IDs are the contract
between subsystems.

Anti-pattern:

```lua
-- BAD: using display name as lookup key
local cat = registry:get("Ammunition & Weapons")

-- GOOD: using canonical ID constant
local cat = registry:get(POS_Constants.CATEGORY_AMMUNITION)
```

### 28.2 Capability-Based Dispatch

Check capabilities or tags, not specific device/object types. This lets future
devices and addon mods plug in without rewriting core logic.

Anti-pattern:

```lua
-- BAD: hardcoding device identity
if deviceType == "camcorder" then captureVisual() end

-- GOOD: checking capability
if device.capabilities and device.capabilities.capture_rawintel then captureRawIntel(device) end
```

Reference: `POS_DataSourceRegistry` already implements this pattern with
`canRecord()` / `getSignalQuality()` / `generateChunk()` callbacks.

### 28.3 Payload Shape Documentation

Every cross-system data structure must have its canonical shape documented. See
`docs/interoperability-matrix.md` for the authoritative payload reference. When
adding a new payload type, document it in the matrix before implementing
consumers.

Canonical shapes currently documented:

- Observation record
- Market effect
- Rumour payload
- Recorder chunk

### 28.4 The Seven Questions

Every new subsystem must answer these questions in its design phase:

1. **What canonical IDs does it use?** — List all ID types from POS_Constants
2. **What payloads does it consume?** — Which data structures does it read?
3. **What payloads does it produce?** — Which data structures does it emit?
4. **What capabilities/tags does it require?** — What must exist for it to function?
5. **What persistence layer owns its truth?** — ModData key, file store, or none?
6. **What events does it emit and listen for?** — PZ events or internal notifications?
7. **What systems should react to its outputs?** — List downstream consumers that need to update when this subsystem's state changes. This drives refresh propagation and future event wiring.

Document the answers in the subsystem's module header comment or in
`docs/interoperability-matrix.md`.

### 28.5 Cross-System Call Discipline

Rules:

1. Use `PhobosLib.safecall(require, "ModuleName")` for optional dependencies —
   never assume a module exists at call time
2. Guard with `if Module and Module.fn then` before calling cross-system
   functions
3. Never directly mutate another subsystem's persistence (e.g., recorder must
   not write to market database; it emits chunks, and the market system ingests
   them)
4. Never read another subsystem's private/internal state — use its public API
5. Screens never mutate shared state directly — they gather params, call a service function, and render the result. All state mutations live in service modules. (Cross-reference: CLAUDE.md "UI / Business Logic Separation")
6. Services never navigate UI — a service may return data or status codes, but must never call `POS_ScreenManager.navigateTo()` or create UI widgets. Navigation belongs in the presentation layer.
7. Forward-looking: when a service mutates state, it should be structured so a future event notification can be added at the mutation point without refactoring. Keep mutations in single authoritative functions, not scattered across multiple callers.
8. When event names are introduced, use dot-namespaced prefixes: `market.*`, `intel.*`, `ops.*`, `delivery.*`, `player.*`, `terminal.*`

Anti-pattern:

```lua
-- BAD: reaching into another module's internal cache
local price = POS_MarketDatabase._clientCache["food"].avgPrice

-- GOOD: using the public API
local summary = POS_MarketDatabase.getSummary("food")
local price = summary and summary.avgPrice
```

### 28.6 Interoperability Anti-Patterns

| Anti-Pattern | Why It's Dangerous | Rule |
|---|---|---|
| **ID drift** | Category names diverge between registries, causing silent lookup failures | All IDs come from POS_Constants (§28.1) |
| **Unvalidated tables** | Raw ad-hoc tables passed between systems cause nil-field JVM crashes | Document payload shapes (§28.3) |
| **Deep internal calls** | Tight coupling makes refactoring impossible | Use public APIs only (§28.5) |
| **Tight coupling threshold** | 3+ systems calling the same function directly | Introduce an event/callback pattern |
| **Display name as key** | Translation changes break lookup logic | Use canonical string IDs |
