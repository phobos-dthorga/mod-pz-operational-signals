# POSnet Expansion Roadmap

> Living document. No implementation dates. Updated as features are
> completed or reprioritised. Last audit: 2026-03-30 (post-v0.25.0).

---

## Status Overview

| # | Feature | Status | Design Ref |
|---|---------|--------|------------|
| 1 | Living Market (7 archetypes) | **DONE** | living-market-design.md |
| 2 | Mission Content (18 definitions) | **DONE** | mission-system-design.md |
| 3 | Market Event System (rumours) | **DONE** | living-market-design.md |
| 4 | Contract System (spot sell + free agents) | **DONE** | design-guidelines.md |
| 5 | Camera Workstation Phase 1-2 | **DONE** | camera-workstation-design.md |
| 6 | Data Recorder Phase 1-2 | **DONE** | data-recorder-design.md |
| 7 | Signal Strength affects Missions | **DONE** | design-guidelines.md §5.4 |
| 8 | Terminal Screen Consolidation | **DONE** | design-guidelines.md §33 |
| 9 | Building Target Name Resolution | **DONE** | POS_BuildingCache.lua |
| 10 | Market Recon Repeat Visit Discount | **DONE** | POS_MarketReconAction.lua |
| 11 | Cross-Mod Missions (PCP/PIP) | **DONE** | interoperability-matrix.md |
| 12 | Archetype Voice Packs (9/9) | **DONE** | design-guidelines.md §32 |
| 13 | Satellite Uplink (Tier IV) | **DONE** | satellite-uplink-design.md |
| 14 | Strategic Relay (Tier V) | **DONE** | tier-v-strategic-relay-design.md |
| 15 | Passive Recon System | **DONE** | passive-recon-design.md |
| 16 | Tutorial & Milestone System (22 milestones) | **DONE** | design-guidelines.md §23 |
| 17 | SIGINT Skill (10 levels) | **DONE** | sigint-skill-design.md |
| 18 | WBN Radio Pipeline | **DONE** | world-broadcast-network-design.md |
| 19 | Radio Proximity Filtering | **DONE** | design-guidelines.md §5.7 |
| 20 | Event-to-Market Price Coupling | **DONE** | design-guidelines.md §55.1 |
| 21 | Fragment-to-MarketDatabase Bridge | **DONE** | design-guidelines.md §55.1 |
| 22 | Item Spawn Expansion + SIGINT Books | **DONE** | POS_Distributions.lua |
| 23 | Entropy System (all 3 phases) | **DONE** | entropy-system-design.md |
| 24 | Signal Ecology v2 (4/5 pillars) | **DONE** | signal-ecology-design.md |
| 25 | Receiver Quality (hardware-scaled WBN) | **DONE** | *(needs §61 in design-guidelines)* |
| 26 | Broadcast Influence System (Phase A) | **DONE** | broadcast-influence-design.md, §60 |
| 27 | Physical Item Trading (Contacts) | Designed, 0% | design-guidelines.md §1.3 |
| 28 | Satellite Passive Collection | Design only | *(design doc missing)* |

**27 of 28 features complete. 1 designed but unstarted. 1 design-only (doc missing).**

---

## Completed Features (v0.25.0)

### Core Systems

- **Living Market**: 7 archetypes, 6 zones, zone pressure, supply/demand
  simulation, price drift, event system, rumour generation
- **Mission System**: 18 definitions across 6 categories + 2 cross-mod.
  Negotiation, cancellation, barter, band-gated visibility.
- **Contract System**: World contracts, spot selling, free agents (5
  archetypes, state machine, signal feed)
- **Passive Recon**: Camcorder, field logger, scanner radio. VHS/
  microcassette/floppy media pipeline.
- **Camera Workstation**: Compile, review, market bulletin actions.
- **Data Recorder**: All media types, passive scan routing.
- **Satellite Uplink (Tier IV)**: Broadcast, calibration, wired links.
- **Strategic Relay (Tier V)**: Discovery, remote calibration, bandwidth.
- **SIGINT Skill**: 10 levels, 5 skill books with loot distribution.
- **Tutorial System**: 22 milestones (14 core + 8 expansion), progressive
  toasts, popups for major features, `PN_CHANNEL_TUTORIAL`.

### Radio & Broadcast Systems

- **WBN Radio Pipeline**: Harvest → Editorial → Composition → Scheduling
  → Delivery. 3 channels, 9 voice packs, 415+ translation keys, voice
  pack text pool resolution.
- **Radio Proximity Filtering**: Intercepts AND WBN broadcasts gated by
  vanilla PZ `HasPlayerInRange()` (volume-aware). Inventory radios checked
  via `inv:contains(device)`. Generic API: PhobosLib `findNearbyTunedRadio`.
