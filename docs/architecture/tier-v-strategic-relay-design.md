# POSnet Tier V -- Strategic Relay / Regional Command Node

## Executive Summary

Tier V is the apex of the POSnet intelligence hierarchy. Where Tier IV
**broadcasts** compiled intelligence outward, Tier V **coordinates the
network itself** and performs higher-order transmission functions.

Tier V is not "a better satellite dish." It is the first true POSnet
**command installation** -- a permanent, power-hungry, strategic relay
that transforms the player from an intelligence gatherer into a
**network operator**.

Tier V is embodied by rare, permanent infrastructure installations --
large fixed satellite dishes found at civic buildings like fire
stations, military outposts, and communications facilities. These
cannot be moved, crafted, or replicated. They must be discovered,
claimed, and maintained.

**Core Identity**:
- Tier IV speaks loudly.
- **Tier V listens, judges, routes, and commands.**

**Design Reference**: design-guidelines.md section 50.

---

## 1. What a Strategic Relay Is

A Strategic Relay is a **site-class world entity with facility state**,
not merely a detected dish sprite. It represents permanent
communications infrastructure that pre-dates the apocalypse --
emergency coordination nodes, military relay stations, broadcast towers.

The fire station dish is the canonical example: civic infrastructure,
rooftop communications hardware, emergency routing, regional
responsibility, logistical coordination, backup power plausibility.

**Player Fantasy**:
> "This was once an emergency coordination point. I have reclaimed it
> as a post-collapse intelligence citadel."

### 1.1 Distinction from Tier IV

| Attribute      | Tier IV (Uplink)         | Tier V (Strategic Relay)    |
|----------------|--------------------------|-----------------------------|
| Role           | Broadcast                | Control                     |
| Scope          | Regional                 | Network-wide                |
| Output         | Narrative                | Intent                      |
| Interaction    | One-to-many              | Many-to-many                |
| Player Feel    | "I speak"                | "I orchestrate"             |
| Hardware       | Portable/placeable dish  | Permanent fixed installation|
| Rarity         | Craftable / findable     | World-placed only           |

**Hard Rule**: If Tier IV starts doing routing, filtering, or
coordination, it has become Tier V. Keep the boundary clean.

---

## 2. Why It Must Exist

### 2.1 Current Gap

The four-tier hierarchy (Capture -> Analysis -> Compilation -> Broadcast)
has a ceiling: once the player broadcasts from a Tier IV dish, they have
reached maximum capability. There is no "what comes next" beyond "do it
again with better artifacts."

### 2.2 What Tier V Solves

Tier V transforms the endgame from repetitive broadcasting into
**network operations**:

- Multi-source intelligence fusion
- Relay-assisted sending for lower tiers
- Long-range tasking and acknowledgement traffic
- Agent telemetry backhaul with richer observability
- Strategic market shaping (indirect, not direct)
- Contested signal battles (MP future)

### 2.3 Design Principles

1. **Crown, not replacement** -- Tier V depends on all lower tiers for
   raw truth. It is hungry: it needs field captures, recorder media,
   terminal analysis, camera compilations, and agent reports.
2. **New verbs, not bigger numbers** -- Tier V unlocks qualitatively
   different actions, not just +20% stat bonuses.
3. **Active, not passive** -- meaningful outputs come from player intent
   (queue a relay, authorize a dispatch, start a scan window, allocate
   bandwidth).
4. **Augment, never gate** -- lower tiers remain independently valuable.

---

## 3. Facility State Model

A Strategic Relay is modelled as a persistent world entity, not a
simple detected sprite.

### 3.1 Site Record Schema

```lua
StrategicRelaySite = {
    siteId           = "string",     -- unique persistent ID
    spriteKey        = "string",     -- world sprite identifier
    location         = {x, y, z},    -- world coordinates
    calibrationState = 0.0,          -- 0.0 to 1.0 (drifts over time)
    powerBudget      = 0.0,          -- current power availability
    networkHealth    = 0.0,          -- 0.0 to 1.0
    linkedTerminals  = {},           -- array of terminal IDs
    transmissionQueue = {},          -- outbound packet queue
    interceptHistory  = {},          -- recent intercept log
    knownPeers       = {},           -- discovered relay/terminal nodes
    trustScore       = 0.0,          -- station broadcast credibility
    componentWear    = 0.0,          -- degradation (0.0 = pristine)
    activeBandwidth  = "balanced",   -- bandwidth allocation mode
    lastMaintenanceDay = 0,
    discoveredDay    = 0,
    isOperational    = false,        -- requires calibration + power
}
```

