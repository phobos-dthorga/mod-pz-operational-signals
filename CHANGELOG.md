<!--
  ________________________________________________________________________
 / Copyright (c) 2026 Phobos A. D'thorga                                \
 |                                                                        |
 |           /\_/\                                                         |
 |         =/ o o \=    Phobos' PZ Modding                                |
 |          (  V  )     All rights reserved.                              |
 |     /\  / \   / \                                                      |
 |    /  \/   '-'   \   This source code is part of the Phobos            |
 |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
 |  (__/    \_/ \/  \__)                                                  |
 |     |   | |  | |     Unauthorised copying, modification, or            |
 |     |___|_|  |_|     distribution of this file is prohibited.          |
 |                                                                        |
 \________________________________________________________________________/
-->

# Changelog

## v0.11.0 — Watchlist, Drill-Down & File Store (2026-03-20)

### Added
- **Item-level drill-down**: Commodity category screens now expand into individual item views with sub-category filtering.
- **Watchlist with price alerts**: Track categories, receive alerts on significant price changes. Integrates with PhobosNotifications when installed.
- **Context panels**: Traders, Price Ledger, and Market Reports screens now populate the right-hand context panel with live data.
- **Release pipeline**: ZIP packaging script, `manifest.json`, and categorized release notes generator.

### Changed
- **Player file store**: Watchlist, alerts, orders, and holdings arrays externalized from player modData to per-player `.dat` files in `Zomboid/Lua/POSNET/` to prevent save bloat. One-shot migration from legacy modData on first load.

### Fixed
- **Design guidelines compliance**: `splitString` runtime crash in WorldState cache loader, missing footer separator on Negotiate screen, 14 files with inline string literals replaced by `POS_Constants`.

---

## v0.10.0 — Danger Detection & Cache Externalization (2026-03-19)

### Added
- **Danger detection gate**: Proximity zombie scan gates terminal access with configurable radius and threshold.
- **Building/mailbox cache externalization**: Caches written to flat files in `Zomboid/Lua/` to survive session restarts.
- **Market note icon**: Custom icon for Raw Market Note items.
- **Dynamic tooltips**: Item tooltips via `PhobosLib.registerTooltipProvider()` showing price, stock, confidence, and freshness.
- **Journal system**: Iteration history log for terminal sessions.
- **Item filtering**: Filter items by name/type within commodity screens.

### Fixed
- Tooltip.json created for item tooltips (was in wrong translation file).

---

## v0.9.0 — Market Intelligence & Passive Recon (2026-03-19)

### Added
- **Market & exchange framework**: Data models, registries, and services for a full commodity market simulation.
- **Vanilla item database**: Room category mapping scripts linking PZ items to market categories.
- **Market intelligence engine**: Item selection pools, procedural pricing with drift, and speculation mechanics.
- **Persistence architecture**: 5-phase migration to world ModData — foundation, core migration, client snapshot protocol, server validation, admin tools.
- **Passive recon devices**: Camcorder, Field Logger, Scanner Radio — craftable items with custom icons and recipes.
- **Passive recon system**: VHS tape recording, scanning engine, and event log integration.
- **Intel gathering cooldown**: Per-location visit cooldown for field note-taking.
- **Dynamic note tooltip**: Raw Market Notes show price/stock/confidence inline.
- **Tape event log**: VHS tapes log scan events for later playback.
- **VHS tape review**: TV station playback of recorded reconnaissance data.
- **Universal intelligence pipeline**: Unified flow from field notes through terminal upload to market database.
- **Scanner radio passive recon**: All vanilla radios enhanced with passive intelligence gathering.

### Fixed
- `sendServerCommand` requires player arg in singleplayer (critical).
- Event log file paths flattened for PZ `getFileWriter` compatibility.
- Terminal UI overflow guards + Exit button on root screens.
- Lua syntax fixes for dot-notation method checks and `selectItems` weight function.
- Deterministic hash replacing `newrandom()` in POS_PriceEngine.
- Removed `%%` from sandbox tooltips; comprehensive loot table audit.

### Changed
- Extracted remaining magic numbers/strings to `POS_Constants`.

---

## v0.8.0 — Screen Stack Architecture (2026-03-19)

### Added
- **Screen stack architecture**: `POS_API.lua` public registration, `POS_Registry.lua` central storage, `POS_MenuBuilder.lua` dynamic menus, `POS_ScreenManager.lua` guard enforcement with `onEnter`/`onExit` hooks and breadcrumbs.
- **3-column terminal layout**: NavPanel, ContentPanel, ContextPanel.
- **Terminal power consumption**: Generator fuel drain while terminal is open.
- **Street addresses**: Map button integration and signal range display.
- **Retroactive building/mailbox scan**: Full world scan on first mod load.
- **Terminal size increase**: Default 1080×1170 (1.5× previous).

