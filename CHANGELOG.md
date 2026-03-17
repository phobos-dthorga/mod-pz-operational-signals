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