### 3.2 Ongoing Burdens

Strategic Relays are expensive to maintain:

- **High power draw** -- significantly more than Tier IV
- **Component degradation** -- wear from continuous operation
- **Calibration drift** -- requires periodic recalibration
- **Fuel dependency** -- post-grid requires generators
- **Signature risk** -- active relay is detectable (MP/future hostile)
- **Possible hostile attention** -- future system hook

---

## 4. Core Tier V Functions

### 4.1 Regional Uplink

Stronger, broader satellite broadcast capability. Where Tier IV reaches
a region, Tier V can push to multiple zones simultaneously.

### 4.2 Relay Queue (Store-and-Forward)

Outgoing reports from lower-tier sources can be queued through the
relay for enhanced delivery. A Tier II terminal analysis result
forwarded through Tier V gains:
- Extended reach
- Higher confidence weighting by recipients
- Relay authentication stamp

### 4.3 Agent Backhaul

Improved free-agent telemetry and recall. With Tier V active:
- Better telemetry frequency (more status updates per tick)
- Improved recall odds in covered zones
- Lower signal penalty on agent risk calculations
- Long-distance agent deployment unlocked
- Agent handoff between zones (future)
- Emergency extraction calls

### 4.4 Signal Fusion

Combine passive recon, terminal analysis, and broadcasts into
higher-confidence summaries. Cross-correlation bonuses, multi-zone
synthesis, predictive hints, anomaly detection.

### 4.5 Intercept Sweep

Deliberate timed action to hunt rare strategic traffic. Power-hungry,
time-limited, high reward. May surface:
- Competing faction broadcasts
- Distress signals
- Military traffic fragments
- Market manipulation attempts

### 4.6 Priority Routing (Bandwidth Allocation)

The player chooses how to allocate the relay's limited bandwidth:

| Mode          | Focus                          | Benefit                        |
|---------------|--------------------------------|--------------------------------|
| `markets`     | Market intelligence priority   | Better price data, faster propagation |
| `agents`      | Agent telemetry priority       | Richer updates, better recall  |
| `operations`  | Mission/contract priority      | Faster contract generation, better briefings |
| `intercepts`  | Military/tactical priority     | Intercept sweep bonuses        |
| `balanced`    | Even distribution              | Modest bonus to all            |

---

## 5. Strategic Outputs

When operated actively, Tier V produces:

- **Regional advisories** -- multi-zone intelligence summaries
- **Market stabilisation/distortion campaigns** -- sustained perceived
  pressure shifts (not instant rewrites)
- **Emergency supply directives** -- contract generation influence
- **Agent reroute packages** -- redirect active agents
- **Counter-rumour broadcasts** -- suppress misinformation
- **Contact awakening events** -- make hidden wholesalers more visible
- **Rare mission triggers** -- unique missions tied to major
  transmissions

---

## 6. Tier V Sending: Network Intent

In the five-tier sending taxonomy, Tier V transmits **network control
traffic**:

| Transmission Type       | Description                          |
|-------------------------|--------------------------------------|
| Relay directives        | Route traffic through specific nodes |
| Agent dispatch envelopes| Deploy/redirect agents at range      |
| Authentication handshakes| Verify node identity                |
| Synchronisation packets | Align data across terminals          |
| Market coordination orders| Multi-zone perceived pressure shifts|
| Threat advisories       | Network-wide danger alerts           |
| Signal priority overrides| Change bandwidth allocation remotely |
| Inter-terminal routing  | Forward intelligence between terminals|

---

## 7. System Interactions

### 7.1 With Terminal Analysis

Tier V enhances terminal analysis capabilities:
- Cross-correlation bonuses (multi-source fusion)
- Better confidence uplift from relay-authenticated data
- Multi-zone synthesis (combine intel from different regions)
- Predictive hints (early warning from traffic pattern analysis)
- Anomaly detection flags
- "Incomplete but urgent" priority flags

### 7.2 With Free Agent System

This is the most impactful connection. Per the free-agent design
document, observability is core and signal infrastructure should
mechanically matter.

