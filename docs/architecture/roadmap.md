# POSnet Expansion Roadmap

> Living document. No implementation dates. Updated as features are
> completed or reprioritised. Last audit: 2026-03-24.

---

## Status Overview

| # | Feature | Status | Tier | Complexity | Design Ref |
|---|---------|--------|------|------------|------------|
| 1 | Living Market Phase 2-3 (4 archetypes) | Designed | High | Medium-High | living-market-design.md |
| 2 | Mission Content Expansion | 5 of ~12 types | High | Low | mission-system-design.md |
| 3 | Market Event System (rumours) | Schema only | High | High | living-market-design.md Phase 4 |
| 4 | Contract System Phase 2-3 | Phase 1 done | Medium | Medium | design-guidelines.md §42-43 |
| 5 | Camera Workstation Phase 2-4 | Phase 1 done | Medium | Medium | camera-workstation-design.md |
| 6 | Data Recorder Phase 2-4 | Phase 1 done | Medium | Medium | data-recorder-design.md |
| 7 | Signal Strength affects Missions | Designed, 0% | Medium | Low | design-guidelines.md §5.4 |
| 8 | Unimplemented Terminal Screens (4) | Constants only | Polish | Medium | design-guidelines.md §33 |
| 9 | Building Target Name Resolution | Placeholder | Polish | Trivial | POS_MissionGenerator.lua:132 |
| 10 | Market Recon Repeat Visit Discount | TODO in code | Polish | Low | POS_MarketReconAction.lua:96 |
| 11 | Physical Item Trading (Contacts) | Designed, 0% | Polish | Medium | design-guidelines.md §1.3 |
| 12 | Cross-Mod Missions (PCP/PIP) | Not started | Content | Low | interoperability-matrix.md |
| 13 | Archetype Voice Packs (4 remaining) | 3 of 7 done | Content | Low | design-guidelines.md §32 |
| 14 | Satellite Passive Collection | Design only | Future | High | satellite-passive-collection-design.md |

---

## Tier 1: High Impact

### 1. Living Market Phase 2-3 — Additional Archetypes

**Status**: Phase 1 (3 archetypes: Scavenger, Quartermaster, Wholesaler)
implemented. 4 more designed but not instantiated.

**What's missing**:
- Phase 2 — **Smuggler** (creates market distortion, grey-market supply,
  betrayal risk) + **Speculator** (creates price spikes, buys low/sells
  high, volatility injection)
- Phase 3 — **Military Logistician** (controlled distribution, strict
  specs, reliable but inflexible) + **Specialist Crafter** (produces
  niche goods, recipe-gated availability)

**What exists**: `POS_ArchetypeSchema.lua`, `Definitions/Archetypes/`
directory with 3 files, `POS_MarketAgent.lua` agent lifecycle.

**Dependencies**: Each archetype = 1 definition file + optional text pool
additions for voice packs. No schema changes needed.

**Design ref**: `living-market-design.md` Phases 2-3.

---

### 2. Mission Content Expansion

**Status**: 5 mission definitions (recon_basic, recon_targeted,
delivery_standard, trade_procurement, signal_intercept).

**What's missing**:
- Recovery missions (salvage/rescue)
- Survey missions (map charting, area assessment)
- Supply missions (vendor restocking on behalf of wholesalers)
- Combat-adjacent recon (reconnaissance under zombie threat)
- Cross-mod missions (PCP chemistry supply runs, PIP specimen collection)

**What exists**: `POS_MissionSchema.lua`, `POS_MissionBriefingResolver.lua`
(8-step compositor), `Definitions/Missions/` + `Definitions/TextPools/`.

**Dependencies**: Each mission type = 1 definition file + 0-N text pool
entries. No schema changes needed. Compositor pipeline handles everything.

**Design ref**: `mission-system-design.md`.

---

### 3. Market Event System (Rumours)

**Status**: `POS_EventSchema.lua` exists. Signal emission is placeholder.

**What's missing**:
- Soft-class event emission during economy ticks (bulk arrivals, convoy
  delays, warehouse fires, controlled releases)
- Event-to-rumour translation (event → human-readable gossip)
- Event-to-market-effect propagation (event → price/stock changes)
- Integration with delivery mission generation (events trigger missions)

**What exists**: Event schema + registry pattern, `POS_RumourGenerator.lua`
(generates rumours), `POS_MarketSignals` screen (merged event/rumour feed).

**Dependencies**: Requires Living Market enabled. Event definitions follow
data-pack pattern.

**Design ref**: `living-market-design.md` Phase 4+.

---

## Tier 2: Medium Impact

### 4. Contract System Phase 2-3

**Status**: Phase 1 (world-originated contracts) implemented.

**What's missing**:
- Phase 2 — **Spot Sell**: player initiates sale to a wholesaler (sell tab
  on CommodityItems screen, 65% of buy price baseline, wholesaler state
  modifiers)
- Phase 3 — **Free Agent System**: delegate selling to runners/brokers who
  operate autonomously. State machine: drafted → assembling → transit →
  negotiation → settlement. 5 visibility layers. Intervention buttons.

