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

# Phobos' Operational Signals (POSnet)

A radio-driven procedural operations and market intelligence system for Project Zomboid Build 42. Intercept POSnet transmissions, gather field intelligence with 90s-era recon devices, trade commodity data via VHS tapes, and deploy into the field.

## Status

**v0.10.0** — Preview release. Core systems functional: terminal UI, operations/delivery/investment missions, market intelligence engine, passive reconnaissance devices, scanner radio, VHS tape pipeline, server-authoritative economy, danger detection, and externalized data caches. Active development.

## Requirements

| Dependency | Version | Notes |
|------------|---------|-------|
| [PhobosLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865) | 1.40.0+ | Shared utility library (danger detection, weighted random, tooltips, text utils) |
| [AZAS Frequency Index](https://steamcommunity.com/sharedfiles/filedetails/?id=3350937757) | Latest | Dynamic per-world radio frequency assignment |

## Soft Dependencies

These mods are **not required** but POSnet detects them at runtime and enables additional features when present.

| Dependency | Integration |
|------------|-------------|
| [Phobos Chemistry Pathways](https://steamcommunity.com/sharedfiles/filedetails/?id=3668197831) | Cross-mod market categories (chemicals, lab equipment) |
| [Phobos Industrial Pathology](https://steamcommunity.com/sharedfiles/filedetails/?id=3686101131) | Cross-mod specimen and pathology market data |
| [Paper Trails](https://steamcommunity.com/sharedfiles/filedetails/?id=3646157770) | Street address resolution for mission briefings and map waypoints |
| [Moodle Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3340065917) | Custom moodle display for intel gathering status |

## Core Systems

### POSnet Terminal
CRT-style terminal interface with 4 colour themes, 3-column layout (nav/content/context panels), boot sequence, and screen stack architecture. Connects via desktop computer (within 3 tiles of radio) or portable computer (inventory). Signal strength based on radio hardware via inverse square law.

### Operations & Missions
Procedural recon, delivery, and courier missions via BBS. Investment opportunities with risk/reward simulation. Mission negotiation (reputation-weighted success chance) and cancellation with tier-scaled penalties. 5 reputation tiers gate content access.

### Market Intelligence
Commodity market simulation with 11 categories and 18 sub-categories. 5,105 vanilla items mapped to categories. Day-to-day price drift with supply/demand speculation. Reputation-scaled price accuracy across 5 tiers. Server-authoritative economy with daily tick.

### Passive Reconnaissance Devices
- **Recon Camcorder** -- equippable, highest quality visual recon, requires VHS tape
- **Field Survey Logger** -- equippable, environmental metadata, silent operation
- **Scanner Radio** -- all 12 vanilla radios enhanced with 4-tier passive scanning
- **Data Calculator** -- compile raw data into higher-quality reports
- **VHS-C Tapes** -- physical intelligence storage (4 quality tiers), crafting (repair, splice, improvise), review at TV stations

### Safety & Intelligence Quality
Danger detection gates intel gathering and passive recon when threats are nearby (zombies, fire, combat) via `PhobosLib.isDangerNearby()`. 5-state context menu with colour-coded status. Dynamic note tooltips show observed items and prices. Journal/document system for in-game readable intelligence reports. Per-location intel cooldown prevents exploitation.

### Data Persistence
World-scoped Global ModData for shared economy (6 containers). Tiny player-bound state (reputation, cash, watchlist, alerts). Building/mailbox caches externalized to flat files for scalability. Append-only event logs with capped rolling windows to prevent save bloat. Auto-migration from legacy data formats.

### AZAS Frequency Index
Dual-band registration: POSnet_Operations (amateur) and POSnet_Tactical (military). Radio must be tuned to the correct frequency. Band determines content access (amateur = Tier I-II, tactical = Tier III-IV).

## Sandbox Options

60+ configurable options covering:

| Category | Examples |
|----------|----------|
| Broadcasts | Interval, max active operations, expiry |
| Missions | Reputation tiers, reward multiplier, cancellation penalties |
| Investments | Payback range, risk variance, obfuscation, return multipliers |
| Deliveries | Distance range, road factor, expiry |
| Markets | Category weights, drift, broadcast quality, intel freshness |
| Recon Devices | Scan radii, intervals, camcorder noise, tape degradation |
| VHS Tapes | Crafting toggle, foraging toggle, review time |
| Economy | Daily tick, event logs, rolling caps |
| Terminal | Font size, colour theme, power drain, nav/context panels |

## Project Layout

```
mod-pz-operational-signals/
├── mod.info                          # Root metadata (versionMin=42.15.0)
├── common/
│   ├── media/
│   │   ├── lua/
│   │   │   ├── shared/               # Shared Lua modules
│   │   │   ├── client/               # Client-only Lua (terminal, recon, context menus)
│   │   │   └── server/               # Server-only Lua (broadcast, economy tick)
│   │   ├── scripts/                  # Item/recipe definitions
│   │   ├── textures/                 # Icons (128x128 RGBA PNG)
│   │   └── sandbox-options.txt       # Sandbox option definitions
├── 42/
│   ├── mod.info                      # Version-specific metadata
│   └── media/lua/shared/Translate/   # JSON translations (42.15+)
├── docs/                             # Documentation and Steam Workshop assets
├── scripts/                          # Utility scripts (version bumping)
└── .github/                          # CI workflows and issue templates
```

## Development

### Pre-commit hook
```bash
git config core.hooksPath .githooks
```

### Bump version
```bash
./scripts/bump-version.sh 0.10.0
```

### Run luacheck
```bash
luacheck common/media/lua/
```

## Licensing

- **Code**: [MIT License](LICENSE)
- **Assets** (textures, icons): [CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA.txt)

## Links

- [CHANGELOG](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Versioning Policy](VERSIONING.md)
- [PhobosLib on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865)
- [POSnet on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3686788646)