### Changed
- Centralised screen layout, colours, and boilerplate into `POS_TerminalWidgets`.
- Extracted magic numbers and strings to named constants.

### Fixed
- `getChannel()` used instead of `getFrequency()` for DeviceData.
- On-demand investment generation + faster first broadcast.
- TitleKey mismatches, missing connected flag, panel clipping.
- VERSION header added to sandbox-options.txt.

---

## v0.7.0 — AZAS Integration & Signal Strength (2026-03-18)

### Added
- **AZAS dual-band integration**: POSnet_Operations (amateur) and POSnet_Tactical (military) frequency bands, dynamic per-world.
- **Frequency validation**: Radio must be tuned to correct POSnet frequency; desktop computers display assigned frequencies.
- **Signal strength**: Inverse-square-law model from radio TransmitRange; gates access below threshold and scales rewards 50–100%.

---

## v0.6.0 — BBS Hub, Missions & Widget System (2026-03-18)

### Added
- **Widget-based terminal UI**: Complete rewrite from legacy screen system to composable widget architecture.
- **Delivery mission system**: Courier service with player-discovered mailbox cache.
- **Unified reputation framework**: 4-tier system gating mission access and reward quality.
- **Recon mission system**: Camera → photograph → field report pipeline.
- **Terminal themes**: 4 colour themes (green, amber, blue, white) + 4 font sizes.
- **BBS hub menu**: Main Menu → BBS → Investments | Operations | Courier.
- **Mission cancellation**: Cancel at any stage; Tier I no penalty, Tiers II–IV scale upward.
- **Negotiation system**: Haggle reward/deadline before accepting; reputation-weighted success chance.
- **Pagination**: PhobosLib_Pagination widget in BBS, Operations, and Deliveries screens.

### Fixed
- Widget migration: clearPanel crash, BuiltinTemplates load order, button click closing terminal, navigation guard persistence, onMouseDownOutside bounds check.

---

## v0.5.0 — Portable Computer (2026-03-18)

### Added
- **Portable computer item**: 10 kg, ConditionMax=100, rare world loot (not craftable). Battery drains while terminal is open.
- Inventory radio + portable computer detection for mobile POSnet access.

### Fixed
- `isInventoryRadio` crash when radio object was nil.

---

## v0.4.2 — Load Order Fix (2026-03-18)

### Fixed
- Screen registration load order — require `POS_ScreenManager` before registering screens.

---

## v0.4.1 — CRT Bezel Bugfixes (2026-03-18)

### Fixed
- 5 CRT bezel terminal rendering bugs.
- Added `Keyboard` to luacheckrc read_globals.

---

## v0.4.0 — BBS Menu & Investments (2026-03-18)

### Added
- **BBS menu system**: Bulletin board hub for operations and services.
- **Investment mechanic**: Money/MoneyBundle investments with server-side maturity resolution and 11 sandbox options.
- **CRT monitor bezel**: Textured terminal frame with visual overhaul.

---

## v0.3.0 — Boot Sequence + Resizable Windows (2026-03-18)

- **DOS boot sequence**: Typewriter-style character-by-character boot animation on first terminal open per world-load.
- **Resizable terminal**: Terminal window can be resized via drag handle (coexists with "Resize Any Window" mod).
- **Click to skip**: Click anywhere during boot to skip straight to operations view.
- **Game speed scaling**: Boot animation speed scales with game speed multiplier.

## v0.2.0 — Core Gameplay Loop (2026-03-18)

- **Terminal UI**: Retro green-on-dark CRT-style terminal window with scanline effect.
- **Physical setup**: Right-click any radio near a vanilla desktop computer to "Connect to POSnet".
- **Context menu**: "Connect to POSnet" on world-placed and inventory radios with validation tooltips.
- **Connection validation**: Checks radio power, turned-on state, and desktop computer proximity.
- **Server→Client flow**: Operations broadcast via server commands, received by OnServerCommand handler.
- **Built-in templates**: 5 starter item_acquire missions across 4 categories.
- **Welcome popup**: PhobosLib guide popup explaining setup and usage.
- **Translation keys**: 20 new i18n keys for terminal, context menu, guide, and connection states.

## v0.1.0 — Initial Scaffold (2026-03-18)

- Project scaffold with CI, pre-commit hook, sandbox options, and Lua module stubs.
- 7 Lua modules covering the 6 core systems: Radio Interception, Mission Generator, Mission Templates, Operation Log, Broadcast System, Completion Detector, and Sandbox Integration.
- 6 sandbox options with JSON translations.
- GitHub Actions CI with 9 validation checks.
