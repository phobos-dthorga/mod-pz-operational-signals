# POSnet Iteration History

A living document tracking the iterative design journey of Phobos' Operational Signals.

---

## v0.1.0–v0.3.0 — Foundation (Initial Development)

### Goals
- Establish POSnet as a radio-driven procedural operations system
- CRT terminal interface with authentic retro aesthetic
- Basic mission generation and BBS system

### Key Decisions
- ISCollapsableWindow-based terminal with CRT bezel texture
- AZAS Frequency Index as hard dependency for per-world frequencies
- PhobosLib as shared utility foundation

---

## v0.4.0 — BBS & Investments

### Goals
- Expand terminal content beyond basic operations
- Add economic gameplay via investment system

### Key Decisions
- BBS Hub with investments, operations, and courier sub-menus
- Investment risk/reward simulation with obfuscation
- Mission negotiation and cancellation with reputation scaling
- PhobosLib_Pagination for list management

---

## v0.5.0–v0.6.0 — Screen Stack & Terminal Layout

### Goals
- Scalable screen architecture for growing feature set
- Professional 3-column terminal layout

### Key Decisions
- Screen stack with API, registry, and guard system
- 3-column layout: NavPanel (180px), ContentPanel (flex), ContextPanel (200px)
- Terminal power consumption (generator fuel drain)
- Signal strength system via inverse square law

---

## v0.7.0 — Market Intelligence Engine

### Goals
- Transform POSnet from operations-only to a full market intelligence system
- Category-specific item pricing based on real vanilla item data

### Key Decisions
- POS_ItemPool: runtime item pool from ScriptManager (5,105 items, 11 categories)
- POS_PriceEngine: deterministic day drift, reputation-scaled variance, speculation
- 18 sub-categories with weighted selection
- PhobosLib.weightedRandom() for reusable selection logic

### Lessons Learned
- weightedRandomMultiple() requires explicit weightFn parameter
- Item pool entries need unwrapping from {value, weight} wrappers

---

## v0.8.0 — Persistence Migration & Passive Recon

### Goals
- Server-authoritative economy for multiplayer safety
- Automate reconnaissance via period-authentic 90s devices

### Key Decisions
- World-scoped Global ModData (6 containers) over player modData
- 7-phase daily economy tick (purge, aggregate, drift, events, log, notify, persist)
- VHS-C tapes as physical intelligence storage (4 quality tiers)
- Passive recon devices: camcorder, field logger, data calculator
- TV CraftBench entity for VHS review
- Universal intelligence pipeline: all formats reduce to pen-and-paper notes

### Lessons Learned
- PZ's getFileWriter() doesn't create subdirectories (flattened to POSNET_*.log)
- sendServerCommand() 3-arg form fails in SP (requires player as first arg)
- Item tooltips must be in Tooltip.json, not UI.json
- PZ sandbox labels and tooltips both render raw text (not printf)

---

## v0.9.0 — Scanner Radio, UI Polish, Journal System

### Goals
- Enhance all vanilla radios with passive scanning
- Fix UI overflow and navigation consistency
- Readable market intelligence documents

### Key Decisions
- Dynamic radio tier system (4 tiers from TransmitRange, no hardcoded item names)
- PhobosLib.truncateText() for UI overflow prevention
- Exit button on root screens, Back button on all others
- PhobosLib tooltip provider for dynamic item tooltips
- PZ Literature API for readable market note documents
- PhobosLib_Address is 100% clean-room (parses vanilla streets.xml directly)

### Lessons Learned
- Kahlua (PZ Lua 5.1) colon-notation nil check: use obj.method not obj:method for existence tests
- PhobosLib_Tooltip provider pattern enables per-instance dynamic tooltips without Java hacks
- Comprehensive loot tables require awareness of ALL vanilla distribution list names
