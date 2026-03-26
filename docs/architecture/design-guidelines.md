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

- The **main menu** must remain uncluttered. Use sub-menus (hubs).
- **BBS** is the hub for all operational content:
  - `[1] Investments`
  - `[2] Assignments` (tabbed: Operations + Deliveries)
- **Markets** is the hub for all economy/trading content:
  - `[1] Market Overview` (consolidated: intel summary + commodities + zone data)
  - `[2] Known Contacts` (consolidated: traders + wholesalers + trade entry)
  - `[3] Market Signals` (consolidated: event log + rumours)
  - `[4] Watchlist` (includes absorbed price ledger data)
  - `[5] Market Reports`
  - `[6] Trade Catalog` (inline confirm flow, no separate confirm/receipt screens)
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

#### 5.3.1 Radio Power Reference

| Radio | Full Type | TransmitRange | Signal % (ref=10,000) |
|---|---|---|---|
| WalkieTalkie 1 | Base.WalkieTalkie1 | 750 | 0.6% |
| WalkieTalkie (makeshift) | Base.WalkieTalkieMakeShift | 1,000 | 1.0% |
| WalkieTalkie 2 | Base.WalkieTalkie2 | 2,000 | 4.0% |
| WalkieTalkie 3 | Base.WalkieTalkie3 | 4,000 | 16.0% |
| Ham Radio (makeshift) | Base.HamRadioMakeShift | 6,000 | 36.0% |
| Ham Radio 1 | Base.HamRadio1 | 7,500 | 56.3% |
| WalkieTalkie 4 | Base.WalkieTalkie4 | 8,000 | 64.0% |
| WalkieTalkie 5 (military) | Base.WalkieTalkie5 | 16,000 | 100% |
| Ham Radio 2 (military) | Base.HamRadio2 | 20,000 | 100% |
| Man-Pack Radio | Base.ManPackRadio | 20,000 | 100% |

Commercial receivers (RadioBlack, RadioRed, RadioMakeShift, CDplayer) have
TransmitRange = 0 and cannot connect to POSnet.

#### 5.3.2 Signal Quality Thresholds

| Range | Quality | Reward Multiplier |
|---|---|---|
| 80–100% | EXCELLENT | 90–100% |
| 50–79% | GOOD | 75–89% |
| 25–49% | WEAK | 62–74% |
| 15–24% | CRITICAL | 57–62% |
| 0–14% | Cannot connect | N/A |

Reward scaling formula: `rewardMultiplier = 0.5 + 0.5 * signalStrength`

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

### 5.4 Signal Strength Mission Influence

> **Status**: Implemented. Reward scaling + difficulty cap + briefing garble.

Radio signal strength influences mission generation:
- **Difficulty cap**: weak signal can only receive simple missions (25% signal
  = max difficulty 2; 50% = 3; 75% = 4; 100% = all)
- **Briefing garble**: below `SIGNAL_GARBLE_THRESHOLD` (80%), words are
  randomly replaced with static fragments (`"...static..."`, `"[garbled]"`,
  `"--bzzt--"`). Intensity scales inversely with signal.
- **Reward scaling**: already existed via `POS_RewardCalculator.scaleReward()`
- Gated by `POS_Sandbox.isSignalAffectsMissionRange()`

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

PhobosLib_Address uses a three-tier data fallback:
1. **PhobosLib_StreetData** — 1,087 hardcoded Knox County street segments
   (Muldraugh, Riverside, Rosewood, West Point, Louisville, March Ridge,
   Ekron, Brandenburg, rural roads, railroads, highways). Primary source.
2. **streets.xml** — parsed from all loaded map directories. Catches
   mod-added map packs (Raven Creek, Greenport, etc.) automatically.
3. **Raw coordinates** — `"x, y"` when no data covers the area.

`POS_BuildingCache` pre-computes street addresses at discovery time
(`entry.addressStr`). Modules should prefer `bldg.addressStr` over
calling `resolveAddress()` repeatedly at render time.

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

Example: `POSnet > BBS > Assignments`

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

The terminal window uses a 3-column layout following a **perception →
interaction → action** triad:

```
POSnetWindow
 ├── SignalPanel   (left,  fixed ~180px)   "The world speaks"
 ├── ContentPanel  (center, flex width)    "I observe and choose"
 └── ContextPanel  (right, fixed ~200px)   "I act upon it"
```

- **SignalPanel** (left) — passive intelligence feed. Read-only, constantly
  updating, requires no interaction. Shows what the world is doing.
- **ContentPanel** (center) — the main screen area where all screen widgets
  render. Where the player reads, selects, and navigates.
- **ContextPanel** (right) — context-sensitive action and insight layer.
  Adapts based on what is selected in the center panel.

> **Implementation status**: All three panels are implemented.
> SignalPanel (`POS_SignalPanel.lua`), ContentPanel, and ContextPanel
> (`POS_ContextPanel.lua`) are live with event-driven updates via
> `POS_Events` (Starlit LuaEvent).

### 9.2 SignalPanel — Passive World Awareness (Left)

The left panel should **never feel "opened"** — it should feel alive. Its
role is ambient perception: what the world whispers to the player right now.

**Content (v1 target):**

1. **Signal feed** — last 5 intercepted events (ambient intel, passive recon
   results, market chatter snippets, NPC trade rumours)
2. **Network status** — connected devices (satellite, antennas, terminal),
   signal strength, band availability, power consumption
3. **World-state alerts** — price spikes, supply shortages, unusual signal
   clusters, military band activity
4. **Background processes** — "Scanning...", "Decoding...", "Processing VHS
   data..." with progress indicators

**Design principles:**
- No interaction required — purely read-only
- Always updating — refreshes on relevant POS.Events (see §40)
- Low cognitive load — concise, scannable, never overwhelming
- Alive, not static — this panel is the mod thinking in the background

### 9.3 ContextPanel — Player Agency & Action (Right)

The right panel is about **control, intent, and consequence**. It adapts to
whatever is selected in the center panel.

**Content (v1 target):**

1. **Context actions** — buttons that change based on selection:
   "Initiate Trade", "Analyze Data", "Broadcast Offer", "Link Device"
2. **Deep info card** — commodity breakdown (supply/demand, volatility),
   device stats (range, power draw), signal metadata (origin, strength)
3. **Active task list** — execution queue with progress and time remaining:
   "Scanning (2m remaining)", "Decoding tape..."
4. **Modifiers** (future) — scan power boost, bandwidth allocation, trade
   aggressiveness

**Design principles:**
- Only appears when relevant — empty/hidden when nothing is selected
- Actionable — every element has a purpose
- High information density — concise key-value pairs, not verbose text

### 9.4 `getContextData()` Provider API

Each screen can optionally define `getContextData(params)` that returns
structured data for the ContextPanel:

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

| Type | Fields | Description |
|------|--------|-------------|
| `header` | `text` (translation key) | Bright section title |
| `kv` | `key`, `value`, `colour?` | Key-value pair |
| `separator` | — | Dim horizontal line |
| `bar` | `key`, `value` (0-100), `colour?` | Text progress bar |

Screens without `getContextData` leave the ContextPanel empty.

### 9.5 Panel Constants

All panel dimensions are named constants in `POS_TerminalUI.lua`:

| Constant | Value | Description |
|----------|-------|-------------|
| `SIGNAL_PANEL_WIDTH` | 180 | Fixed width of the signal feed panel |
| `CONTEXT_PANEL_WIDTH` | 200 | Fixed width of the context panel |
| `CONTEXT_COLLAPSE_THRESHOLD` | 900 | Window width below which ContextPanel hides |
| `PANEL_GAP` | 4 | Gap between adjacent panels |

**Never hardcode panel widths.** Always reference the constants.

### 9.6 Responsive Collapse

- **Full mode** (window width >= 900px): All 3 panels visible.
- **Compact mode** (window width < 900px): SignalPanel + ContentPanel only
  (ContextPanel collapses).
- ContentPanel width adapts dynamically — screens use relative sizing via
  `ctx.pw` from `initLayout()`.

### 9.7 Event-Driven Panel Binding

When the Starlit LuaEvent integration (§40) is implemented, panels will
subscribe to POS.Events:

- **SignalPanel** subscribes to: `OnMarketSnapshotUpdated`,
  `OnSignalStateChanged`, `OnConnectionStateChanged`,
  `OnScreenInvalidationRequested`
- **ContextPanel** subscribes to: selection change events from the center
  panel, `OnTradeCompleted`, `OnMissionGenerated`

This enables loose coupling between panels — the center panel never directly
calls the side panels; it emits events and they react.

### 9.8 Content That Does NOT Belong in Side Panels

- **No persistent player HUD** (money, reputation, stats) — POSnet is a
  terminal application, not a character screen.
- **No mini-maps** — the `[MAP]` button opens the PZ world map directly.
- **No mirroring** — side panels must never duplicate center panel content.
- **No mandatory interaction** — side panels augment, never gate.
- **No button overload** — side panels are concise, not cluttered.

### 9.9 Vertical Design Awareness

The telnet-style frame consumes a 24px header bar + 24px status bar = 48px
of vertical space (~4% at default 1170px). Usable content height is ~1122px
(~56 lines at 20px lineH).

- Pagination page sizes should adapt to available vertical space using
  `PhobosLib_Pagination`'s `maxHeight` option.
- Headers + footers + breadcrumbs should not exceed ~6 lines combined.
- Screens should test at the minimum window height (780px, ~36 usable lines).

### 9.10 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Mirroring same info across panels | Wastes space, confuses the triad |
| Making side panels mandatory to use | Augment, never gate |
| Overloading side panels with buttons | High density ≠ cluttered |
| Static side panels with no "life" | Panels must feel alive and responsive |
| Direct cross-calls between panels | Use events (§40) for loose coupling |

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
[`docs/architecture/release-architecture.md`](release-architecture.md).

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

## 20. Five-Tier Intelligence Hierarchy

POSnet's intelligence pipeline is structured as a five-tier hierarchy. Each tier
represents a distinct level of sophistication, location, and strategic value.
All tiers are independently useful — no tier is a hard dependency on another.

### 20.1 Tier Overview

| Tier | Node | Location | Artifact | Primary Modifier |
|------|------|----------|----------|-----------------|
| I — Capture | Field | Anywhere | Raw Market Notes, recorded media | Equipment quality |
| II — Analysis | Terminal | Radio + computer | Intel Fragments | **SIGINT skill** |
| III — Compilation | Camera Workstation | TV stations | Compiled reports, bulletins | Location + SIGINT |
| IV — Broadcast | Satellite Uplink | Rooftops, military | Regional market effects | SIGINT credibility |
| V — Command | Strategic Relay | Fire stations, military | Network coordination | Infrastructure quality |

### 20.2 Design Principles

1. **No mandatory bottlenecks.** Raw Market Notes can skip Tiers II-V and go
   directly into the market database. Each tier is an optional premium path.
2. **Progressive investment.** Higher tiers require more travel, infrastructure,
   materials, and time — but produce proportionally more impactful results.
