# POSnet Expansion Roadmap

> Living document. No implementation dates. Updated as features are
> completed or reprioritised. Last audit: 2026-03-28.

---

## Status Overview

| # | Feature | Status | Complexity | Design Ref |
|---|---------|--------|------------|------------|
| 1 | Living Market (7 archetypes) | **DONE** | High | living-market-design.md |
| 2 | Mission Content (18 definitions) | **DONE** | Low | mission-system-design.md |
| 3 | Market Event System (rumours) | **DONE** | High | living-market-design.md |
| 4 | Contract System (spot sell + free agents) | **DONE** | Medium | design-guidelines.md |
| 5 | Camera Workstation Phase 1-2 | **DONE** | Medium | camera-workstation-design.md |
| 6 | Data Recorder Phase 1-2 | **DONE** | Medium | data-recorder-design.md |
| 7 | Signal Strength affects Missions | **DONE** | Low | design-guidelines.md 5.4 |
| 8 | Terminal Screen Consolidation | **DONE** | Medium | design-guidelines.md 33 |
| 9 | Building Target Name Resolution | **DONE** | Trivial | POS_BuildingCache.lua |
| 10 | Market Recon Repeat Visit Discount | **DONE** | Low | POS_MarketReconAction.lua |
| 11 | Cross-Mod Missions (PCP/PIP) | **DONE** | Low | interoperability-matrix.md |
| 12 | Archetype Voice Packs (9/9) | **DONE** | Low | design-guidelines.md 32 |
| 13 | Satellite Uplink (Tier IV) | **DONE** | High | satellite-uplink-design.md |
| 14 | Strategic Relay (Tier V) | **DONE** | High | tier-v-strategic-relay-design.md |
| 15 | Passive Recon System | **DONE** | Medium | passive-recon-design.md |
| 16 | Tutorial & Milestone System | **DONE** | Low | design-guidelines.md 23 |
| 17 | SIGINT Skill (10 levels) | **DONE** | Medium | sigint-skill-design.md |
| 18 | WBN Radio Pipeline | **DONE** | High | world-broadcast-network-design.md |
| 19 | Radio Proximity Filtering | **DONE** | Medium | design-guidelines.md 5.7 |
| 20 | Event-to-Market Price Coupling | **DONE** | Low | design-guidelines.md 55.1 |
| 21 | Fragment-to-MarketDatabase Bridge | **DONE** | Low | design-guidelines.md 55.1 |
| 22 | Item Spawn Expansion + SIGINT Books | **DONE** | Low | POS_Distributions.lua |
| 23 | Entropy System (Fog-of-Market) | Design complete | Very High | entropy-system-design.md |
| 24 | Broadcast Influence System | Design complete | High | broadcast-influence-design.md |
| 25 | Signal Ecology v2 | Partial (stub) | Very High | signal-ecology-design.md |
| 26 | Physical Item Trading (Contacts) | Designed, 0% | Medium | design-guidelines.md 1.3 |
| 27 | Satellite Passive Collection | Design only | High | satellite-passive-collection-design.md |

---

## Completed Features (v0.23.0)

### Core Systems (All Operational)

- **Living Market**: 7 archetypes (Scavenger, Quartermaster, Wholesaler,
  Smuggler, Military Logistician, Speculator, Specialist Crafter), 6
  market zones, zone pressure, supply/demand simulation, price drift
- **Mission System**: 18 definitions across 6 categories + 2 cross-mod.
  Band-gated visibility. Signal-based difficulty cap + briefing garble.
  Negotiation, cancellation penalties, barter system.
- **Contract System**: World-originated contracts, spot selling, free
  agent system (5 archetypes, state machine, signal feed)
- **Passive Recon**: Camcorder, field logger, scanner radio. VHS/
  microcassette/floppy media pipeline.
- **Camera Workstation**: Compile Site Survey, Tape Review, Market
  Bulletin actions. Confidence calculation.
- **Data Recorder**: VHS cassettes, microcassettes, floppy disks. Passive
  scan data routes through equipped recorder.
- **Satellite Uplink (Tier IV)**: Broadcast modes, signal strength
  preview, calibration, fuel drain, wired connection.
- **Strategic Relay (Tier V)**: Discovery, remote calibration, bandwidth
  allocation, operational dashboard.
- **SIGINT Skill**: Custom perk, 10 levels, affects data quality not
  access. 5 skill books with loot distribution.
- **Tutorial System**: 14 milestones, progressive toasts, legacy migration.

### Radio & Broadcast Systems (All Operational)

- **WBN Radio Pipeline**: Harvest -> Editorial -> Composition ->
  Scheduling -> Delivery. 3 channels, 9 voice packs, 415 translation
  keys, signal degradation. Players hear market bulletins on vanilla
  radios.
- **Radio Proximity Filtering**: Intelligence intercepts gated by hearing
  range of powered, unmuted, tuned radio. Vanilla PZ hearing mechanics
  apply. Generic API in PhobosLib (`findNearbyTunedRadio`).