- **Receiver Quality**: Radio hardware scales WBN dropout rate. Data-pack
  profiles for all 17 vanilla radios (`POS_ReceiverProfileSchema` +
  registry). Item condition scaling. Formula fallback for modded radios.
  `PN_CHANNEL_SIGNAL` + weak receiver notification.
- **Event-to-Market Coupling**: Zone events affect prices directly.
- **Fragment-to-MarketDatabase Bridge**: Radio = passive market intel.
  Fragment confidence scaled by receiver quality.

### Signal Ecology v2

Five-pillar multiplicative composite model (propagation × infrastructure
× (clarity − noise) × (1 − saturation) × intent).

- **Propagation**: Weather + season modifiers (8 weather, 4 season triggers)
- **Infrastructure**: Power grid state (grid_on/off/failing/generator)
- **Clarity**: SIGINT skill tier (0.70–1.00 across 5 tiers)
- **Saturation**: Active agents + market state + seasonal modifiers
- **Intent**: 1.0 stub — see Outstanding Items §O3
- **Noise**: Active weather + market triggers (subtracted from clarity)
- **Qualitative states**: locked / clear / faded / fragmented / ghosted / lost
- **Tier clamping**: Floor/ceiling per SIGINT tier
- **Hourly recalculation** with event-driven invalidation

### Entropy System (All 3 Phases)

- **Phase 1**: Fog-of-market (certainty, freshness, rumourLoad,
  contradiction, trust, silenceDays, concealment, shadowState)
- **Phase 2**: Weather decay, blackout, wholesaler concealment
- **Phase 3**: Seasonal modifiers, information shadows, speculative
  rumours, trust erosion, desperation index

### Broadcast Influence System (Phase A)

- Perceived pressure layer from satellite broadcasts
- Trust mutation from broadcast accuracy
- Freshness decay + resolution
- 3 PN notification events + data reset integration

---

## Outstanding Items (Full Audit — 2026-03-30)

### Stubs & Partial Implementations

| ID | Item | Location | Severity | Notes |
|----|------|----------|----------|-------|
| O1 | Satellite decalibration check | `POS_SatelliteService.lua:710` | LOW | Called from economy tick but is a no-op stub. Comment: "Full implementation deferred to when satellite sprites are known." Sandbox option `SatelliteDecalibrationDays` is wired but the check body does nothing. |
| O2 | ChunkProcessor type-selective dispatch | `POS_ChunkProcessor.lua` | LOW | `processType()` delegates to `processAll()` with comment "not yet type-selective". All chunk types process identically; no gameplay impact until media-type-specific processing is needed. |
| O3 | Signal Intent pillar (Tier V Phase E) | `POS_SignalEcologyService.lua:318` | LOW | Hardcoded `1.0`. Designed for bandwidth allocation, priority routing, transmission type, encryption strength (see signal-ecology-design.md §2.5). Intentionally deferred. |

### Missing Documentation

| ID | Item | Expected Location | Severity | Notes |
|----|------|-------------------|----------|-------|
| D1 | Receiver Quality design section | design-guidelines.md §61 | MEDIUM | Feature is implemented (v0.25.0) but no design doc section exists. §60 is already Broadcast Influence. Need new §61 documenting the formula, quality bands, client-side degradation architecture, and data-pack schema. |
| D2 | Satellite Passive Collection design | satellite-passive-collection-design.md | MEDIUM | Referenced in roadmap but **file does not exist**. Feature is "design only" — the document itself is the deliverable and it's missing. |
| D3 | Signal Ecology §8 migration status | signal-ecology-design.md §8 | LOW | Migration phases A-C marked complete, but Phase D (UI) and Phase E (Intent) status not updated post-implementation. |

### Dependency & Configuration

| ID | Item | Location | Severity | Notes |
|----|------|----------|----------|-------|
| C1 | PhobosLib min version not specified | mod.info (root + 42/) | MEDIUM | POSnet requires PhobosLib ≥1.67.0 for `getReceiverQualityFactor()`, `isTelevision()`, `resolveQualitativeBand()`. The `require=` line specifies the mod ID but no minimum version. PZ mod.info supports `require=ModID:version` syntax. |

### Unstarted Designed Features

| ID | Item | Design Ref | Severity | Notes |
|----|------|------------|----------|-------|
| F1 | Physical Item Trading | design-guidelines.md §1.3 | LOW | Documented as future. 0% code. No sandbox option defined. No mission contact location generation. No context menu handler. Not blocking anything. |
| F2 | Satellite Passive Collection | *(missing doc)* | LOW | Concept only. Depends on D2 (design doc) being written first. |
| F3 | Broadcast Influence Phase B | broadcast-influence-design.md | LOW | Phase A complete. Phase B (wholesaler posture shifts, echo generation) is designed but unstarted. |