**Agent telemetry improvements**:
- `agent.telemetryQuality` boosted in relay-covered zones
- More granular `agent.lastKnownState` updates
- `agent.contactConfidence` improves with relay backhaul
- Stateful feed drama: "Agent entered negotiation window",
  "Courier rerouted around instability", "Signal intermittent,
  cargo status uncertain"

**Recall assistance**:
- Recall chance bonus in linked zones
- Reduced delay before response
- Partial cargo recovery odds improve
- Compromised agents gain a slim chance to re-establish contact

### 7.3 With Living Market

Tier V does not merely "change prices more." It affects:
- **Propagation speed** of intelligence through the market
- **Breadth of affected zones** (multi-zone influence)
- **Persistence of narrative** (slower confidence decay)
- **Confidence weighting** in market interpretation
- **Wholesaler behavioural shifts** (stronger posture nudges)
- **Timing of soft-to-hard signal conversion**

The strategic relay becomes the place where **regional market
coherence** is forged. Not infinite control. Not magic omniscience.
But a serious lever.

### 7.4 With Side Panels

**Left panel -- live signal / network feed**:
- Inbound telemetry bursts
- Agent last-contact updates
- Relay health indicators
- Regional advisories
- Unusual traffic alerts
- Intercept opportunities
- Transmission backlog

**Right panel -- command / context panel**:
- Linked terminals list
- Active dish state
- Power/fuel burden
- Route quality metrics
- Queued outgoing packets
- Selected zone pressure
- Selected agent uplink status

---

## 8. Sprite Detection

### 8.1 Target Sprites

Permanent large satellite dishes found on specific building types.
Must be identified via sprite name patterns (similar to Tier IV
detection but filtered to permanent/large installations only).

Candidate locations:
- Fire stations (rooftop dishes)
- Military installations
- Communications buildings
- Emergency services facilities

### 8.2 Detection Criteria

A Tier V site must be distinguished from ordinary Tier IV dishes:
- Sprite must be in the permanent/large dish family
- Must be attached to a qualifying building type
- Cannot be player-placed or moved
- One site per building (no stacking)

---

## 9. Power Requirements

Significantly higher than Tier IV:

| State              | Power Draw           |
|--------------------|----------------------|
| Idle               | Low baseline         |
| Passive monitoring | Moderate             |
| Active relay       | High                 |
| Intercept sweep    | Very high            |
| Full network ops   | Maximum              |

Post-grid operation requires dedicated generator capacity.

---

## 10. Calibration

### 10.1 Initial Calibration

First-use setup requires:
- Electrical skill (higher than Tier IV requirement)
- Calibration tools
- Extended timed action
- Power must be stable during calibration

### 10.2 Calibration Drift

Strategic Relays experience calibration drift over time:
- Quality degrades slowly each day
- Weather events accelerate drift
- Periodic recalibration required
- Drift affects all relay functions proportionally

---

## 11. Sandbox Options

| Option                    | Type    | Default | Description                          |
|---------------------------|---------|---------|--------------------------------------|
| TierVEnabled              | boolean | true    | Enable/disable Tier V installations  |
| TierVPowerMultiplier      | float   | 1.0     | Scale power requirements             |
| TierVCalibrationDrift     | float   | 1.0     | Scale calibration drift rate         |
| TierVAgentBonus           | float   | 1.0     | Scale agent telemetry improvements   |
| TierVInterceptChance      | float   | 1.0     | Scale intercept sweep success        |

---

## 12. Constants

```lua
-- Tier V Strategic Relay
POS_Constants.TIER_V_CALIBRATION_DRIFT_PER_DAY   = 0.02
POS_Constants.TIER_V_POWER_DRAW_IDLE             = 0.05
POS_Constants.TIER_V_POWER_DRAW_ACTIVE           = 0.25
POS_Constants.TIER_V_POWER_DRAW_SWEEP            = 0.50
POS_Constants.TIER_V_TELEMETRY_BONUS             = 0.20
POS_Constants.TIER_V_RECALL_BONUS                = 0.15
POS_Constants.TIER_V_INTERCEPT_BASE_CHANCE       = 0.10
POS_Constants.TIER_V_MAX_QUEUED_PACKETS          = 10
POS_Constants.TIER_V_RELAY_CONFIDENCE_BONUS      = 0.10
POS_Constants.TIER_V_BANDWIDTH_MODES = {
    "balanced", "markets", "agents", "operations", "intercepts"
}
```

