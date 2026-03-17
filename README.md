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

A radio-driven procedural operations system for Project Zomboid Build 42. Players equipped with radios can intercept transmissions from the POSnet (Phobos Operational Signals Network), generating field operations that encourage exploration across Knox Country.

## Status

**v0.1.0** — Initial scaffold. Core architecture in place, mission system under development.

## Requirements

| Dependency | Type | Notes |
|------------|------|-------|
| [PhobosLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865) | Required | Shared utility library for all Phobos mods |

## Core Systems

### Radio Interception
Hook into PZ's native radio system to deliver POSnet broadcasts on a dedicated frequency. Players must tune in to receive operations.

### Mission Generator
Procedural mission generation with weighted category selection, location scouting, and difficulty scaling based on game day and player skills.

### Operation Log
In-game journal tracking active, completed, and expired operations. Accessible via context menu or keybind.

### Broadcast Message System
Diegetic radio transmissions with colour-coded speaker identities, signal strength simulation, and atmospheric message formatting.

### Completion Detection
Event-driven objective tracking: item acquisition, location visits, entity interactions, and timed survival objectives.

## Mission Categories

| Category | Description |
|----------|-------------|
| Industrial Recovery | Salvage equipment and materials from factories and warehouses |
| Vehicle Salvage | Locate and recover specific vehicles or vehicle parts |
| Scientific Research | Collect specimens, samples, or data from designated locations |
| Survivor Assistance | Deliver supplies or clear threats near survivor locations |
| Infrastructure Repair | Restore power, water, or structural integrity at key sites |

## Modules

| Module | Side | Description |
|--------|------|-------------|
| `POS_SandboxIntegration` | Shared | Sandbox option accessors |
| `POS_RadioInterception` | Client | Radio frequency registration and broadcast delivery |
| `POS_MissionGenerator` | Shared | Procedural mission creation and template system |
| `POS_MissionTemplates` | Shared | Mission category definitions and objective templates |
| `POS_OperationLog` | Client | In-game operation journal UI and persistence |
| `POS_BroadcastSystem` | Server | Timed broadcast scheduling and transmission |
| `POS_CompletionDetector` | Shared | Objective tracking and completion event handling |

## Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| Enable Debug Logging | false | PhobosLib debug output for POSnet modules |
| Enable POSnet Broadcasts | true | Master toggle for the entire system |
| Broadcast Interval (minutes) | 30 | Time between POSnet transmissions |
| Max Active Operations | 3 | Maximum concurrent operations in the log |
| Operation Expiry (days) | 7 | Days before an uncompleted operation expires |
| POSnet Frequency | 91500 | Radio frequency for POSnet broadcasts (Hz) |

## Project Layout

```
mod-pz-operational-signals/
├── mod.info                          # Root metadata (versionMin=42.15.0)
├── common/
│   ├── media/
│   │   ├── lua/
│   │   │   ├── shared/               # Shared Lua modules
│   │   │   ├── client/               # Client-only Lua (radio UI, journal)
│   │   │   └── server/               # Server-only Lua (broadcast scheduling)
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
./scripts/bump-version.sh 0.2.0
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