---

## Future (Long-Term)

### Physical Item Trading (Contacts) — F1

**Status**: Designed (design-guidelines.md §1.3), sandbox-gated, 0% impl.

Certain missions include a contact location for physical item exchange.
Player travels to the contact point and right-clicks to open a trade
panel. Gated by `EnableContactTrading` (not yet defined in sandbox).

### Satellite Passive Collection — F2

**Status**: Concept only. Design document missing (see D2).

### Broadcast Influence Phase B — F3

**Status**: Phase A complete (v0.25.0). Phase B designed.

Wholesaler posture shifts from sustained broadcasts, rumour echo
generation, broadcast saturation penalties.

### Signal Intent Pillar (Tier V Phase E) — O3

**Status**: Stub (1.0). Design complete in signal-ecology-design.md §2.5.

Bandwidth allocation, priority routing, transmission type, encryption
strength. Requires Strategic Relay UI enhancements.

---

## Dependencies Graph

```
Entropy System (COMPLETE)
    |
    +---> Broadcast Influence Phase A (COMPLETE, v0.25.0)
    |         |
    |         +---> Broadcast Influence Phase B (FUTURE — F3)
    |
    +---> Signal Ecology v2 (COMPLETE, 4/5 pillars)
              |
              +---> Receiver Quality (COMPLETE, v0.25.0)
              |
              +---> Intent Pillar (FUTURE — O3, needs Tier V Phase E)

Tutorial System (COMPLETE, 22 milestones)

Physical Item Trading (FUTURE — F1, independent)

Satellite Passive Collection (FUTURE — F2, needs design doc D2)
```

---

## Release History

| Version | Date | Key Features |
|---------|------|-------------|
| v0.25.0 | 2026-03-30 | Receiver quality, broadcast influence, tutorial expansion, WBN proximity gate, TV remediation |
| v0.24.0 | 2026-03-29 | Entropy system Phase 1 (fog-of-market) |
| v0.23.0 | 2026-03-28 | Radio proximity, WBN pipeline, signal ecology, spawns |

---

## Session Log (2026-03-28 — 2026-03-29)

Features shipped:
1. Expanded item spawns + SIGINT skill book distribution
2. Radio proximity filtering for intercepts (PhobosLib v1.65.0)
3. WBN radio pipeline wired (3 integration bugs fixed)
4. Event-to-market price coupling
5. Fragment-to-MarketDatabase bridge
6. Entropy system design document
7. Entropy Phase 1: fog-of-market layer (v0.24.0)
8. Entropy Phase 2: weather, blackout, wholesaler concealment
9. Entropy Phase 3: seasonal, shadows, speculation, trust, desperation
10. Voice pack text pool path fix
11. PhobosLib v1.66.0: decayMultiplicative + resolveQualitativeBand

## Session Log (2026-03-30)

Features shipped:
1. PhobosLib_Radio: `getDeviceData()` instanceof guard (fixes Kahlua crash)
2. PhobosLib_Radio: `instanceof(item, "Radio")` inventory scan guard
3. PhobosLib_Radio: TV types added (TvAntique, TvBlack, TvWideScreen)
4. PhobosLib_Radio: `isTelevision()` public API
5. PhobosLib_Radio: `getReceiverQualityFactor()` with profile lookup + condition scaling
6. POSnet: Receiver quality data-pack (schema + registry + 17 vanilla profiles)
7. POSnet: Client-side WBN degradation (ecology × receiver quality)
8. POSnet: WBN proximity gate via vanilla `HasPlayerInRange()` / `inv:contains()`
9. POSnet: TV exclusion in ConnectionManager + PassiveRecon
10. POSnet: Broadcast influence system merged (Phase A)
11. POSnet: Tutorial expansion merged (+8 milestones → 22 total)
12. POSnet: `PN_CHANNEL_SIGNAL` + `PN_CHANNEL_TUTORIAL` notification channels
13. POSnet: 40 new translation keys (6 receiver quality + 34 tutorial)
14. PhobosLib v1.67.0 tagged + POSnet v0.25.0 tagged

Audit completed:
- Full codebase audit for stubs, dead code, doc gaps
- 104 sandbox options verified wired
- 3 stubs documented (satellite decal, chunk processor, intent pillar)
- 3 missing docs identified (§61, satellite passive design, signal ecology §8)
- 1 dependency gap (PhobosLib min version not in mod.info)