---

## 13. Module Architecture

### 13.1 New Modules

| Module                          | Side   | Purpose                           |
|---------------------------------|--------|-----------------------------------|
| `POS_StrategicRelayService.lua` | shared | Core facility state + tick logic  |
| `POS_RelayDetection.lua`        | shared | Sprite detection for Tier V sites |
| `POS_InterceptService.lua`      | shared | Intercept sweep logic             |
| `POS_RelayContextMenu.lua`      | client | Right-click actions on relay sites|
| `POS_Screen_RelayCommand.lua`   | client | Terminal screen for relay ops     |

### 13.2 Modified Modules

| Module                          | Change                              |
|---------------------------------|-------------------------------------|
| `POS_FreeAgentService.lua`      | Telemetry + recall bonuses from relay|
| `POS_MarketSimulation.lua`      | Relay-enhanced propagation          |
| `POS_ConnectionManager.lua`     | Tier V signal integration           |
| `POS_Constants.lua`             | Tier V constants                    |

---

## 14. Implementation Phases

### Phase 1 -- Core Detection & State (MVP)
- Sprite detection for permanent dishes
- Site record creation and persistence
- Initial calibration action
- Power integration
- Basic relay status display

### Phase 2 -- Agent Integration
- Telemetry quality bonus from active relay
- Recall chance improvements
- Agent backhaul status in Field Agents screen

### Phase 3 -- Market Integration
- Relay-enhanced market propagation
- Multi-zone broadcast from relay
- Regional advisory generation

### Phase 4 -- Intercept & Network Ops
- Intercept sweep action
- Bandwidth allocation system
- Priority routing
- Relay queue (store-and-forward)

### Phase 5 -- Polish
- Side panel integration
- Signal fusion UI
- Calibration drift visuals
- Component wear and maintenance

---

## 15. Anti-Patterns -- What Tier V Must Never Become

1. **Not a stat stick** -- if it only provides flat percentage bonuses
   (+20% signal, +10% rep), it is dead. It needs new verbs.
2. **Not passive by default** -- meaningful outputs require player
   intent: queue a relay, authorize a dispatch, start a scan window,
   allocate bandwidth.
3. **Not a replacement for lower tiers** -- Tier V is hungry. It
   depends on field capture, recorder media, terminal analysis, camera
   compilation, and agent reports. The command node is a crown, not a
   replacement for the kingdom beneath it.
4. **Not omniscient** -- Tier V improves the signal, it does not
   eliminate uncertainty. Weather, saturation, and infrastructure
   integrity still degrade performance.

---

## 16. Relationship to Other Design Documents

| Document                        | Relationship                              |
|---------------------------------|-------------------------------------------|
| `satellite-uplink-design.md`    | Tier IV broadcast; Tier V extends, not replaces |
| `free-agent-system.md`          | Agent telemetry + recall integration      |
| `living-market-design.md`       | Multi-zone market propagation             |
| `signal-ecology-design.md`      | Signal pillars affect Tier V performance  |
| `terminal-analysis-design.md`   | Tier V enhances terminal cross-correlation|
| `interoperability-matrix.md`    | New data flows for relay subsystem        |
| `design-guidelines.md`          | section 20 (Five-Tier Hierarchy), section 50 (Signal Ecology) |

---

## 17. Risk Assessment

| Risk                                    | Likelihood | Impact | Mitigation                     |
|-----------------------------------------|------------|--------|--------------------------------|
| Tier V feels too similar to Tier IV     | Medium     | High   | Enforce verb distinction       |
| Performance impact from relay tick      | Low        | Medium | Aggregate-first persistence    |
| Scope creep into MP territory           | Medium     | Low    | Defer contested signals        |
| Tier V trivialises lower tiers          | Low        | High   | Dependency design (hungry crown)|

---

## 18. Success Criteria

1. Player discovers a fire station dish and feels genuine excitement
2. Tier V unlocks actions that feel qualitatively different from Tier IV
3. Agent telemetry visibly improves when relay is active
4. Market influence is indirect and perception-based, not direct price control
5. Maintaining the relay feels like running a facility, not clicking a button
6. Lower tiers remain essential and independently rewarding
7. Bandwidth allocation creates meaningful strategic decisions