- **Event-to-Market Coupling**: Zone-level events (theft raids, bulk
  arrivals, convoy delays) directly affect prices via
  `POS_EventService.getEventPressure()` summed into zone pressure.
- **Fragment-to-MarketDatabase Bridge**: Radio-sourced signal fragments
  feed into `POS_MarketDatabase.addRecord()` as broadcast-tier
  observations. Passive radio listening = passive market intelligence.

### Content & Polish (All Complete)

- 18 mission definitions, 9 voice pack definitions, 60+ text pool files
- 66 custom items, 40 icons, 5 SIGINT skill books
- Expanded item spawn locations (v0.23.0)
- Terminal screen consolidation (22 screens)
- Market recon repeat visit discount, building target name resolution

---

## Active Development Queue

### Priority 1: Entropy System (Fog-of-Market)

**Status**: Design complete, implementation not started.
**Complexity**: Very High (estimated 80-120 hours across 3 phases).

The single most impactful remaining feature. Introduces negative
influencers at every layer of the economy so information decays, markets
become uncertain, and the player must actively maintain their
intelligence network.

**Phase 1 -- Foundational Entropy**:
- Per-zone/category fog-of-market state bundle (`certainty`, `freshness`,
  `rumourLoad`, `contradiction`, `trust`, `silenceDays`, `concealment`)
- Certainty decay by silence
- Contradiction damage from disagreeing sources
- Effective pressure formula (raw pressure * certainty * trust * noise)
- Atmospheric state labels on terminal UI

**Phase 2 -- Actor-Based Distortion**:
- Wholesaler concealment affecting intel quality (sandbox-gated, SIGINT-
  detectable)
- Blackout state degrading authoritative signal quality
- Weather modifier integration via Signal Ecology propagation pillar

**Phase 3 -- Downstream Consequences**:
- Seasonal entropy baselines
- Trust erosion from failed broadcast predictions
- Information shadow zones in severe weather
- Speculative overreaction, false scarcity waves

**Design ref**: `entropy-system-design.md`, `design-guidelines.md` 59.

---

### Priority 2: Broadcast Influence System

**Status**: Design complete, implementation not started.
**Complexity**: High (estimated 50-80 hours).
**Blocked by**: WBN pipeline (now operational), Entropy Phase 1 (for
trust/influence attenuation).

Makes Tier IV satellite broadcasts actually affect markets and agent
behaviour. Without this, broadcasting feels cosmetic.

**Key features**:
- Five broadcast classes (Scarcity Alert, Surplus Notice, Route Warning,
  Contact Bulletin, Strategic Rumour)
- Regional trust scores affect broadcast effectiveness
- Wholesaler posture nudging from broadcasts
- Rumour echo generation
- Broadcast consequences (saturation, misinformation penalties)

**Design ref**: `broadcast-influence-design.md`.

---

### Priority 3: Signal Ecology v2

**Status**: Design complete, SIGNAL_INTENT_STUB placeholder in code.
**Complexity**: Very High (estimated 80-120 hours for full migration).

Replace flat signal-strength percentage with five-pillar composite model:
Propagation (weather/terrain), Infrastructure (power/hardware), Clarity
(noise/encoding), Saturation (agents/market), Intent (bandwidth/priority).
Qualitative signal states (Locked, Clear, Faded, Fragmented, Ghosted,
Lost) replace raw percentages.

**Note**: The Entropy System's weather integration (Phase 2) provides a
natural on-ramp. Phase 1 of Signal Ecology (wire Intent pillar to free
agent risk + satellite range) can proceed independently.

**Design ref**: `signal-ecology-design.md`, `design-guidelines.md` 56.

---

## Future (Long-Term)

### Physical Item Trading (Contacts)

**Status**: Designed (design-guidelines.md 1.3), sandbox-gated, 0% impl.

Player visits contact in-world, right-click context menu, trades
directly rather than via terminal. Medium complexity.

### Satellite Passive Collection

**Status**: Design document only.

Satellite dish as always-on intelligence appliance. Three states: Idle,
Passive Collection, Deep Sweep. Generates raw signal logs and traffic
fragments requiring terminal processing.

**Design ref**: `satellite-passive-collection-design.md`.

---

## Dependencies Graph

```
Entropy Phase 1 (fog-of-market)
    |
    +---> Entropy Phase 2 (weather + concealment)
    |         |
    |         +---> Signal Ecology v2 (weather pillar shared)
    |
    +---> Broadcast Influence (trust attenuation)
              |
              +---> Entropy Phase 3 (downstream consequences)
```

---

## Session Log (2026-03-28)

Features shipped this session:
1. Expanded item spawns + SIGINT skill book distribution
2. Radio proximity filtering for intercepts (PhobosLib v1.65.0)
3. WBN radio pipeline wired (3 integration bugs fixed)
4. Event-to-market price coupling (getEventPressure wired)
5. Fragment-to-MarketDatabase bridge (radio listening = market intel)
6. Entropy system design document codified
7. WBN magic number extraction (8 constants)