3. **Independent value.** A player using only Tier I (pen and paper) has a
   complete, functional experience. Each additional tier adds depth, not fixes
   a deficiency.
4. **SIGINT as throughline.** The SIGINT skill connects all tiers as an
   analytical progression — minimal effect at Tier I, primary domain at Tier II,
   secondary influence at Tier III, tertiary influence at Tier IV, network
   management at Tier V.
5. **Each tier transmits a different class of truth.** Tier I transmits
   observations. Tier II transmits interpretations. Tier III transmits
   validated packages. Tier IV transmits public influence. Tier V transmits
   network intent. See §20.4 for the full sending taxonomy.

### 20.3 Tier IV vs Tier V Distinction

Tier IV and Tier V serve fundamentally different roles:

| Attribute | Tier IV (Broadcast) | Tier V (Command) |
|-----------|--------------------|--------------------|
| Role | Broadcast compiled intelligence outward | Coordinate the network itself |
| Scope | Regional | Network-wide |
| Output | Narrative (influence perception) | Intent (route, prioritise, fuse) |
| Interaction | One-to-many | Many-to-many |
| Player feel | "I speak" | "I orchestrate" |
| Hardware | Portable/findable dish | Permanent fixed installation |

**Hard Rule**: If Tier IV starts doing routing, filtering, or coordination,
it has become Tier V. If Tier V starts directly authoring public
broadcasts, it has become Tier IV. Keep the boundary clean.

### 20.4 Sending Taxonomy (All Tiers)

Every tier can transmit, but each tier transmits a different class of truth:

| Tier | Class | Examples |
|------|-------|----------|
| I — Field | **Observations** | Recon snippets, tagged coordinates, item sightings, danger markers, distress bursts, courier drop notices, crude market whispers |
| II — Terminal | **Interpretations** | Cleaned intel fragments, target packages, mission submissions, contact updates, trade intent notices, agent recall requests |
| III — Compilation | **Validated Packages** | Compiled site surveys, market bulletins, reviewed media packages, confidence-rated summaries, wholesaler dossiers |
| IV — Broadcast | **Public Influence** | Market guidance, scarcity alerts, opportunity pings, faction influence broadcasts, destabilising rumours or stabilising truth |
| V — Command | **Network Intent** | Relay directives, agent dispatch envelopes, synchronisation packets, market coordination orders, threat advisories, priority overrides |

Tier I sending is messy, narrow, lossy, and delayed — it should feel human
and improvised. Tier II is deliberate and formatted. Tier III is portable,
tradeable, and authoritative. Tier IV affects systems, not just records.
Tier V is the first tier where POSnet stops feeling like a terminal and
starts feeling like an infrastructure organism.

### 20.5 Design Documents

| Tier | Design Document |
|------|----------------|
| I | `passive-recon-design.md`, `data-recorder-design.md` |
| II | `terminal-analysis-design.md` |
| III | `camera-workstation-design.md` |
| IV | `satellite-uplink-design.md` |
| V | `tier-v-strategic-relay-design.md` |
| Skill | `sigint-skill-design.md` |
| Signal | `signal-ecology-design.md` |

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

### 21.5 Access Rule

**SIGINT gates data quality, never screen access.** All terminal screens
are fully navigable from SIGINT Level 0. Low-SIGINT players see noisier
data, lower confidence ratings, and fewer ambient discoveries — but they
can access every screen, accept every visible contract, and browse every
market view.

| SIGINT Range | Effect |
|-------------|--------|
| 0-2 | Noisy data, low confidence, fewer ambient discoveries |
| 3-5 | Reduced noise, medium confidence, pattern recognition |
| 6-8 | High-fidelity data, early event detection, better prices |
| 9-10 | Near-perfect intelligence, rare intercepts, predictive edge |

Do NOT add `canOpen` or `sigintRequired` gates to screens or contracts.
Equipment gates (Data Recorder, radio connection) are fine — they require
physical tools, not skill level.

### 21.6 Cross-Mod

- ZScienceSkill: optional XP mirror (0.5x ratio) + 3 SIGINT specimens.
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

> Full design: `docs/architecture/living-market-design.md`

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

Living Market is always active — the experimental sandbox gate has been removed.
`POS_Sandbox.isLivingMarketEnabled()` is retained for backward compatibility
and always returns `true`.

The simulation tick is integrated into `POS_EconomyTick.lua` Phase 5.75,
wrapped in `PhobosLib.safecall()`. It runs every
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
- Living Market is always active — the pressure term is always applied.
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

- Living Market is always active — SIGINT XP paths no longer require a gate check.
- Never expose raw zone pressure values in field notes or camera summaries.
  Always use qualitative descriptors (e.g. "tightening", "oversupplied")
  resolved through the stock-tier bucketing system.

### 24.14 Ambient Intelligence Rules

Ambient intel provides a passive trickle of low-confidence market data when
the player is connected to the POSnet network. It requires no equipment
beyond a terminal connection.

**Rules:**

1. Ambient observations are always `CONFIDENCE_LOW` and `SOURCE_TIER_BROADCAST`
   — they never produce high-quality data.
2. Price noise is ±25% (`AMBIENT_INTEL_PRICE_NOISE`) — significantly less
   accurate than field data (±10%) or agent data (±10–20%).
3. Generation gated by active terminal connection
   (`POS_ConnectionManager.isConnected()`).
4. Interval configurable via sandbox (`POS.AmbientIntelInterval`, default 30
   game-minutes).
5. Volume: 1–3 observations per interval — a trickle, not a flood.
6. Anti-repetition: `PhobosLib.avoidRecent()` prevents the same category
   appearing consecutively.
7. Max 50 ambient records in database — oldest pruned when exceeded.
8. Source names drawn from flavour pool (8 translated keys) for variety.

**Anti-patterns:**

| Anti-Pattern | Why It's Wrong |
|---|---|
| High-confidence ambient data | Undermines the value of active recon equipment |
| Large volume per tick | Drowns out player-collected intel |
| No connection gate | Player should feel the difference between connected/disconnected |
| Hardcoded source names | Source pool must be translatable and extensible |

**Implementation reference:** `POS_AmbientIntel.lua`

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
| `PhobosLib.findItemInList(player, itemTypes)` | Find the first matching item from an array of full types (see §29) |
| `PhobosLib.getConfigurable(sandboxKey, default)` | Fetch a sandbox option with fallback default (see §29) |
| `PhobosLib.resolveThresholdTier(value, thresholds)` | Map a numeric value to a named tier via threshold table (see §29) |
| `PhobosLib.resolveTokens(text, ctx)` | Replace `{key}` tokens in a string from a context table; nil-safe (see §31) |
| `PhobosLib.pickWeighted(entries, ctx)` | Select a random entry from a weighted array, condition-filtered (see §31) |
| `PhobosLib.conditionsPass(entry, ctx)` | Check if an entry's conditions match a context (see §31) |
| `PhobosLib.avoidRecent(entryId, history, maxSize)` | Rolling history dedup for weighted selections (see §31) |

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
`docs/architecture/interoperability-matrix.md` for the authoritative payload reference. When
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
`docs/architecture/interoperability-matrix.md`.

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

---

## 29. Recipe Callback Patterns

All recipe callbacks in POSnet must follow a strict delegation pattern. The
callback function itself is a **thin delegator** — 3–5 lines maximum, with
zero business logic. All shared concerns live in `POS_CraftHelpers`.

### 29.1 Delegation Rule

Every `OnCreate` / `OnCanPerform` callback must delegate to
`POS_CraftHelpers` for the following shared concerns:

- **Writing implement damage** — type lookup via
  `POS_Constants.WRITING_IMPLEMENTS`, condition drain via
  `POS_CraftHelpers.damageWritingImplement()`.
- **Confidence resolution** — call
  `PhobosLib.resolveThresholdTier(skillLevel, POS_Constants.CONFIDENCE_THRESHOLDS)`
  to map the player's skill level to a confidence tier string.
- **Note generation** — delegate to `POS_CraftHelpers.generateNote()` or
  equivalent helper that builds the note body and attaches it to an item.
- **Media initialisation** — delegate to `POS_CraftHelpers.initMedia()` for
  any item that carries embedded media state (tapes, disks, film).

### 29.2 Sandbox Configuration

Sandbox-configurable parameters (e.g. base confidence, damage multiplier,
output counts) must be fetched via `PhobosLib.getConfigurable(sandboxKey,
default)` — never read directly from `SandboxVars` inside the callback.
This keeps the sandbox fetch centralised and testable.

### 29.3 Item Lookup

When a callback needs to find a specific item from the player's inventory
(e.g. a writing implement or a media blank), use
`PhobosLib.findItemInList(player, POS_Constants.WRITING_IMPLEMENTS)` rather
than iterating manually. The constant array is the single source of truth
for accepted item types.

### 29.4 Anti-Patterns

| Anti-Pattern | Why It's Dangerous | Correct Approach |
|---|---|---|
| **Duplicated sandbox fetch blocks** | Divergent defaults when one copy is updated but the other is missed | Single `PhobosLib.getConfigurable()` call in the helper |
| **Hardcoded item types** | Adding a new writing implement requires editing every callback | Use `POS_Constants.WRITING_IMPLEMENTS` array |
| **Direct method calls without safecall** | Kahlua nil-field crashes propagate as silent CTDs | Wrap cross-module calls in `PhobosLib.safecall()` |
| **Business logic in the callback** | Callbacks become untestable and diverge over time | Delegate to `POS_CraftHelpers` — callback body is 3–5 lines |

---

## 30. Standalone Trading System

POSnet includes a direct trading system that lets players buy and sell
physical items through wholesalers via the terminal. All transactions flow
through `POS_TradeService` (shared service); screens are presentation only.

### 30.1 Trading Rules

- **Buy** removes items from wholesaler stock and grants them to the player.
  Buying depletes the wholesaler's `stockLevel` by
  `TRADE_STOCK_DEPLETION_PER_UNIT * quantity`.
- **Sell** consumes items from the player's inventory and adds money.
  Selling replenishes the wholesaler's `stockLevel` by
  `TRADE_STOCK_REPLENISH_PER_UNIT * quantity`.
- After every transaction the wholesaler's operational state is
  re-evaluated via `POS_WholesalerService.resolveOperationalState()`.
  A large buy can push a wholesaler from Stable into Tight; a large sell
  can pull it back.
- Transactions are **atomic**: if item grant or money removal fails, the
  entire transaction rolls back (items returned, money refunded).
- Each transaction awards SIGINT XP. Bulk orders award a bonus
  (`SIGINT_XP_TRADE_BULK_BONUS`) on top of the base.

### 30.2 Price Formula

Buy price:

```
buyPrice = floor(basePrice * stateMultiplier * (1 + markupBias))
```

- `basePrice` — from `POS_PriceEngine.generatePrice()` if available,
  otherwise `POS_ItemPool.getBasePrice()`, otherwise `PRICE_MIN_OUTPUT`.
- `stateMultiplier` — `WHOLESALER_PRICE_MULTIPLIER[state]` (e.g. Dumping
  has a lower multiplier, Withholding has a higher one).
