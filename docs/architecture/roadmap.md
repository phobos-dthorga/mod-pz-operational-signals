# POSnet Expansion Roadmap

> Living document. No implementation dates. Updated as features are
> completed or reprioritised. Last audit: 2026-03-29.

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
| 7 | Signal Strength affects Missions | **DONE** | design-guidelines.md 5.4 |
| 8 | Terminal Screen Consolidation | **DONE** | design-guidelines.md 33 |
| 9 | Building Target Name Resolution | **DONE** | POS_BuildingCache.lua |
| 10 | Market Recon Repeat Visit Discount | **DONE** | POS_MarketReconAction.lua |
| 11 | Cross-Mod Missions (PCP/PIP) | **DONE** | interoperability-matrix.md |
| 12 | Archetype Voice Packs (9/9) | **DONE** | design-guidelines.md 32 |
| 13 | Satellite Uplink (Tier IV) | **DONE** | satellite-uplink-design.md |
| 14 | Strategic Relay (Tier V) | **DONE** | tier-v-strategic-relay-design.md |
| 15 | Passive Recon System | **DONE** | passive-recon-design.md |
| 16 | Tutorial & Milestone System | **DONE** | design-guidelines.md 23 |
| 17 | SIGINT Skill (10 levels) | **DONE** | sigint-skill-design.md |
| 18 | WBN Radio Pipeline | **DONE** | world-broadcast-network-design.md |
| 19 | Radio Proximity Filtering | **DONE** | design-guidelines.md 5.7 |
| 20 | Event-to-Market Price Coupling | **DONE** | design-guidelines.md 55.1 |
| 21 | Fragment-to-MarketDatabase Bridge | **DONE** | design-guidelines.md 55.1 |
| 22 | Item Spawn Expansion + SIGINT Books | **DONE** | POS_Distributions.lua |
| 23 | Entropy System (all 3 phases) | **DONE** | entropy-system-design.md |
| 24 | Broadcast Influence System | Design complete | broadcast-influence-design.md |
| 25 | Signal Ecology v2 | Partial (stub) | signal-ecology-design.md |
| 26 | Physical Item Trading (Contacts) | Designed, 0% | design-guidelines.md 1.3 |
| 27 | Satellite Passive Collection | Design only | satellite-passive-collection-design.md |

---

## Completed Features

### Core Systems (All Operational)

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
- **Tutorial System**: 14 milestones, progressive toasts.

### Radio & Broadcast Systems (All Operational)

- **WBN Radio Pipeline**: Harvest → Editorial → Composition → Scheduling
  → Delivery. 3 channels, 9 voice packs, 415+ translation keys, signal
  degradation, voice pack text pool resolution.
- **Radio Proximity Filtering**: Intercepts gated by hearing range.
  Generic API in PhobosLib (`findNearbyTunedRadio`).
- **Event-to-Market Coupling**: Zone events affect prices directly.
- **Fragment-to-MarketDatabase Bridge**: Radio = passive market intel.

### Entropy System (All 3 Phases Complete)

**Phase 1 — Foundational Fog-of-Market**:
- Per-zone/category `intelState` bundle (certainty, freshness,
  rumourLoad, contradiction, trust, silenceDays, concealment, shadowState)
- Certainty decay by silence, contradiction damage, observation recovery
- Effective pressure formula in PriceEngine
- Atmospheric state labels on terminal UI
- 4 notification events (cold, contradiction, transition, recovery)

**Phase 2 — Actor-Based Distortion**:
- Weather accelerates decay via Signal Ecology propagation pillar
- Blackout degrades certainty + boosts rumours
- Wholesaler concealment (sandbox-gated, default OFF, SIGINT-detectable)

**Phase 3 — Downstream Consequences**:
- Seasonal baseline modifiers (schema-driven via SignalModifierSchema)
- Information shadow zones (severe weather + blackout combo)
- Speculative rumours (schema-driven data-pack, certainty-triggered)
- Trust erosion from failed broadcast predictions
- Desperation index amplifying contradiction/speculation/rumour swings

**Design refs**: `entropy-system-design.md`, `design-guidelines.md` §59

---

## Active Development Queue

### Priority 1: Broadcast Influence System

**Status**: Design complete, implementation not started.
**Complexity**: High (estimated 50-80 hours).

Makes Tier IV satellite broadcasts actually affect markets and agent
behaviour. Now unblocked by the entropy system (trust attenuation ready).

**Key features**:
- Five broadcast classes (Scarcity Alert, Surplus Notice, Route Warning,
  Contact Bulletin, Strategic Rumour)
- Regional trust scores affect broadcast effectiveness
- Wholesaler posture nudging from broadcasts
- Rumour echo generation
- Broadcast consequences (saturation, misinformation penalties)

**Design ref**: `broadcast-influence-design.md`.

---

### Priority 2: Signal Ecology v2

**Status**: Design complete, SIGNAL_INTENT_STUB placeholder in code.
**Complexity**: Very High (estimated 80-120 hours for full migration).

Replace flat signal-strength percentage with five-pillar composite model.
The entropy system's weather and seasonal integration (Phase 2-3) shares
the Signal Ecology propagation pillar, providing a natural on-ramp.

**Design ref**: `signal-ecology-design.md`, `design-guidelines.md` 56.

---

## Future (Long-Term)

### Physical Item Trading (Contacts)

**Status**: Designed (design-guidelines.md 1.3), sandbox-gated, 0% impl.

### Satellite Passive Collection

**Status**: Design document only.

**Design ref**: `satellite-passive-collection-design.md`.

---

## Dependencies Graph

```
Entropy System (COMPLETE — all 3 phases)
    |
    +---> Broadcast Influence (trust attenuation ready)
    |
    +---> Signal Ecology v2 (propagation pillar shared)
```

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