**What exists**: `POS_ContractService.lua` (lifecycle), `POS_TradeService.lua`
(executeSell already exists), `POS_Screen_Contracts.lua`.

**Dependencies**: Phase 2 is low complexity (sell tab). Phase 3 requires
new schemas, agent pool, and 2 new screens.

**Design ref**: `design-guidelines.md` §42-43.

---

### 5. Camera Workstation Phase 2-4

**Status**: Phase 1 (Compile Site Survey) implemented.

**What's missing**:
- Phase 2 — Tape Review + Market Bulletin actions (2 more action types)
- Phase 3 — Camera output gates missions; mission success photos
- Phase 4 — Advanced metadata, confidence decay, archival system

**What exists**: `POS_CameraService.lua`, `POS_CameraCompileAction.lua`,
`POS_CameraContextMenu.lua`, entity definitions.

**Design ref**: `camera-workstation-design.md`.

---

### 6. Data Recorder Phase 2-4

**Status**: Phase 1 (VHS cassettes) implemented.

**What's missing**:
- Phase 2 — Microcassettes, 3.5" floppy disks as new media types
- Phase 3 — Noise reduction, cross-validation, conflict resolution
- Phase 4 — Degradation, re-recording, compression

**What exists**: `POS_DataRecorderService.lua`, item definitions for all
media types, recipes for review/salvage.

**Design ref**: `data-recorder-design.md`.

---

### 7. Signal Strength Affects Mission Quality

**Status**: Designed, sandbox-gated (`POS.SignalAffectsMissionRange`),
zero implementation.

**What's missing**:
- Distance calculation weighted by signal percentage
- Briefing text clarity/obscuration based on signal
- Mission pool filtering based on signal range

**What exists**: Signal strength calculation in `POS_ConnectionManager.lua`,
reward scaling (50-100%) already uses signal.

**Dependencies**: Trivial to implement. Pairs well with radio hardware
progression (WalkieTalkie1 → HamRadio2).

**Design ref**: `design-guidelines.md` §5.4.

---

## Tier 3: Polish & Content

### 8. Unimplemented Terminal Screens

Four screen constants defined but no screen files exist:

| Constant | Screen ID | Purpose |
|----------|-----------|---------|
| `SCREEN_WHOLESALER_DIR` | pos.markets.directory | Wholesaler network visibility |
| `SCREEN_ZONE_OVERVIEW` | pos.markets.zones | Zone pressure heatmap |
| `SCREEN_EXCHANGE_OVERVIEW` | pos.exchange.overview | Stock exchange viewer |
| `SCREEN_EVENT_LOG` | pos.markets.events | Hard events timeline |

**Recommendation**: Wholesaler Directory is highest value (visibility into
supply network). Zone Overview is good world-building. Exchange and Event
Log can wait.

---

### 9. Building Target Name Resolution

**Status**: `POS_MissionGenerator.lua` line 132 hardcodes `"target site"`.

**Fix**: Wire `POS_BuildingCache.getBuildingName(buildingKey)` into mission
context token table. Trivial change, meaningful immersion improvement.

---

### 10. Market Recon Repeat Visit Discount

**Status**: TODO comment in `POS_MarketReconAction.lua:96`.

**Feature**: Player revisits a location within 7 days, action time reduced
by 50%. Rewards strategic planning and location knowledge.

**Dependencies**: modData tracking of last visit per location.

---

### 11. Physical Item Trading (Contacts)

**Status**: Designed in §1.3, sandbox-gated (`EnableContactTrading`),
zero implementation.

**Feature**: Before accepting delivery missions, player visits a contact
location in-world (right-click context menu), meets the contact, and
trades directly rather than via terminal.

**Dependencies**: Mission definition schema extension, context menu
integration, trade panel UI.

---

## Cross-Mod Opportunities

### 12. PCP/PIP Cross-Mod Missions

- **PCP**: Chemistry supply run missions (acquire reagents, deliver to
  lab). Compounds as high-value trade goods in contracts.
- **PIP**: Biological specimen collection contracts (deliver specimens
  to research facilities). Pathology equipment as mission rewards.

**Implementation**: Optional cross-mod mission definitions that only
activate when both mods are detected via `getActivatedMods():contains()`.

---

### 13. Archetype Voice Packs

**Status**: 3 of 7 archetypes have voice packs (smuggler, military,
trader).

**Missing**: Scavenger, Quartermaster, Wholesaler, Speculator voice packs.
Each is a text pool definition file with 5-10 entries.

---

## Future (Long-Term)

### 14. Satellite Passive Background Data Acquisition

**Status**: Design document only. Prerequisite: satellite wiring connection
(§5.6).

**Feature**: Satellite dish as an always-on intelligence appliance. Three
operating states: Idle, Passive Collection (heavy power drain), Deep Sweep
(extremely high power, rare intercepts). Generates intermediate resources
(raw signal logs, traffic fragments) that require terminal processing.

**Dependencies**: Satellite wiring system, power model, data pipeline.

**Design ref**: `satellite-passive-collection-design.md`.