- `markupBias` — per-wholesaler markup from the wholesaler definition.

Sell price:

```
sellPrice = floor(buyPrice * SellPriceRatio)
```

`SellPriceRatio` is a sandbox option (`POS.SellPriceRatio`) with a default
of `TRADE_DEFAULT_SELL_RATIO`. Sell prices are always strictly lower than
buy prices.

### 30.3 Bulk Discount

When the player buys `quantity >= BulkDiscountThreshold` (sandbox option),
a percentage discount is applied:

```
discountMultiplier = 1.0 - (BulkDiscountPercent / 100)
totalCost = floor(unitPrice * quantity * discountMultiplier)
```

Both threshold and percent are sandbox-configurable. The discount is
computed by `POS_TradeService.computeBulkDiscount()` and applied at
transaction time, not at price display time.

### 30.4 State Gates

Wholesaler operational state gates trade willingness:

| State | Buy | Sell | Notes |
|-------|-----|------|-------|
| Stable | Yes | Yes | Normal operations |
| Tight | Yes | Yes | Prices slightly elevated |
| Strained | Yes | Yes | Prices elevated, stock low |
| Dumping | Yes (extra discount) | Yes | `TRADE_DUMPING_EXTRA_DISCOUNT` applied on top of state multiplier |
| Withholding | **No** | Yes | Wholesaler refuses to sell; players can still offload items |
| Collapsing | **No** | **No** | All trade blocked |

Blocked states are defined in `POS_Constants.TRADE_BLOCKED_BUY_STATES` and
`TRADE_BLOCKED_SELL_STATES`. Validation checks these before any transaction.

### 30.5 Intel Advantage

The Known Contacts screen is gated behind a SIGINT skill level requirement
(`TRADE_TERMINAL_SIGINT_REQ`). Players who invest in signals intelligence
gain access to the trading network earlier. Future iterations may add:

- Hidden offer tiers unlocked by fresh intel (recent observations in the
  wholesaler's zone).
- Price accuracy bonuses for players with high-confidence data on a
  category.

These are design-space reservations, not current features.

### 30.6 Screen Flow

```
Known Contacts (pos.markets.contacts — trader + wholesaler list, paginated)
    └── Trade Catalog (pos.markets.trade — category browser → item list, BUY/SELL toggle)
            └── inline confirm (quantity picker, price preview, bulk discount — same screen)
```

Known Contacts consolidates the old Trade Terminal and Wholesaler Directory
into a single entry point. Trade Catalog now handles confirmation inline
(no separate Trade Confirm or Trade Receipt screens). Navigation is at most
2 clicks from the Markets hub. See §33 for the full terminal screen tree.

### 30.7 Anti-Patterns

| Anti-Pattern | Why It's Dangerous | Correct Approach |
|---|---|---|
| **Mutating inventory from a screen** | Breaks UI/service separation; untestable, rollback impossible | Call `POS_TradeService.executeBuy/executeSell` from the Confirm screen's button callback |
| **Hardcoding prices** | Bypasses PriceEngine, state multipliers, and sandbox options | Always go through `POS_TradeService.computeBuyPrice/computeSellPrice` |
| **Skipping validation** | Allows trades in blocked states, overdrafts, negative stock | Always call `validateBuy/validateSell` before executing |
| **Reading sandbox directly** | Divergent defaults when one copy is updated | Use `POS_Sandbox.*` accessors or `PhobosLib.getConfigurable()` |

---

## 31. Text Compositor Patterns

PhobosLib provides four utility functions for building dynamic,
data-driven text from definition files. These are used by POSnet's
rumour system, field note generator, and any future content that needs
weighted random text selection with token substitution.

### 31.1 resolveTokens

```lua
PhobosLib.resolveTokens(text, ctx) --> string
```

Replaces `{key}` tokens in `text` with values from the `ctx` table.
Unresolved tokens are left as-is (e.g. `{unknown}` remains literal).
Returns `""` if `text` is nil; returns `text` unchanged if `ctx` is nil.

**When to use:** Any time a definition file contains a template string
with placeholders. Pass a context table built from runtime state.

```lua
local msg = PhobosLib.resolveTokens(
    "Convoy delayed near {region} — {category} scarce.",
    { region = "West Point", category = "ammunition" })
-- "Convoy delayed near West Point — ammunition scarce."
```

### 31.2 pickWeighted

```lua
PhobosLib.pickWeighted(entries, ctx) --> entry|nil
```

Selects one entry from a weighted array using `ZombRand`. Each entry must
have at minimum `{ text = "...", weight = N }`. Optional fields:

| Field | Type | Purpose |
|-------|------|---------|
| `text` | string | The text payload (may contain `{key}` tokens) |
| `weight` | number | Relative selection weight (higher = more likely) |
| `id` | string | Unique identifier for use with `avoidRecent` |
| `conditions` | table | Optional condition block checked by `conditionsPass` |

Entries whose `conditions` fail against `ctx` are filtered out before
the roll. Returns `nil` if no valid entries remain or total weight is
zero.

### 31.3 conditionsPass

```lua
PhobosLib.conditionsPass(entry, ctx) --> boolean
```

Checks whether an entry's `conditions` table is satisfied by `ctx`.
Returns `true` if the entry has no `conditions` field. Returns `false`
if `ctx` is nil but conditions exist.

**Supported condition types:**

| Condition Key | Type | Meaning |
|---|---|---|
| `minDifficulty` | number | `ctx.difficulty` must be >= this value |
| `maxDifficulty` | number | `ctx.difficulty` must be <= this value |
| Any other key | array | `ctx[key]` must be one of the values in the array |

```lua
-- Entry visible only in high-difficulty, food-related contexts:
{
    text = "Rations are dwindling.",
    weight = 10,
    conditions = {
        minDifficulty = 3,
        categoryId = {"food", "agriculture"},
    },
}
```

### 31.4 avoidRecent

```lua
PhobosLib.avoidRecent(entryId, history, maxSize) --> boolean
```

Returns `false` if `entryId` is already in the `history` array (i.e.
the entry was recently used). Returns `true` and appends `entryId` to
`history` if it was not found. Trims the oldest entries when the history
exceeds `maxSize` (default 10).

**Usage with pickWeighted:** Call `pickWeighted` in a loop, checking each
result against `avoidRecent`. If the pick is recent, discard and re-roll
(with a max-attempts guard to avoid infinite loops).

```lua
local history = player:getModData().rumourHistory or {}
for attempt = 1, 5 do
    local pick = PhobosLib.pickWeighted(rumourPool, ctx)
    if pick and PhobosLib.avoidRecent(pick.id, history, 10) then
        return PhobosLib.resolveTokens(pick.text, ctx)
    end
end
```

### 31.5 Anti-Patterns

| Anti-Pattern | Why It's Dangerous | Correct Approach |
|---|---|---|
| **Logic in definition files** | Definitions must be pure data (`return { ... }`) — functions in data files break schema validation and data-pack loading | Keep definitions declarative; use `conditions` for filtering and `{tokens}` for dynamic content |
| **Hardcoded text in Lua** | Bypasses translation, condition filtering, and weighted selection | Put text variants in definition files; resolve at runtime |
| **Skipping avoidRecent** | Players see the same rumour/note text repeatedly, breaking immersion | Always pair `pickWeighted` with `avoidRecent` for player-facing text |

---

## 32. Mission Content System

> **Status**: Implemented. The 8-step compositor pipeline lives in
> `POS_MissionBriefingResolver.lua`. Mission definitions in
> `Definitions/Missions/`, text pools in `Definitions/TextPools/`,
> voice packs for archetype-specific language (smuggler, military, trader).

Guidelines summary for compositional mission briefings and data-driven
mission definitions. The full design lives at `docs/architecture/mission-system-design.md`.

### 32.1 Compositional Briefings

- Briefings are assembled from **5 sections**: title, situation, tasking,
  constraints, and submission.
- Each section resolves independently from weighted text pools via
  `PhobosLib.pickWeighted()`.
- Tokens (`{zoneName}`, `{rewardCash}`, etc.) are resolved via
  `PhobosLib.resolveTokens()`.
- Generated text is **persisted on the operation** — never regenerated from
  schema.
- Cross-ref: **§31 Text Compositor Patterns**.

### 32.2 Mission Definitions

- Schema-validated data files in `Definitions/Missions/*.lua`.
- Follow **§26 Data-Pack Architecture** conventions.
- Each definition specifies: category, difficulty range, location rules,
  objective templates, briefing pool references.
- Three initial categories: **recon**, **recovery**, **survey**.
- Definitions are **declarative** — no functions, no logic.

### 32.3 Text Pools

- Shared text fragments in `Definitions/TextPools/*.lua`.
- Entries have: `id`, `text`, `weight`, `conditions` (optional).
- Conditions use `PhobosLib.conditionsPass()` for context-aware filtering.
- Anti-repetition via `PhobosLib.avoidRecent()` with rolling history
  (max 10 per section).

### 32.4 Voice Packs

> **Status**: Fully implemented across 4 section types.

Voice packs use the data-pack pattern (`POS_VoicePackSchema.lua` →
`Definitions/VoicePacks/*.lua` → `POS_VoicePackRegistry.lua`).

**Supported sections** (via `VOICE_ALL_OVERRIDE_SECTIONS`):

| Section | Scope | Pools | Status |
|---------|-------|-------|--------|
| `situation` | Mission/contract briefings | 8 (all archetypes) | Implemented |
| `submission` | Mission/contract completion instructions | 8 (all archetypes) | Implemented |
| `agentState` | Free agent state transition messages | 5 (agent archetypes) | Implemented |
| `investment` | Investment opportunity descriptions | — | Planned |
| `wbn_opener` | WBN bulletin opening phrases | `VOICE_SECTION_WBN_OPENER` | Planned |
| `wbn_closer` | WBN bulletin closing phrases | `VOICE_SECTION_WBN_CLOSER` | Planned |

**Fallback chain**: archetype-specific pool → default common pool.
Voice packs are **additive** — the system works without any defined.

**8 market agent archetypes** with distinct voices:
scavenger (scrappy), quartermaster (methodical), wholesaler (volume),
smuggler (shadowy), military (formal), trader (mercantile),
speculator (analytical), crafter (technical).

**5 free agent archetypes** with state-specific messages:
runner (breathless), courier (professional), broker (smooth),
smuggler (covert), contact (reliable).

**Addon extensibility**: register via `Definitions/VoicePacks/*.lua`
following `POS_VoicePackSchema`. Addon voice packs are loaded
alongside built-in ones via `PhobosLib.createRegistry()`.

### 32.5 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| **NPC dependencies** | PZ B42 has no stable NPC API — all missions must be completable via world-object interaction only |
| **Functions in definitions** | Definitions are declarative data; logic belongs in the resolver |
| **Regenerating briefings** | Persisted text must never be regenerated from schema — breaks save compatibility |
| **Monolithic briefing text** | Always use sections, never one giant string |
| **Infinite item sources** | Recovery missions require items to physically exist in the world |
| **Magic teleportation** | Player must physically travel to all objective locations |

### 32.6 Implementation Reference

| File | Purpose |
|---|---|
| `docs/architecture/mission-system-design.md` | Full design document |
| `POS_MissionSchema.lua` | Mission definition schema |
| `POS_TextPoolSchema.lua` | Text pool entry schema |
| `POS_MissionBriefingResolver.lua` | Briefing assembly engine |
| `Definitions/Missions/*.lua` | Mission data files |
| `Definitions/TextPools/*.lua` | Shared text fragments |

---

## 33. Terminal Screen Architecture

The terminal uses **12 navigable screens** organised under 3 hubs. This
consolidation (down from 20 screens) reduces navigation depth and cognitive
load while preserving all functionality.

### 33.1 Consolidated Screen Tree

```
Main Menu (pos.main)
 ├── BBS Hub (pos.bbs)
 │    ├── Bulletin Board        (pos.bbs.board)
 │    │    └── Post Detail      (pos.bbs.post)            [programmatic]
 │    ├── Incoming Requests     (pos.bbs.contracts)        — unified list + status badges
 │    ├── Assignments           (pos.bbs.assignments)      — DualTab: category × status
 │    │    ├── Negotiate        (pos.bbs.negotiate)        [programmatic]
 │    │    └── Agent Deploy     (pos.bbs.agents.deploy)    [programmatic]
 │    ├── Field Agents          (pos.bbs.agents)           — DualTab: archetype × status
 │    ├── Signal Fragments      (pos.bbs.fragments)        — Intelligence fragment review with type filter tabs
 │    ├── Investments           (pos.bbs.investments)
 │    └── Intelligence Analysis (pos.data.analysis)
 ├── Markets Hub (pos.markets)
 │    ├── Market Overview       (pos.markets.overview)      — 3 tabs: Summary | Zones | Exchange
 │    │    ├── Commodity Detail  (pos.markets.commodity)    [drill-down]
 │    │    └── Commodity Items   (pos.markets.items)        [drill-down, buy/sell + qty]
 │    ├── Known Contacts        (pos.markets.contacts)      — 2 tabs: Contacts | Directory
 │    ├── Market Signals        (pos.markets.signals)       — hard events + soft rumours [reactive]
 │    ├── Watchlist             (pos.markets.watchlist)      — [reactive: OnTradeCompleted]
 │    ├── Market Reports        (pos.markets.reports)
 │    └── Trade Catalog         (pos.markets.trade)
 │         └── Trade Receipt    (pos.markets.receipt)       [programmatic]
 ├── Data Management            (pos.data)                  [debug only]
 │    └── Data Reset            (pos.data.reset)            [debug only]
 └── Settings                   (pos.settings)              [placeholder]

Absorbed screens (deleted):
 - Zone Overview → Market Overview Tab 2 "Zones"
 - Stockmarket → Market Overview Tab 3 "Exchange"
 - Wholesaler Directory → Contacts Tab 2 "Directory"
```

Screens marked `[programmatic]` are navigated to by code (button callbacks,
trade completion) rather than appearing in hub menus. Screens marked
`[drill-down]` are sub-views navigated from parent screen selections.
Screens marked `[debug only]` require debug logging to be enabled.

### 33.2 Hub-Screen Navigation Pattern

Every screen is reachable in **1-2 clicks** from the Main Menu:

1. **Click 1** — Main Menu to hub (BBS, Markets, Settings).
2. **Click 2** — Hub to leaf screen (Assignments, Market Overview, etc.).

Hubs are menu-only screens (no content of their own). They exist solely to
group related screens and keep the Main Menu uncluttered.

### 33.3 Tab Pattern for Multi-View Screens

Screens that consolidate multiple former screens use **tabs** to switch
between logical views without adding navigation depth. The canonical
implementation is `PhobosLib.createTabbedView()`.

- **Assignments** uses tabs for Operations and Deliveries.
- Tabs are rendered as inline toggle buttons at the top of the content area.
- Tab switches use `replaceCurrent()` — they do **not** push to the
  navigation stack and do **not** appear in breadcrumbs.

### 33.4 Consolidation Map

| Old Screen(s) | New Screen | Notes |
|---|---|---|
| Intel Summary + Commodities + Zone Overview | Market Overview (`pos.markets.overview`) | Single dashboard with zone/category/intel sections |
| Traders + Wholesaler Directory + Trade Terminal | Known Contacts (`pos.markets.contacts`) | Unified contact list, SIGINT-gated |
| Event Log + Market Rumours (BBS Rumours) | Market Signals (`pos.markets.signals`) | Merged event + rumour feed |
| Operations + Deliveries | Assignments (`pos.bbs.assignments`) | Tabbed view |
| Price Ledger | Watchlist (`pos.markets.watchlist`) | Ledger data absorbed into watchlist |
| Trade Confirm + Trade Receipt | Trade Catalog (`pos.markets.trade`) + Trade Receipt (`pos.markets.receipt`) | Receipt is a separate programmatic screen navigated after trade completion |

### 33.5 Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| **Exceeding 2 levels of navigation depth from Main Menu** | Players lose context; breadcrumbs become unwieldy | Use tabs or inline sections within a screen instead of adding sub-screens |
| **Creating a new screen for a confirmation dialog** | Adds unnecessary navigation depth | Use an inline confirm pattern within the existing screen |
| **Hub screens with content** | Hubs should be menu-only; mixing content with navigation confuses the player | Keep hub screens as pure menu builders; put content in leaf screens |
| **Tabs that push to the navigation stack** | Pollutes the back-stack, breaks breadcrumbs | Tabs must use `replaceCurrent()`, never `navigateTo()` |

### 33.6 Scroll Panel Pattern

Screens with variable-height content that may exceed the terminal panel must
wrap their content sections in `PhobosLib.createScrollPanel()`. The header and
footer (Back button) stay **outside** the scroll area on the original
`contentPanel`. This prevents content from overflowing the content area.

```lua
-- After header
local scrollH = contentPanel:getHeight() - ctx.y - ctx.btnH - 16
local scrollPanel = PhobosLib.createScrollPanel(
    contentPanel, 0, ctx.y, contentPanel:getWidth(), scrollH)
ctx.panel = scrollPanel
ctx.y = 0
-- ... all section content renders into scrollPanel ...
-- Footer drawn on original contentPanel
ctx.panel = origPanel
W.drawFooter(ctx)
```

**Market Overview** uses this pattern — its zone pressure section grows with
the number of Living Market zones.

### 33.7 Cross-Screen Button Navigation

When a screen offers buttons that navigate to related screens (e.g.,
CommodityDetail → "Known Sellers" or "Price History"), the button handler must
use `navigateTo()` with the **current consolidated screen ID**, not the
pre-consolidation ID. After screen consolidation, the target screen IDs are:

| Button Label | Target Screen Constant |
|---|---|
| Known Sellers | `SCREEN_CONTACTS` |
| Price History | `SCREEN_WATCHLIST` |
| View Items | `SCREEN_COMMODITY_ITEMS` |

---

## 34. Sandbox Option Hygiene

POSnet exposes sandbox options so server admins and solo players can tune the
experience. Not every tunable value should be a sandbox option. This section
defines when to add one, how to name it, and what to avoid.

### 34.1 When to Add a Sandbox Option

- Only add an option when the player meaningfully benefits from tuning it.
- Feature toggles that default to `true` and are never expected to be disabled
  should **not** be sandbox options.
- Numeric values that are implementation details (buffer sizes, internal timers)
  should be constants, not sandbox options.
- Ask: "Would a player ever change this?" -- if the answer is "probably not",
  it is a constant.

### 34.2 Option Categories

| Category | Example | Belongs In |
|---|---|---|
| Gameplay balance | ReputationCap, OperationExpiryDays | Sandbox option |
| Player preference | TerminalFontSize, ColourTheme | Sandbox option |
| ~~Experimental gate~~ | ~~EnableLivingMarket~~ | Always active (removed) |
| Performance limit | MaxObservationsPerCategory | Sandbox option |
| Core feature toggle | "EnableMarkets" on a market mod | Constant (always true) |
| Internal tuning | WritingDamageChance, BufferSize | Constant |
| Unused placeholder | "Reserved for future" | Don't add until needed |

### 34.3 Naming Conventions

- Boolean gates: `POS.EnableFeatureName` (only for genuinely optional features).
- Numeric tuning: `POS.FeatureParameterName` (e.g.,
  `POS.EconomyTickIntervalHours`).
- All options need both `Sandbox_POS_Name` and `Sandbox_POS_Name_tooltip`
  translation keys.

### 34.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Feature toggle for core functionality | Players installed the mod for this feature -- don't let them break it |
| Placeholder options with no reads | Wastes sandbox UI space, confuses players |
| Hyper-granular numeric tuning | Six weight sliders nobody will touch -- use a single preset or hardcode |
| Option without tooltip | Players can't understand what it does |

### 34.5 Cleanup Reference

POSnet underwent a sandbox option cleanup from 135 to approximately 96 options
in v0.17.0, removing 19 unused options and 20 always-on feature toggles. This
section codifies the principles that guided that cleanup so future development
does not re-introduce the same bloat.

---

## 35. Item Discovery Mechanics

### 35.1 Discovery Gate
- Trade catalog items are hidden until discovered via observation records.
- Discovery is per-player, stored in player ModData via `PhobosLib.trackDiscovery()`.
- Selling is NEVER gated -- players always know what they own.

### 35.2 Discovery Sources

Table of discovery sources and their item counts per observation:

| Source | Items/Observation | Quality | Notes |
|---|---|---|---|
| Ambient Intel | 2-5 | Low | Passive, requires terminal connection only |
| Agent Observations | 3-8 | Medium | Living Market tick, archetype-weighted |
| Passive Recon | 4-10 | Medium-High | Active equipment, SIGINT-scaled |
| Camera Analysis | 5-12 | High | Requires camera workstation |

### 35.3 Observation Record Dual-Population

Discovery sources must populate **both** fields on each observation record:

- `record.discoveredItems` — array of fullType strings. Consumed by
  `POS_MarketDatabase.addRecord()` to trigger `POS_PlayerState.discoverItem()`.
- `record.items` — array of `{ fullType, price }` tables. Stored on the
  observation and returned by `POS_MarketDatabase.getItemRecords()` for the
  View Items screen.

Both `POS_AmbientIntel` and `POS_MarketAgent` build these arrays in a single
loop over `POS_ItemPool.selectRandomItems()`.

### 35.4 Progressive Reveal
- Trade catalog shows "X of Y items discovered" count.
- View Items (CommodityItems) screen shows "X of ~Y items discovered" counter.
- Empty item list shows informative message: "No items discovered in this
  category yet. Listen to the network to discover items..."
- PN notification on each new discovery.
- Higher-quality sources discover more items faster.

### 35.5 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Gating sell operations | Player knows what's in their inventory |
| Instant full catalog | Removes progression incentive |
| Discovery resets on load | Must persist in player ModData |
| Category-level discovery | Discovery is per-item, not per-category |

---

## 36. Item Pool Curation

### 36.1 Principle

Not every PZ item is tradeable. The item pool applies a two-layer exclusion
filter (DisplayCategory blacklist + name pattern blacklist) before indexing.
See `docs/architecture/item-pool-curation.md` for the full exclusion list and rationale.

### 36.2 Constants Location

All curation constants live in `POS_Constants_Market.lua` (not base
`POS_Constants.lua`) to respect the Kahlua assignment limit.

### 36.3 Cross-Mod Items

Cross-mod items bypass curation entirely — they are registered explicitly
via `POS_ItemPool.registerItem()` and are always included.

### 36.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Whitelist-only approach | Too fragile; new PZ updates add categories silently |
| Filtering by item type string | DisplayCategory is the canonical PZ classification |
| Hardcoding item fullTypes | Thousands of items; patterns are more maintainable |
| Filtering at selection time | Wastes memory indexing items that are never selected |

---

## 37. Data Reset Tool

### 37.1 Purpose

A developer/debug terminal screen that wipes all POSnet-related data from
the current save. Useful when corrupted or stale data causes crashes or
incorrect behaviour without requiring manual save file editing.

### 37.2 Access Control

The screen is only visible when **either**:
- PZ is launched with the `-debug` flag (`isDebugEnabled()`)
- The `POS.EnableDebugLogging` sandbox option is enabled

### 37.3 Architecture

- **`POS_DataResetService.lua`** (shared) — business logic. Clears all
  `WMD_*` world ModData keys (authority only) and `MODDATA_*` player keys.
  No magic strings — all keys referenced via `POS_Constants`.
- **`POS_Screen_DataReset.lua`** (client) — terminal screen with two-step
  confirmation dialog. Red-highlighted warning, Cancel / Confirm buttons.

### 37.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Single-click destructive action | Accidental data loss |
| Clearing ModData on non-authority | Desync in multiplayer |
| Hardcoding ModData key strings | Drift from POS_Constants definitions |
| Showing in production builds | Confuses non-developer players |

---

## 38. Boot Sequence Customisation

### 38.1 Architecture

The terminal boot sequence is driven by definition files loaded through
the PhobosLib data-pack architecture (schema + registry + loader).

- **Schema**: `POS_BootSequenceSchema.lua` — validates `id`, `systemName`,
  `durationSeconds`, `postBootPauseSec`, `lines[]`
- **Default definition**: `Definitions/BootSequence/default.lua` — telnet-style
  connection handshake
- **Loader**: `POS_BootSequence.lua` — registry with `allowOverwrite = true`
- **Template**: `Definitions/BootSequence/_template.lua` for custom definitions

### 38.2 Token System

Boot lines support runtime token replacement:

| Token | Resolves To |
|-------|-------------|
| `%FREQ%` | Connected frequency in MHz (e.g. "91.5") |
| `%BAND%` | Band name ("Operations" or "Tactical") |
| `%PLAYER%` | Player display name |
| `%SIGNAL%` | Signal strength percentage (e.g. "64%") |
| `%RADIO%` | Connected radio display name |

### 38.3 MP Server Override

Servers and addon mods override the boot sequence by registering a
definition with `id = "default"`. The registry uses `allowOverwrite = true`,
so the last registration wins. Addon mods should use `OnGameStart` to
register after the built-in default has loaded.

### 38.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Hardcoding boot text in POS_TerminalUI | Not customisable by servers/addons |
| Token resolution at file-load time | Connection info not available yet |
| Fixed boot duration | Different text lengths need different timing |

---

## 39. Apocalypse Economy Pricing

### 39.1 Principle

Item base prices reflect **apocalyptic survival value**, not pre-apocalypse
retail price or PZ item weight. A seed packet weighing 0.02 kg is worth $20
because it represents an entire future food supply chain. A gold bar weighing
16 kg is worth $12 because you can't eat it.

### 39.2 Item Value Override System

Curated per-item base prices live in `Definitions/ItemValues/*.lua` using the
standard data-pack pattern (schema + registry + definition files). Each file
returns `{ schemaVersion, entries = { ... } }` where each entry has:

- `id` — PZ fullType (e.g. `"Base.Generator"`)
- `basePrice` — absolute base price in dollars (replaces weight formula)
- `isLuxury` — if true, price is scaled by zone `luxuryDemand`
- `reason` — audit trail / documentation

Override lookup is O(1) via `POS_ItemValueRegistry.getOverride(fullType)`.

### 39.3 Category Multipliers

Items **without** an override still use the weight-based formula, but category
multipliers are tuned for apocalyptic priorities. See
`POS_Constants_Market.CATEGORY_PRICE_MULTIPLIERS`. Literature is 2.0x because
skill books are irreplaceable survival knowledge.

### 39.4 Luxury Zone Scaling

Items flagged `isLuxury = true` have their final price multiplied by the
zone's `luxuryDemand` field (defined in zone definition files). Urban zones
inflate luxury prices; rural zones deflate them. When Living Market is
disabled, the multiplier defaults to 1.0.

| Zone | luxuryDemand | Effect on $12 gold bar |
|------|-------------|------------------------|
| Louisville Edge | 2.5 | $30.00 |
| West Point | 1.5 | $18.00 |
| Riverside | 1.2 | $14.40 |
| Muldraugh | 0.5 | $6.00 |
| Military Corridor | 0.3 | $3.60 |
| Rural East | 0.3 | $3.60 |

### 39.5 Addon Extensibility

Addon mods register overrides at runtime:

```lua
if POS_ItemValueRegistry then
    POS_ItemValueRegistry.registerOverrides({
        { id = "MyMod.SuperMedicine", basePrice = 150.00,
          reason = "Custom rare medicine" },
    })
end
```

### 39.6 Registry API Reference

**Module**: `POS_ItemValueRegistry.lua`

| Function | Returns | Description |
|----------|---------|-------------|
| `init()` | — | Load schema, create registry, load all definition files, build O(1) index |
| `getOverride(fullType)` | `{basePrice, isLuxury}` or `nil` | Hot-path lookup by PZ fullType |
| `isLuxury(fullType)` | `boolean` | Convenience check for luxury flag |
| `getRegistry()` | registry instance | Expose registry for addon mods |
| `registerOverrides(entries)` | — | Bulk-register from array of `{id, basePrice, ...}` |

**Schema**: `POS_ItemValueSchema.lua` — fields: `schemaVersion`, `id` (fullType),
`basePrice` (min 0.01), `isLuxury` (default false), `reason` (default "").

**Definition files**: `Definitions/ItemValues/*.lua` — each returns
`{ schemaVersion, entries = { ... } }`. 11 built-in files + template.

### 39.7 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Using PZ weight as a proxy for value | Seeds = 0.02 kg but $20 survival value |
| Uniform category multipliers | Fuel ≠ miscellaneous in an apocalypse |
| Luxury items at fixed price everywhere | Zone context matters — urban vs rural |
| Overriding at selection time | Override at indexing time for consistency |
| Per-item files for overrides | 200+ files is unwieldy; use entries arrays |

---

## 40. Starlit Library Integration (Roadmap)

> **Status**: Phase 1 (LuaEvent) implemented — 15+ named events via
> `POS_Events.lua`. Phase 2 (TaskManager) **blocked** by KahluaArray bug
> (see §40.7). Reverted to manual tick counters. Phase 3 (Time) not yet
> adopted.

POSnet will adopt three modules from the **Starlit** utility library as a
servant-library for orchestration and events. Starlit is a dependency-style
mod (required via `mod.info`), not copied into the mod.

### 40.1 Adoption Scope

| Module | Purpose | POSnet Use Case | Priority |
|--------|---------|-----------------|----------|
| **LuaEvent** | Object-based custom event bus | Internal decoupling — subsystems publish events instead of direct cross-calls | **High** |
| **TaskManager** | Tick-spread scheduling and task chains | Passive recon, staged analysis, chunked processing, cooldown orchestration | **High** |
| **Time** | Game/real-time conversion and duration formatting | Report freshness, mission expiry, investment maturity, cooldown display | **Medium** |

### 40.2 Explicitly Out of Scope

| Module | Status | Reason |
|--------|--------|--------|
| InventoryUI | **Deprecated** | Removed in recent Starlit updates |
| PZEvents | **Deprecated** | Removed in recent Starlit updates |
| Reflection | **Deprecated** | Removed; fragile across game updates |
| TimedActionUtils | Available | PhobosLib.WorldAction already covers this |

Starlit must **never** be used to replace:
- POSnet's screen stack / navigation / registry architecture
- Core persistence and save format (ModData-based)
- Pricing engine or market simulation internals

### 40.3 POS.Events Namespace (Planned)

When LuaEvent is adopted, POSnet will expose a thin event surface:

```
POS.Events.OnConnectionStateChanged  -- radio link up/down
POS.Events.OnBandChanged             -- tactical ↔ operations
POS.Events.OnChunkRecorded           -- data recorder wrote chunk
POS.Events.OnRecorderStatusChanged   -- media inserted/ejected/full
POS.Events.OnIntelCompiled           -- camera compilation complete
POS.Events.OnMarketSnapshotUpdated   -- new observation ingested
POS.Events.OnStockTickClosed         -- daily market tick complete
POS.Events.OnMissionGenerated        -- new assignment available
POS.Events.OnTradeCompleted          -- buy/sell transaction done
POS.Events.OnScreenInvalidationRequested  -- UI refresh trigger
```

Benefits:
- Tutorial system subscribes without polluting services
- UI screens refresh only when relevant data changes
- Third-party mods gain clean integration points
- Logging/debugging attached orthogonally

### 40.4 TaskManager Use Cases (Planned)

| Task | Current Approach | TaskManager Replacement |
|------|-----------------|------------------------|
| Passive recon pulse | EveryOneMinute + counter | Scheduled task with configurable interval |
| Terminal analysis | Instant function call | Multi-tick staged pipeline: scan → process → finalise → notify |
| Economy tick | EveryOneMinute + day check | Daily scheduled task with tick-spreading |
| Ambient intel | EveryOneMinute + interval | Scheduled background task |
| Chunked file writes | PhobosLib_ChunkedWriter | TaskManager coroutine chain |

### 40.5 Implementation Phases

**Phase 1** (highest value):
1. Add Starlit as `require:` dependency in `mod.info`
2. Create `POS_Events.lua` wrapping Starlit LuaEvent
3. Wire first 3-4 events (OnMarketSnapshotUpdated, OnConnectionStateChanged, OnScreenInvalidationRequested)
4. Migrate UI refresh from direct calls to event subscriptions

**Phase 2** (orchestration):
5. Introduce TaskManager for passive recon pipeline
6. Convert terminal analysis to staged multi-tick task
7. Move economy tick to TaskManager scheduling

**Phase 3** (polish):
8. Adopt Time module for player-facing duration/freshness text
9. Replace ad-hoc time formatting across screens

### 40.6 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Making Starlit the backbone of POSnet | It's a servant-library, not the throne |
| Replacing screen registry with Starlit | POSnet's screen stack is already mature |
| Using deprecated modules (InventoryUI, PZEvents, Reflection) | Removed or fragile across PZ updates |
| Exposing Starlit types in POSnet's public API | Wrap behind POS_Events; don't leak dependency |
| Using TaskManager for persistence | It's for runtime orchestration, not save state |
| Adopting Starlit "devotionally" | Surgical adoption of proven modules only |

### 40.7 TaskManager — Blocked by KahluaArray Bug

**Do NOT use `TaskManager.repeatEveryTicks()` in POSnet.**

Starlit's `repeatEveryTicks()` creates the task array via
`table.newarray()`, which produces a Java-backed `KahluaArray`.
KahluaArray only accepts **integer keys**. Starlit then tries to set
`.offset` (a **string key**) on it at line 249, causing:

```
java.lang.RuntimeException: Invalid table key: offset
    at KahluaArray.rawset(KahluaArray.java:156)
```

Without `.offset`, the update loop at line 233 does `offset + amount`
with nil offset, causing a secondary crash:

```
__add not defined for operands
```

This is an **internal Starlit inconsistency** — `table.newarray()` and
string-keyed `.offset` are mutually incompatible in Kahlua Lua 5.1.

**Status**: Reverted to manual tick counters in POS_ReconScanner and
POS_PathTracker. TaskManager adoption is blocked until Starlit
replaces `table.newarray()` with a regular Lua table in
`repeatEveryTicks()`.

**Starlit LuaEvent is unaffected** and remains in active use (15+ named
events via `POS_Events.lua`).

---

## 41. Ambient Intelligence System

### 41.1 Overview

The ambient intel system (`POS_AmbientIntel.lua`) provides passive "word of
mouth" market observations without requiring active recon or data recording.
When the terminal is connected, the player periodically receives gossip-style
market snippets from the network — simulating background chatter that any
connected operator would naturally overhear.

### 41.2 Architecture

- **Module**: `POS_AmbientIntel.lua` (shared)
- **Event**: `Events.EveryOneMinute` — checks interval counter
- **Interval**: Sandbox option `POS.AmbientIntelInterval` (10-120 min, default 30)
- **Max records**: 50 ambient records cap (rolling)
- **Authority**: Server/SP only (guarded by `isAuthority()`)

### 41.3 Observation Generation

Each ambient tick:
1. Select 1-3 random commodity categories (weighted by market registry)
2. For each category, select 2-5 random items via `POS_ItemPool.selectRandomItems()`
3. Generate observation with: category, source name, stock level, price (±25% noise)
4. Populate `discoveredItems` array (feeds item discovery system, §35)
5. Store via `POS_MarketDatabase.addRecord()`
6. Notify player via PhobosNotifications (if installed)

### 41.4 Flavour Sources

Ambient observations are attributed to 8 randomised source names (e.g.
"word of mouth", "network chatter", "overheard broadcast") to create
narrative variety. Sources are cosmetic — they don't affect data quality.

### 41.5 Integration Points

- **Item Discovery (§35)**: Each ambient record carries `discoveredItems`,
  progressively revealing the trade catalog
- **Market Database**: Records feed into category summaries, price history,
  and the Market Overview screen
- **Living Market (§24)**: Ambient intel supplements (not replaces) agent
  observations — provides a baseline data flow even without active recon

### 41.6 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Generating ambient data on the client | Authority must be server/SP only |
| Making ambient data high-confidence | It's gossip — should be noisy (±25%) |
| Replacing active recon with ambient | Ambient supplements; active recon produces better data |
| Generating ambient when not connected | Terminal connection is the prerequisite |

---

## 42. Three-Layer Selling System

> **Status**: All three phases implemented. Phase 1 (Contracts),
> Phase 2 (Spot Sell on CommodityItems), Phase 3 (Free Agents —
> `POS_FreeAgentService.lua` + `POS_Screen_FreeAgents.lua`).

### 42.1 Design Principle

"Buying is convenience. Selling is intelligence."

Selling is **demand-led**, not inventory-led. The world asks the player to
sell — through desperate radio pleas, military requisitions, and shadowy
back-channel deals. The player's information quality (SIGINT, recon data)
determines which opportunities they discover and how good the terms are.

### 42.2 Three Layers

| Layer | Description | Available | Fantasy |
|-------|-------------|-----------|---------|
| Spot selling | Offload surplus to a contact | Early game | Scavenger trading junk |
| Contracts | World-originated demand orders | Mid game | Field operative supplying outposts |
| Free agents | Delegate to runners/brokers | Late game | Signals commander running logistics |

### 42.3 Progression Arc

Spot selling is the floor. Contracts are the main progression path. Free
agents are the automation/scale layer. Without contracts, free agents become
"automate sell button." With contracts, they become meaningful operators.

### 42.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Mirror-image of buying | Selling should be demand-driven, not browse-driven |
| Vendor trash disposal | Present as offloading surplus into a live market |
| Separate economy from Living Market | Contract fulfilment must affect zone pressure |
| Black-box free agents | Players must see agents working through the signal feed |

---

## 43. Contract System

> **Status**: Implemented. Schema, service, generator, text pools, screen.
> See `POS_ContractService.lua`, `POS_ContractGenerator.lua`.

### 43.1 Contract Kinds

| Kind | Description | Pay | Risk | SIGINT Gate |
|------|-------------|-----|------|-------------|
| `procurement` | Standard supply request | 1.0-1.3x | None | 1 |
| `urgent` | Emergency shortage — premium, tight deadline | 1.5-2.5x | None | 2 |
| `standing` | Recurring supply — lower margins, stable | 0.8-1.1x | None | 2 |
| `grey_market` | Off-the-books deal — betrayal risk | 1.3-2.0x | 15% | 3 |
| `military` | Official requisition — strict specs | 1.4-1.8x | None | 5 |
| `arbitrage` | Regional price arbitrage | 1.2-1.8x | 5% | 4 |

### 43.2 Lifecycle

```
posted → accepted → fulfilled → settled
posted → expired (deadline passed, unaccepted)
accepted → failed (deadline passed)
accepted → betrayed (grey market — items consumed, no payment)
```

### 43.3 Generation Rules

Contracts spawn from the economy tick when zone pressure exceeds
`CONTRACT_GENERATION_PRESSURE_THRESHOLD` (0.5). One contract per zone per
tick. Maximum 8 available contracts at any time. Cooldown: 1 day between
generations. Requires Living Market enabled.

### 43.4 Pricing (Bid Model)

```
payout = avgCategoryBasePrice × quantity × payMultiplier
```

Where `payMultiplier` is rolled between definition's `payMultiplierMin` and
`payMultiplierMax`. Urgent contracts pay more because people are desperate.
Standing orders pay less because the demand is predictable.

### 43.5 Betrayal Mechanic

Grey-market contracts have a `betrayalChance` (default 15%). On fulfilment,
the system rolls against this chance. If betrayed: items are consumed but no
payment is received. The buyer vanishes. The player learns to be more
careful about who they deal with.

### 43.6 Briefing Text

Contract briefings use the Mission Briefing Resolver (§32) with contract-
specific text pools. Voice pack overrides apply per archetype sponsor:
smuggler contracts sound shadowy, military contracts sound formal, etc.

### 43.7 ContextPanel Integration

When a contract is selected in the list, the ContextPanel (right sidebar)
shows full detail: buyer archetype, item needed, quantity, payout, deadline
countdown, urgency, risk indicator, SIGINT requirement, briefing preview,
inventory check (owned/needed), and action buttons (Accept/Fulfil/Abandon).

### 43.8 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Player-originated contracts | That's Phase 3 (free agents). Contracts are world-originated. |
| Flat inverse of buy price | Use bid model with urgency, shortage, archetype modifiers |
| Contracts as separate economy | Fulfilment must affect zone pressure and wholesaler stock |
| Omniscient betrayal warning | Risk indicator shows LOW/MODERATE/HIGH, not exact % |
| Instant settlement | Items consumed → money credited is atomic, but the world impact (pressure relief) should propagate through the next economy tick |

---

## 45. Band Registry System

> **Status**: Implemented. 2 built-in bands, addon-extensible.

### 45.1 Overview

Radio bands gate **mission content visibility**, not screen access (§21.5).
Each band represents a distinct frequency range with its own mission pool.
Addon mods can register custom bands.

### 45.2 Built-In Bands

| Band ID | Badge | Type | Content |
|---------|-------|------|---------|
| `POSnet_Operations` | OPS | amateur | Civilian: delivery, trade, basic recon |
| `POSnet_Tactical` | TAC | tactical | Military: SIGINT, recovery, night ops |

### 45.3 Schema

`POS_BandSchema.lua`: id, name, displayNameKey, azasBandType (amateur/tactical),
badgeLabel, sortOrder, enabled.

### 45.4 Mission Filtering

Each mission definition has an optional `requiredBands` array. When set,
the mission only appears in the Assignments screen when the player's active
band matches one of the listed bands. When nil, visible on all bands.

### 45.5 Addon Extensibility

```lua
POS_BandRegistry.getRegistry():register({
    schemaVersion = 1,
    id = "MedicalEmergency",
    name = "Medical Emergency Band",
    displayNameKey = "UI_MyMod_Band_Medical",
    azasBandType = "amateur",
    badgeLabel = "MED",
    sortOrder = 3,
})
```

### 45.6 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Hardcoding band IDs in screens | Use POS_BandRegistry.get() |
| Gating screens by band | Gate content (missions), not access (screens) |
| Bands as SIGINT gates | Bands are frequency context, not skill gates |

---

## 46. Free Agent Operations

> **Status**: Fully playable + observable. Schema, service, screen,
> economy tick, Deploy UI, cargo consumption, contract settlement,
> PN channels (5), ContextPanel detail (state/risk/ETA/cargo/SIGINT),
> signal feed persistence, zone-aware risk scaling, SIGINT influence.
> Dual-tab rendering via PhobosLib_DualTab.

### 46.1 Overview

Free agents are NPCs (runners, brokers, couriers, smugglers) sent into
zombie territory to execute trade operations autonomously. The player
deploys an agent, then monitors progress through the signal feed and
terminal screen — waiting by the radio.

### 46.2 State Machine

```
drafted → assembling → transit → negotiation → settlement → completed
                          ↓           ↓
                       delayed    compromised → failed
```

Each economy tick advances agents probabilistically via
`POS_FreeAgentService.tick()`. Not every tick produces a state change —
agents progress at realistic speeds with risk of delay or loss.

### 46.3 Agent Archetypes

| Archetype | Commission | Risk | Speed | Fantasy |
|-----------|-----------|------|-------|---------|
| Runner | 5% | 20% | 2d | Kid with a bike and a death wish |
| Broker | 15% | 5% | 5d | Smooth-talker with a ham radio |
| Courier | 10% | 10% | 3d | Ex-military professionals |
| Smuggler | 20% | 25% | 4d | Operates outside the law |
| Contact | 8% | 3% | 6d | Established wholesaler route |

### 46.4 Screen

Dual tab bars: [All|Runner|Broker|Courier|Smuggler] × [Active|Completed|Failed].
Each row shows: agent name, state badge, zone, cargo, ETA, risk, commission.
Active agents have a [Recall] button (abort mission, no payout).

### 46.5 Settlement

On completion: player receives `payout × (1 - commissionRate)`.
On failure: cargo is lost, agent is gone, no payout.

### 46.7 Deploy UI Architecture

Contract ContextPanel → [Send Agent] → `pos.bbs.agents.deploy` screen:

1. Contract summary (kind, item×qty, payout)
2. Archetype selector (5 buttons with commission/risk/ETA per row)
3. Cost preview (cargo consumed + commission deducted + net payout)
4. Inventory check (owned/needed with colour feedback)
5. [Confirm Deployment] → `POS_FreeAgentService.deploy()` → cargo consumed
   atomically → agent appears in Field Agents screen

The archetype selector uses named constants (`POS_Constants.FREE_AGENT_ARCHETYPE_*`)
and translation keys (`UI_POS_FreeAgent_Archetype_*`). All labels use
`PhobosLib.safeGetText()`. No magic strings.

### 46.8 PhobosNotifications Integration

5 PN channels registered via `POS_NotificationChannels.lua`:

| Channel | Constant | Content |
|---------|----------|---------|
| `posnet_agents` | `PN_CHANNEL_AGENTS` | Agent deploy/state/recall |
| `posnet_contracts` | `PN_CHANNEL_CONTRACTS` | Contract accept/fulfil/expire/betray |
| `posnet_market` | `PN_CHANNEL_MARKET` | Market events, zone disruptions |
| `posnet_trade` | `PN_CHANNEL_TRADE` | Buy/sell confirmations |
| `posnet_intel` | `PN_CHANNEL_INTEL` | Item discoveries |

Priority escalation for agents: `drafted/assembling` = low,
`transit/negotiation` = low, `delayed` = normal, `compromised` = high,
`completed` = normal, `failed` = critical.

All `notifyOrSay` calls use the correct opts-table signature with
`PhobosLib.safecall` wrapper for resilience.

### 46.9 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Deterministic state transitions | Probabilistic feels real; waiting by the radio IS the gameplay |
| Invisible agents | Signal feed must show updates; this is a radio game |
| Risk-free agents | Loss must be possible or the system has no tension |
| Instant settlement | Agents take days; patience is the cost of delegation |

---

## 48. Empty State UX — Sandbox Gate Messages

### 48.1 Principle

Every screen that depends on a sandbox feature MUST show a clear message
when that feature is disabled, explaining WHAT is missing and HOW to
enable it. Silently showing empty content leaves the user confused.

### 48.2 Message Tiers

| Tier | When | Example |
|------|------|---------|
| Feature disabled | Sandbox option OFF | "Living Market is disabled. Enable it in Sandbox Options > ..." |
| Data not yet populated | Feature ON but no ticks yet | "No market events yet. Signals generate automatically during economy ticks." |
| User action needed | Feature works, data empty | "Add categories from Market Overview to track price changes." |

### 48.3 Screens with Gate Messages

| Screen | Gate | Message Key |
|--------|------|------------|
| Market Overview (Zone Pressure) | _(always active)_ | _(gate removed)_ |
| Contacts (Directory tab) | _(always active)_ | _(gate removed)_ |
| Market Signals (empty) | _(always active)_ | `UI_POS_Signals_WaitForTick` |
| Watchlist (empty) | User action | `UI_POS_Watchlist_HowToAdd` |
| Commodity Detail (no sources) | User action | `UI_POS_CommodityDetail_HowToGather` |
| Exchange tab | Exchange option | `UI_POS_Exchange_Disabled` (already existed) |
| Intelligence Analysis | Equipment | Multi-line guidance (already existed) |

### 48.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Silent empty content | User doesn't know what's wrong or how to fix it |
| Generic "no data" message | Doesn't explain the specific dependency |
| Hardcoded English in messages | Use translation keys for all empty-state text |
| Hiding screens entirely | Show the screen with explanation, not a locked menu item |

---

## 49. No Silent Gates

### 49.1 Principle

Every gate, restriction, or hidden requirement in POSnet MUST explain
itself to the player. If the user doesn't know about an inherent design
feature, a specific mention MUST be made and how it can be OVERCOME.

Every gate message must include three elements:
1. **WHAT** is restricted ("These missions require a tactical band")
2. **WHY** it's restricted ("Your radio is tuned to Operations")
3. **HOW** to overcome it ("Switch to POSnet_Tactical frequency")

### 49.2 Gate Types

| Gate Type | Explained? | Message Location |
|-----------|-----------|------------------|
| Connection required | YES | Menu item disabled with reason |
| Signal strength minimum | YES | Menu item disabled with reason |
| Radio band (screens) | YES | Menu item disabled with reason |
| Radio band (missions) | YES | Empty state in Assignments (§49) |
| Camera cooldown | YES | Context menu tooltip |
| Camera power/inputs | YES | Context menu tooltip |
| Wholesaler state blocked | YES | Disabled trade button |
| Player balance | YES | Disabled buy button + balance shown |
| SIGINT visibility | YES | Hidden count + skill hint in Contacts (§49) |
| Mission difficulty cap | YES | Footer hint in Assignments (§49) |
| Signal → mission quality | YES | Footer hint in Assignments (§49) |
| Living Market disabled | YES | Explicit message on affected screens (§48) |
| Equipment required | YES | Menu item disabled with reason |

### 49.3 Implementation Pattern

All gate messages use `UI_POS_Gate_*` translation keys with `%1`/`%2`
placeholders for dynamic values (skill level, signal %, band name).
Messages are rendered as dim-coloured labels below the empty state.

### 49.4 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Silent content filtering | Player sees empty list, doesn't know why |
| "No data" without context | Doesn't explain the specific gate or how to overcome |
| SIGINT gates on screen access | Per §21, SIGINT affects data quality, not access |
| Hiding menu items entirely | Show the screen with an explanation |
| Hardcoded gate messages | Use UI_POS_Gate_* translation keys |

---

## 47. Operations Actor Architecture

> **Status**: Design document. Reframes Free Agents from "selling Phase 3"
> to POSnet's general-purpose field-operations actor layer.
> See `docs/architecture/free-agent-system.md` for full detail.

### 47.1 Principle

Free agents are not merely trade delegates. They are **operational assets**
— the player's extension into the world when the terminal can't reach.
The same actor framework serves contracts, procurement, smuggling, recon
couriering, signal relay, and data handoff. "Send someone out, wait by the
radio" is the universal POSnet experience at the tactical layer.

### 47.2 Design Pillars

1. **Observability first** — strategic (pre-deploy), operational (in-flight),
   forensic (post-completion). Three layers, all visible through terminal UI.
2. **Cargo and money are sacred** — hard invariants for item consumption,
   provenance tracking, settlement authority, and salvage rules.
3. **Zone risk is central** — `finalRisk = archetype × zone × disruption ×
   signal × intel`. Not a flat scalar.
4. **Signal infrastructure matters** — poor signal degrades telemetry,
   reduces recall success, limits intervention options.

### 47.3 Hard Invariants

- Deploy consumes cargo immediately (`PhobosLib.consumeItems`)
- Settlement is the only money credit point
- Commission is deducted atomically
- Contract-linked runs settle through the same authority as manual fulfilment
- Every record carries ownership scope (player/faction/public)
- Only owner scope can recall/cancel/settle

### 47.4 MP Ownership Model

Hybrid: world owns simulation, players/factions own operational rights.
Single server-owned data store with ownership scope tags. Five
implementation phases (tags → permissions → provenance → intel → infra).
Vanilla PZ factions mapped to POSnet permission levels (owner/officer/member).
See `free-agent-system.md` §12 for full detail.

### 47.5 Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Treating agents as "selling Phase 3 only" | They are a general operations substrate |
| Flat risk per archetype | Risk must incorporate zone, disruption, signal, intel |
| Black-box agents | Observability is a core requirement, not a UI enhancement |
| Fuzzy cargo provenance | "Where did the items go?" must always be answerable |
| Per-player isolated data stores in MP | Kills the shared-world radio fantasy |
| Bolting MP ownership on later | Schema shape depends on ownership decisions |

---

## 50. Signal Ecology (Future Architecture v2)

> **Status**: Future target architecture. Current implementation uses flat
> signal percentage (v1). See `signal-ecology-design.md` for full design.

### 50.1 Principle

Signal should never be a guarantee. It should be a negotiation between
physics, infrastructure, people, systems, and the player's intent. The
flat 100% signal at top-tier radios collapses an entire dimension of
gameplay into a solved state. POSnet thrives on uncertainty, degradation,
and interpretation.

### 50.2 Five Pillars

| Pillar | Layer | Question | Key Inputs |
|--------|-------|----------|------------|
| Propagation | Physics | "How well can the signal travel?" | Weather, season, terrain, antenna type |
| Infrastructure | Hardware | "How stable is the network?" | Grid power, generator fuel, hardware condition, calibration |
| Clarity | Information | "How readable is what we receive?" | Noise, encoding quality, terminal analysis level, interference |
| Saturation | Economic | "How crowded is the air?" | Active agents, market chatter, panic events, band competition |
| Intent | Player control | "What are we trying to do?" | Bandwidth allocation, priority routing, transmission type |

### 50.3 Signal States

Replace raw percentage with qualitative bands: **Locked** (85-100%),
**Clear** (65-84%), **Faded** (45-64%), **Fragmented** (25-44%),
**Ghosted** (10-24%), **Lost** (0-9%).

### 50.4 Emergent Loop

Weather affects signal. Signal affects agents. Agents affect markets.
Markets affect signal. This closed loop means radios are never "solved"
and players must interpret evidence rather than consume truth.

### 50.5 Migration Path

Phase A: weather effects on existing signal. Phase B: infrastructure
pillar. Phase C: market/agent saturation. Phase D: full ecology UI.
Phase E: intent pillar (Tier V). See `signal-ecology-design.md` §8 for
full migration strategy.

---

## 51. Tier V Strategic Relay

> **Status**: Design document. See `tier-v-strategic-relay-design.md` for
> full design.

### 51.1 Principle

Tier V is the apex of the intelligence hierarchy. It is the first true
POSnet **command installation** — a permanent, power-hungry, strategic
relay that transforms the player from an intelligence gatherer into a
network operator.

**Tier IV speaks loudly. Tier V listens, judges, routes, and commands.**

### 51.2 Core Functions

| Function | Description |
|----------|-------------|
| Regional Uplink | Stronger, multi-zone satellite broadcast |
| Relay Queue | Store-and-forward for lower-tier reports |
| Agent Backhaul | Improved telemetry and recall for field agents |
| Signal Fusion | Cross-source intelligence synthesis |
| Intercept Sweep | Timed action to hunt rare strategic traffic |
| Priority Routing | Bandwidth allocation across domains |

### 51.3 Hardware Identity

Permanent large satellite dishes on civic buildings (fire stations,
military outposts, communications facilities). Cannot be crafted,
moved, or replicated. Must be discovered, claimed, and maintained.

### 51.4 Crown-Not-Replacement Rule

Tier V depends on all lower tiers for raw truth. It is hungry: it
needs field captures, recorder media, terminal analysis, camera
compilations, and agent reports. The command node is a crown, not a
replacement for the kingdom beneath it.

---

## 52. Intelligence Transmission Hierarchy

**Core law**: Every tier should be able to transmit, but each tier transmits
a different class of truth.

| Tier | Transmits | Character | Examples |
|------|-----------|-----------|----------|
| I — Field | **Observations** | Raw, messy, lossy, delayed. Feels human and improvised. | Recon snippets, tagged coordinates, item sightings, danger markers, distress bursts, courier drop notices, crude market whispers |
| II — Terminal | **Interpretations** | Deliberate and formatted. Structured reports. | Cleaned intel fragments, target packages, mission submissions, contact updates, trade intent notices, agent recall requests |
| III — Compilation | **Validated packages** | Portable, tradable, authoritative. | Compiled site surveys, market bulletins, reviewed media packages, confidence-rated summaries, wholesaler dossiers |
| IV — Broadcast | **Public influence** | Affects systems, not just records. Regional narratives. | Public market guidance, scarcity alerts, region-wide opportunity pings, faction influence broadcasts, destabilising rumours or stabilising truth |
| V — Strategic | **Network intent** | Infrastructure organism. Coordination traffic. | Relay directives, agent dispatch envelopes, authentication handshakes, synchronisation packets, market coordination orders, threat advisories, signal priority overrides, inter-terminal routing |

> **§52.1 Design boundary**: If a lower tier starts transmitting the class
> above it, it has crossed the hierarchy line. A radio cannot broadcast
> regional narratives. A satellite cannot issue relay directives.
> Keep each tier's verbs distinct.

**Cross-references**: `satellite-uplink-design.md` §5.5–5.7,
`tier-v-strategic-relay-design.md` §6,
`broadcast-influence-design.md` §2,
`passive-recon-design.md` §2.3

---

## 53. Data Store Registry

Every persistent data store (ModData key) used by POSnet MUST be
registered in `data-stores-reference.md` before merge.

For each store, document:
1. **Constant name** (`WMD_` for world, `MODDATA_` for player)
2. **Owner module** (which service reads/writes it)
3. **Cap / pruning strategy** (`pushRolling`, `trimByAge`, lifecycle, or unbounded)
4. **Growth classification** (LOW / MEDIUM / HIGH)
5. **Reset coverage** (is it in `POS_DataResetService`?)
6. **Multiplayer scope** (shared world vs per-player)

> **Anti-pattern**: Adding a `getWorldModDataTable()` call without updating the
> registry. Unregistered stores become invisible to the reset system and data
> audits, leading to ghost data that survives resets and corrupts save files.

**PhobosLib utilities to prefer**:
- `pushRolling(arr, val, cap)` — for any array that grows over time
- `trimByAge(arr, dayField, maxDays, currentDay)` — for entries with timestamps
- Avoid unbounded arrays in ModData — PZ serialises the entire table on save

**Cross-reference**: `data-stores-reference.md`

---

## 54. Radio Band Taxonomy

POSnet uses **three radio domains** that must not be conflated:

| Domain | Purpose | Accessible Via |
|--------|---------|---------------|
| Civilian Data Net | Structured POSnet terminal traffic | Terminals, data-capable radios |
| Tactical Data Net | Restricted network traffic | Terminals, military gear, satellites |
| Broadcast Bands | Public editorialised bulletins | Any radio (handheld, vehicle, etc.) |

> **Design rule**: Data bands carry payloads. Broadcast bands carry
> interpretations. Never expose raw simulation data on public broadcast
> channels. Tier IV bridges data → broadcast. Tier V governs both planes.

**Cross-references**: `radio-band-taxonomy-design.md`,
`world-broadcast-network-design.md`

> **Terminal access rule**: Terminal services are gated behind data bands
> only. Broadcast bands (`wbn_market`, `wbn_emergency`) are receive-only
> and must never provide terminal access. Use
> `POS_AZASIntegration.isDataBand(band)` to verify terminal eligibility.
> See `radio-band-taxonomy-design.md` §3.2.

---

## 55. WBN Coding Conventions

The World Broadcast Network (WBN) delivers diegetic radio bulletins to
players via PZ Build 42's `DynamicRadio` system. All WBN services follow
these conventions.

### 55.1 Event-Driven Harvest

WBN does **not** poll for state changes. The harvest layer subscribes to
Starlit events for loose coupling:

| Event | Source | WBN Action |
|-------|--------|------------|
| `OnStockTickClosed` | Economy tick | Compare zone pressure snapshots, generate economy candidates |
| `OnMarketEvent` | Event service | Generate infrastructure/emergency candidates |

Future phases will add: `OnFreeAgentStateChanged`, `OnConnectionStateChanged`.

### 55.2 DynamicRadio API

WBN uses vanilla PZ's radio system — **not** custom `sendServerCommand`
messaging. The delivery chain is:

1. `DynamicRadioChannel.new(name, freq, category, uuid)` — register channel
2. `RadioBroadCast.new(id, -1, -1)` — create global broadcast
3. `RadioLine.new(text, r, g, b)` — create coloured line
4. `channel:setAiringBroadcast(bc)` — emit

Players receive bulletins automatically when tuned to a WBN frequency.
No custom client delivery code is needed for the core floating text —
the vanilla radio system handles it.

### 55.3 Constants & Translation Keys

- All WBN constants live in `POS_Constants_WBN.lua` on the `POS_Constants` table
- Prefix: `POS_Constants.WBN_*`
- All player-facing text uses translation keys: prefix `UI_WBN_*`
- Phrase bank keys follow: `UI_WBN_Phrase_<Slot>_<Archetype>_<Index>`
- No magic numbers or inline strings in any WBN service

### 55.4 Bulletin Grammar System

Bulletins are composed from five slots, each drawn randomly from a
translation-key-based phrase pool:

| Slot | Keyed By | Example |
|------|----------|---------|
| Opener | archetype | "Market advisory:" |
| Subject | domain | "{category} in {zone}" |
| Condition | direction | "is up {pct} percent" |
| Qualifier | confidence band | "Reports are mixed." |
| Closer | archetype | "Trade accordingly." |

Template variables (`{category}`, `{zone}`, `{pct}`) are filled at
composition time. Confidence modifiers prepend the percentage phrase
(high: bare, medium: "about", low: "said to be").

**Voice Pack Integration**: The opener and closer slots route through the
Voice Pack Registry (`POS_VoicePackRegistry.getOverride(archetypeId, "wbn_opener")`).
If a voice pack defines WBN sections, those phrase pools are used; otherwise
the built-in defaults in CompositionService apply. This enables addon mods
to add custom radio voices without modifying WBN code.

See §32 for voice pack architecture.

### 55.5 Station Classes (Phase 1)

| Station | Frequency | Archetype | Cadence | Domain |
|---------|-----------|-----------|---------|--------|
| Civilian Market | 91.4 MHz | quartermaster | 10 min | economy |
| Emergency | 103.8 MHz | field_reporter | 5 min | infrastructure |

### 55.6 File Locations

| File | Layer | Purpose |
|------|-------|---------|
| `shared/POS_Constants_WBN.lua` | constants | All WBN named values |
| `shared/POS_WBN_HarvestService.lua` | harvest | Event-driven candidate generation |
| `shared/POS_WBN_EditorialService.lua` | editorial | Scoring, filtering, dedup |
| `shared/POS_WBN_CompositionService.lua` | composition | 5-slot grammar rendering |
| `shared/POS_WBN_SchedulerService.lua` | scheduling | Per-station queues + cadence |
| `server/POS_WBN_ChannelService.lua` | delivery | DynamicRadio channel + emission |
| `client/POS_WBN_ClientListener.lua` | client | OnDeviceText history capture |

**Cross-references**: `world-broadcast-network-design.md`,
`radio-band-taxonomy-design.md`

### 55.7 Weather and Power Constants

All weather broadcast thresholds are named constants in `POS_Constants_WBN.lua`:

| Constant | Value | Meaning |
|----------|-------|---------|
| `WBN_WEATHER_RAIN_MODERATE` | 0.3 | `getRainIntensity()` ≥ triggers rain report |
| `WBN_WEATHER_RAIN_HEAVY` | 0.7 | Heavy rain threshold |
| `WBN_WEATHER_SNOW_THRESHOLD` | 0.2 | `getSnowIntensity()` ≥ triggers snow report |
| `WBN_WEATHER_FOG_THRESHOLD` | 0.4 | `getFogIntensity()` ≥ triggers fog report |
| `WBN_WEATHER_WIND_STRONG_KPH` | 40 | `getWindspeedKph()` ≥ triggers wind warning |
| `WBN_WEATHER_WIND_STORM_KPH` | 70 | Storm-force wind threshold |
| `WBN_WEATHER_COLD_EXTREME_C` | 0 | `getTemperature()` ≤ triggers cold warning |
| `WBN_WEATHER_HEAT_EXTREME_C` | 35 | `getTemperature()` ≥ triggers heat warning |

Power grid severities:

| Constant | Value | Transition |
|----------|-------|-----------|
| `WBN_POWER_SEVERITY_FAILURE` | 0.95 | Grid ON → OFF |
| `WBN_POWER_SEVERITY_RESTORED` | 0.80 | Grid OFF → ON |
| `WBN_POWER_SEVERITY_REMINDER` | 0.30 | Steady OFF periodic |
| `WBN_POWER_SEVERITY_STATUS` | 0.20 | Steady ON periodic |

### 55.8 Signal Fragment Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `WBN_FRAGMENT_CONF_SCALE` | 0.6 | Broadcast conf × this = fragment conf |
| `WBN_FRAGMENT_CONF_MIN` | 0.20 | Floor for fragment confidence |
| `WBN_FRAGMENT_CONF_MAX` | 0.60 | Ceiling (radio never exceeds) |
| `WBN_FRAGMENT_MAX_STORED` | 30 | Rolling cap in player ModData |
| `WBN_RUMOUR_REINFORCE_BOOST` | 0.05 | Same-direction confidence boost |
| `WBN_RUMOUR_CONTRADICT_DROP` | 0.10 | Contradiction confidence penalty |

### 55.9 Voice Pack Sections

WBN uses 6 voice pack override sections (all addon-extensible):

| Section | Used For |
|---------|---------|
| `wbn_opener` | Bulletin opener line |
| `wbn_closer` | Bulletin closer line |
| `wbn_weather` | Weather broadcast body |
| `wbn_power` | Power grid broadcast body |
| `wbn_flavour_market` | Market channel world-flavour |
| `wbn_flavour_emergency` | Emergency channel world-flavour |

---

## 56. Signal Ecology Core Tenet

Signal Ecology is always active. Signal quality is never flat or optional.
Weather, infrastructure, clarity, and saturation all contribute to a
composite signal that affects every POSnet system.

> **Design rule**: No sandbox toggle for Signal Ecology. The system falls
> back to a safe default (0.50 = "faded") if dependencies are missing,
> but never disables itself entirely.

**Cross-references**: `signal-ecology-design.md`, `POS_Constants_Signal.lua`,
`POS_SignalEcologyService.lua`
