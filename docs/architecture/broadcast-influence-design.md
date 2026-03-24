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

# POSnet Broadcast Influence System -- Design Document

**Branch**: `dev/broadcast-influence` (future)
**Date**: 2026-03-25
**Status**: Design phase -- implementation not started
**Prerequisites**: Satellite Uplink operational (see `satellite-uplink-design.md`),
Living Market active (see `living-market-design.md`), Free Agent System
registered (see `free-agent-system.md`)

> **Design reference**: `design-guidelines.md` section 52
> **Cross-references**: `satellite-uplink-design.md`, `tier-v-strategic-relay-design.md`,
> `signal-ecology-design.md`, `free-agent-system.md`, `living-market-design.md`,
> `interoperability-matrix.md`

---

## 1. What It Is

The Broadcast Influence System is the **translation layer** between Tier IV
satellite broadcasts and the downstream systems that react to them -- markets,
wholesalers, agents, rumours, and regional trust. It does not control those
systems. It alters the informational climate in which they make decisions.

**Core doctrine**:

> Tier IV should not control markets or agents directly; it should alter
> the informational climate in which both make decisions.

A broadcast is not a command. It is a pressure wave that moves through the
post-collapse information economy. Markets feel it as perceived scarcity or
surplus. Wholesalers feel it as a nudge toward caution or opportunism. Agents
feel it as a shift in what targets look attractive and what routes feel
dangerous. Rumours amplify, distort, and decay what the broadcast originally
said. Trust determines how much any of it sticks.

The player does not press a button that says "raise ammo prices." The player
broadcasts a scarcity alert, and the world -- imperfectly, noisily, with delay
and distortion -- reacts.

---

## 2. The Full Loop

Intelligence flows through a complete cycle from creation to world reaction.
Each step introduces noise, delay, or distortion -- nothing is instantaneous,
nothing is clean.

### 2.1 Step-by-Step Outline

1. **Intelligence Created** -- Field operatives produce raw data: passive
   recon observations, VHS tape reviews, terminal analyses, agent field
   reports. This is Tier I/II material.

2. **Compilation & Uplift** -- The Camera Workstation (Tier III) compiles raw
   intel into structured artifacts. The Satellite Uplink (Tier IV) selects
   a compiled artifact and a broadcast class.

3. **Broadcast Transmitted** -- The satellite dish transmits the broadcast
   with a specific type, strength, confidence, and target zone. This
   consumes power, calibration, and cooldown time.

4. **Influence Layer Processes** -- The Broadcast Influence System converts
   the broadcast into two output records:
   - A **market_signal** record (consumed by the Living Market)
   - An **agent_advisory** record (consumed by the Free Agent System)

5. **Market Reacts** -- The Living Market's economy tick reads active
   market_signal records. Perceived pressure shifts. Wholesalers adjust
   posture. Prices drift. Rumours spawn.

6. **Agents React** -- The Free Agent Service's agent tick reads active
   agent_advisory records. Target desirability shifts. Route risk
   recalculates. Telemetry quality improves. Recall windows open.

7. **World Responds** -- NPC wholesalers, market zones, and rumour channels
   produce observable consequences. The player sees ripple effects through
   the terminal.

8. **Confidence Decays** -- All broadcast-derived effects carry a freshness
   value that decays each economy tick. Stale signals lose influence.
   Expired signals are pruned.

9. **Trust Mutates** -- If reality matches the broadcast (prices did rise,
   routes were dangerous), regional trust in the broadcast station
   increases. If reality contradicts, trust erodes. Trust feeds back into
   step 4, weighting future broadcasts.

```
  INTELLIGENCE          BROADCAST           INFLUENCE           WORLD
  ───────────           ─────────           ─────────           ─────
  recon notes  ──┐
  VHS tapes    ──┤                      ┌─ market_signal ──→ zone pressure
  agent reports──┼→ Tier IV uplink ──→ │                      wholesaler posture
  terminal     ──┘   (broadcast)        │                      rumour echoes
                                        └─ agent_advisory ──→ target desirability
                                                               route risk
                                                               telemetry quality
                                              ↑
                                         trust score ←── reality vs prediction
```

---

## 3. Market Integration

### 3.1 Information Shock

Broadcasts create **perceived pressure**, not real inventory changes. The
satellite dish does not teleport goods or destroy stockpiles. It changes
what the market *believes* about supply and demand.

**Formula**:

```lua
zone.perceivedPressure[categoryId] += strength * confidence
```

Where:
- `strength` is the broadcast's signal strength (0.0--1.0)
- `confidence` is the broadcast's derived confidence (0.0--1.0)
- The result modifies perceived pressure, which the price engine already
  reads when computing zone-level price adjustments

Perceived pressure decays each economy tick by a configurable rate
(default: 15% per day). It is *additive* with real pressure from actual
supply observations.

### 3.2 Wholesaler Posture Shift

Broadcasts nudge wholesaler behavioural posture without hard-rewriting
state. Each wholesaler archetype has a characteristic reaction profile.

The six wholesaler postures (from `living-market-design.md`):

| Posture | Meaning |
|---------|---------|
| `accumulate` | Buying up stock, reducing availability |
| `hold` | Sitting on inventory, not selling freely |
| `probe` | Testing market, placing speculative orders |
| `dump` | Offloading inventory quickly, flooding supply |
| `reroute` | Shifting supply to alternative zones |
| `conceal` | Hiding inventory from public markets |

**Per-archetype reaction profiles**:

| Archetype | Scarcity Alert | Surplus Notice | Route Warning | Contact Bulletin | Strategic Rumour |
|-----------|---------------|----------------|---------------|-----------------|-----------------|
| Military | hold +0.25 | hold +0.10 | reroute +0.20 | hold +0.05 | conceal +0.15 |
| Black-market | conceal +0.30 | accumulate +0.20 | conceal +0.15 | probe +0.20 | conceal +0.25 |
| Speculator | probe +0.25 | dump +0.20 | hold +0.10 | probe +0.15 | accumulate +0.20 |
| Civilian | accumulate +0.20 | probe +0.15 | hold +0.20 | -- | accumulate +0.10 |
| Smuggler | reroute +0.20 | probe +0.15 | reroute +0.30 | probe +0.25 | conceal +0.20 |

These are **weighted nudges**, not state overwrites. The wholesaler's existing
posture, local conditions, and personality all contribute. The broadcast
influence is one input among several.

### 3.3 Rumour Generation

Every broadcast emits:
- **1 authoritative signal** -- the market_signal record itself, with the
  broadcast's full confidence and strength
- **0--N rumour echoes** -- distorted, lower-confidence copies that spread
  through the rumour system

Echo count is determined by:

| Factor | Effect on Echo Count |
|--------|---------------------|
| Signal strength | Higher strength = more echoes |
| Confidence | Higher confidence = fewer echoes (clean signal, less distortion) |
| Zone saturation | High saturation = more echoes (information overload amplifies noise) |
| Desperation index | High desperation = more echoes (panicked populations repeat rumours) |
| Blackout status | Active blackout = more echoes (absence of authority breeds speculation) |
| Local volatility | High volatility = more echoes (unstable zones amplify everything) |

**Formula** (indicative):

```lua
local echoCount = math.floor(
    strength * 3.0
    * (1.0 - confidence * 0.5)
    * (1.0 + saturation * 0.4)
    * (1.0 + desperation * 0.3)
    * (blackout and 1.6 or 1.0)
    * (1.0 + volatility * 0.3)
)
```

Each echo inherits the broadcast's category and zone but receives a
degraded confidence (`confidence * randFloat(0.2, 0.6)`) and a randomised
expiry window shorter than the parent signal.

---

## 4. Agent Integration

### 4.1 Broadcast-Derived Tasking Environment

Agents do not receive direct orders from broadcasts. They react to what is
"in the air" -- the ambient informational climate that broadcasts create.

Major broadcasts alter:
- **Target desirability** -- A scarcity alert in west_point makes that zone
  more attractive for scavengers and brokers, less attractive for cautious
  couriers
- **Route risk** -- A route warning raises perceived danger along affected
  corridors, causing agents to favour alternative paths or accept higher
  delay
- **Destination congestion** -- A surplus notice increases expected
  competition at the target zone, reducing expected yield for late arrivals
- **Opportunistic side events** -- Contact bulletins can trigger chance
  encounters (new trader contact, barter opportunity) during agent travel

### 4.2 Telemetry Richness

Tier IV infrastructure improves the quality and cadence of agent status
updates -- not just risk reduction. The satellite uplink provides a
communication backbone that agents can use for richer reporting.

Key fields:

```lua
agent.telemetryQuality   = 0.72  -- 0.0 to 1.0 (higher = more detail)
agent.lastKnownState     = "en_route"
agent.lastContactDay     = 22
agent.contactConfidence  = 0.85  -- how certain we are of lastKnownState
```

Without Tier IV: telemetry updates are infrequent, low-detail, and may
arrive late or not at all. The player sees "last seen: 3 days ago, status:
unknown."

With Tier IV: telemetry updates are more frequent, include richer context
(current zone, cargo status, encountered threats), and arrive with higher
confidence. The player sees "last contact: today, status: en route via
rosewood, cargo intact, minor threat encountered."

### 4.3 Recall Assistance

Broadcast infrastructure materially improves recall success without
guaranteeing it. The satellite dish is not a command-and-control system --
it is a better radio.

- **Without Tier IV**: recall attempts rely on local radio. Success depends
  on signal quality, agent distance, and agent state. Chance of contact
  may be as low as 20--40%.
- **With Tier IV**: recall attempts benefit from a broadcast recall window.
  The satellite dish can push a wideband recall signal that agents are
  more likely to receive. Success chance rises by +15--25% (additive).
- **Not guaranteed**: agents in blackout zones, heavily damaged areas, or
  "gone dark" states may still be unreachable. The broadcast improves
  the odds, not the certainty.

### 4.4 Agent Behavioural Modulation

Each agent archetype responds differently to broadcast classes. These
response profiles modulate agent decision-making at the margin -- they do
not override the agent's core behaviour or current mission parameters.

```lua
BroadcastResponse = {
    scavenger = {
        scarcity_alert  = { riskBias = +0.10, zoneInterest = +0.25 },
        hazard_alert    = { riskBias = -0.15 },
        surplus_notice  = { zoneInterest = +0.10, routeVariance = +0.05 },
    },
    courier = {
        hazard_alert    = { routeCaution = +0.30 },
        surplus_notice  = { deliveryPriority = +0.10 },
        route_warning   = { routeCaution = +0.25, recallDelay = +0.10 },
    },
    broker = {
        scarcity_alert  = { tradeUrgency = +0.25 },
        surplus_notice  = { accumulationChance = +0.15 },
        contact_bulletin = { contactInterest = +0.20 },
    },
    smuggler = {
        military_alert  = { stealthBias = +0.30, directRouteChance = -0.20 },
        route_warning   = { stealthBias = +0.20, reroute = +0.15 },
        scarcity_alert  = { riskBias = +0.15, zoneInterest = +0.20 },
    },
}
```

These values are indicative design targets. Final tuning will occur during
playtesting. The important structural point is that responses are
**per-archetype, per-broadcast-class, and always marginal** -- never binary.

---

## 5. Trust System

### 5.1 Regional Trust Scores

Each market region maintains a trust score representing local confidence in
the player's broadcast station. Trust is a float in the range [0.0, 1.0].

**Initial values** (indicative):

| Region | Initial Trust | Rationale |
|--------|--------------|-----------|
| Muldraugh | 0.61 | Player's likely home base, moderate starting credibility |
| Rosewood | 0.48 | Smaller community, cautious, wants proof |
| West Point | 0.52 | Larger population, more exposure to information |
| Riverside | 0.44 | Remote, self-reliant, sceptical of outside broadcasts |
| March Ridge | 0.38 | Isolated, minimal prior contact |
| Military Corridor | 0.55 | Structured hierarchy, respects signals intelligence |

Trust is stored per-region in the broadcast persistence layer
(`POSNET.Broadcasts.trustByRegion`).

### 5.2 Trust Mutation Rules

Trust changes based on the accuracy and behaviour of the broadcast station
over time.

**Trust increases when**:
- A broadcast's prediction is confirmed by subsequent observations
  (e.g., scarcity alert followed by observed price rise)
- Follow-up broadcasts correct or refine earlier signals
- Broadcast confidence level matches actual certainty (not inflated)
- Broadcast frequency is measured and proportional to real events

**Trust decreases when**:
- A broadcast's prediction is contradicted by reality (surplus alert
  followed by actual scarcity)
- High-confidence broadcasts turn out to be wrong (trust penalty scales
  with confidence used)
- The station floods the airwaves with sensational alerts that do not
  materialise
- Strategic rumours are detected as intentional misinformation (severe
  penalty if the region discovers the manipulation)

**Mutation formula** (per broadcast resolution):

```lua
local accuracy = measureAccuracy(broadcast, observations)
local trustDelta = (accuracy - 0.5) * 0.08 * broadcast.confidence
region.trust = POS_Utils.clamp(region.trust + trustDelta, 0.0, 1.0)
```

### 5.3 Trust Effects

Trust directly modulates how strongly broadcast-derived effects land in
each region.

| Trust Level | Market Impact | Rumour Behaviour | Agent Response |
|-------------|--------------|------------------|----------------|
| High (0.7+) | Clean, strong pressure shift; wholesalers react promptly | Fewer echoes, higher-fidelity rumours | Agents treat advisories as reliable, adjust behaviour quickly |
| Medium (0.4--0.7) | Moderate pressure shift; some wholesaler scepticism | Normal echo count, moderate distortion | Agents weigh advisories against personal experience |
| Low (< 0.4) | Weak pressure shift; wholesalers largely ignore | Many echoes, heavy distortion, contradictory rumours | Agents discount advisories, rely on own telemetry |

Low trust does not silence broadcasts. It makes them *noisy*. The
information still enters the system, but arrives wrapped in more rumours,
more distortion, and more scepticism. This is by design -- a distrusted
broadcast station is not useless, it is *chaotic*.

---

## 6. Data Structures

All structures follow the canonical payload shapes defined in
`interoperability-matrix.md`. The following are the broadcast influence
layer's primary records.

### 6.1 Broadcast Record

```lua
{
    id            = "bc_1042",
    type          = "scarcity_alert",     -- scarcity_alert | surplus_notice | route_warning | contact_bulletin | strategic_rumour
    origin        = "satellite_tier4",    -- broadcast source
    zoneId        = "west_point",
    categoryId    = "ammo",
    confidence    = 0.81,                 -- derived from artifact quality
    strength      = 0.46,                 -- 0.0 to 1.0
    freshness     = 0.90,                 -- decays over time
    trustWeight   = 0.67,                 -- station broadcast credibility
    issuedDay     = 22,
    expiresDay    = 25,
}
```

### 6.2 Market Effect Projection

```lua
{
    zoneId               = "west_point",
    categoryId           = "ammo",
    perceivedPressureMod = 0.22,          -- shifts perceived, not real pressure
    rumourChanceMod      = 0.18,
    wholesalerBias       = {
        accumulate = 0.14,
        conceal    = 0.09,
    },
}
```

### 6.3 Agent Advisory

```lua
{
    id              = "adv_991",
    zoneId          = "west_point",
    advisoryType    = "scarcity_alert",
    severity        = 0.46,
    confidence      = 0.81,
    telemetryBonus  = 0.10,
    recallBonus     = 0.06,
    routeRiskMod    = 0.12,
    expiresDay      = 25,
}
```

---

## 7. Five Initial Broadcast Classes

### 7.1 Scarcity Alert

**Trigger**: Stock observed low, failed deliveries recorded, hazard
blocking supply lines, terminal analysis confirms shortage.

**Market effects**:
- Perceived pressure rises in target zone/category
- Wholesaler accumulation bias increases (especially civilian, speculator)
- Broker urgency rises -- brokers attempt to lock in supply before prices
  spike
- Prices drift upward as perceived scarcity propagates
- Rumour echoes multiply -- scarcity is the most echo-prone broadcast class

**Agent effects**:
- Scavenger zone interest rises (scarce goods = higher value finds)
- Broker trade urgency increases
- Smuggler risk tolerance rises (scarcity = premium black-market margins)

**Trust dynamics**: Accurate scarcity alerts build trust rapidly. False
scarcity alerts (prices did not rise, supply was fine) erode trust severely.

### 7.2 Surplus Notice

**Trigger**: Cache discovered, bulk arrival observed, wholesaler dump
detected, terminal analysis confirms oversupply.

**Market effects**:
- Perceived pressure drops in target zone/category
- Wholesaler dump posture rises (especially speculators shedding inventory)
- Trader opportunism increases -- buyers rush to exploit soft prices
- Prices soften as perceived surplus propagates
- Crowding risk increases -- too many actors converging on the same surplus
  creates competition, delays, and potential conflict

**Agent effects**:
- Scavenger zone interest rises moderately (cheap goods worth collecting)
- Broker accumulation chance increases (buy low, sell later)
- Courier delivery priority rises (perishable surplus must move quickly)

**Trust dynamics**: Surplus notices are easier to verify (goods are
visibly present). Trust impact is moderate -- correct surplus notices
build trust steadily, incorrect ones cause mild erosion.

### 7.3 Route Warning

**Trigger**: Danger confirmed on a travel corridor -- zombie horde movement,
blackout zone, structural collapse, military activity, civil unrest.

**Market effects**:
- Indirect -- route disruption reduces future supply flow, causing
  lagged pressure increases in zones downstream of the blockage
- Wholesaler reroute posture rises for affected corridors
- Rumour echoes moderate (route warnings are specific and verifiable)

**Agent effects**:
- Courier route caution rises significantly
- Scavenger route variance increases (seeking alternative paths)
- Recall delay risk rises for agents currently in the affected corridor
- Mission routing adjusts -- active missions may re-evaluate pathing

**Trust dynamics**: Route warnings are high-stakes, high-verifiability.
Agents and traders who follow the warning and avoid danger build trust
quickly. False warnings (route was safe) cause sharp trust loss --
nobody forgives being told to take the long way for nothing.

### 7.4 Contact Bulletin

**Trigger**: New trader, wholesaler, or military contact confirmed through
terminal analysis or agent field report.

**Market effects**:
- Unlocks new trade opportunities in the target zone
- Increases inbound chatter on the rumour network (new contacts generate
  their own information streams)
- Wholesaler probe posture rises (new contact = new market dynamics to
  test)

**Agent effects**:
- Agent interest rises for missions near the new contact's zone
- Broker contact interest increases (new trading partner = new margins)
- Smuggler probe interest rises (new contact may be corruptible or useful)

**Trust dynamics**: Contact bulletins are low-risk, moderate-reward.
They rarely damage trust (the contact either exists or doesn't), and
successful introductions build trust gradually.

### 7.5 Strategic Rumour

**Trigger**: Player deliberately crafts a low-confidence, high-distortion
broadcast. This is intentional misinformation -- the player knows (or
suspects) the broadcast does not reflect reality, and transmits it anyway.

**Market effects**:
- Larger social distortion than equivalent-strength honest broadcasts
- Lower trust impact initially (the broadcast is flagged as low-confidence)
- More noise injected into the rumour system -- strategic rumours are the
  most echo-generative broadcast class
- Stronger but less predictable reactions -- the market may overshoot,
  undershoot, or react in unexpected directions

**Agent effects**:
- Agents discount low-confidence advisories but do not ignore them entirely
- Risk bias shifts are amplified but unreliable
- Some archetypes (smuggler, broker) may *exploit* known rumours for
  personal advantage

**Trust dynamics**: Strategic rumours are a double-edged sword. If the
region detects the manipulation (reality sharply contradicts the broadcast),
trust drops severely. If the rumour happens to align with reality (by
coincidence or clever prediction), trust is unaffected. The player is
gambling with their credibility.

**Design note**: Strategic rumours exist because information warfare is a
core fantasy of POSnet. The player should have the option to weaponise
their broadcast authority -- but the cost must be real and the consequences
unpredictable. Magnificent for morally grey play.

---

## 8. Performance

The Broadcast Influence System must be lightweight. It runs on the economy
tick alongside the Living Market, agent ticks, and rumour processing.

### 8.1 Persistence

- **Aggregate-first** -- store broadcast effects as zone/category
  aggregates, not per-listener records. One market_signal per
  zone-category pair, not one per wholesaler.
- **Compact records** -- broadcast records use flat tables with numeric
  values. No nested objects deeper than one level.
- **Bounded history** -- retain only active (non-expired) broadcasts in
  the hot path. Expired broadcasts move to a capped archive (last 50)
  for trust calculation, then are pruned.

### 8.2 Tick Integration

- **Economy tick** consumes market_signal records by zone and category.
  One pass over active signals per tick. No per-wholesaler iteration
  at the broadcast layer -- the Living Market handles wholesaler-level
  granularity.
- **Agent tick** reads only relevant advisories -- agents query by their
  current zone and mission type, not by scanning all advisories.
- **Expired signals decay cleanly** -- freshness decrement is a single
  multiply per record per tick. Records crossing the expiry threshold
  are removed in the same pass.

### 8.3 Budget

Target: broadcast influence processing should consume no more than 5% of
the economy tick's total budget. Given the economy tick's target of < 50ms
on modest hardware, the broadcast layer should complete in < 2.5ms.

---

## 9. Cross-References

| Document | Relationship |
|----------|-------------|
| `satellite-uplink-design.md` | Defines the Tier IV hardware, broadcast mechanics, and uplift process that feeds this system |
| `tier-v-strategic-relay-design.md` | Tier V amplifies and relays broadcasts across regions; this system defines what those broadcasts *do* |
| `signal-ecology-design.md` | Signal quality affects broadcast strength and reliability; degraded signals produce weaker influence |
| `free-agent-system.md` | Agents consume agent_advisory records produced by this system |
| `living-market-design.md` | The Living Market consumes market_signal records and applies perceived pressure shifts |
| `interoperability-matrix.md` | Canonical payload shapes for all records; this system's schemas are registered there |
| `design-guidelines.md` section 52 | Governing design principles for the broadcast influence layer |
| `world-broadcast-network-design.md` | Diegetic delivery pipeline that presents broadcast influence effects as radio bulletins |
| `radio-band-taxonomy-design.md` | Band separation rules governing where broadcasts are heard |

---

## 10. Anti-Patterns

These are behaviours the Broadcast Influence System must **never** exhibit.

1. **Do not rewrite real inventory** -- Broadcasts alter *perceived*
   pressure, never actual stock levels. If a scarcity alert causes prices
   to rise, it is because the market *believes* supply is low, not because
   supply was destroyed. Real inventory is owned by the Living Market and
   wholesaler state machines.

2. **Do not guarantee delivery** -- Broadcasts are informational, not
   logistical. A surplus notice does not cause goods to arrive. It tells
   the market that goods *might* be available. Actual delivery depends on
   wholesaler behaviour, agent operations, and zone conditions.

3. **Do not bypass trust** -- Every broadcast effect must be weighted by
   regional trust. A broadcast to a region with 0.2 trust should produce
   minimal market impact and heavy rumour distortion. There is no
   "override" channel that ignores trust.

4. **Do not simulate every NPC listener** -- The system must not model
   individual NPC reactions to broadcasts. Effects are applied at the
   zone-category and wholesaler-archetype level. Individual NPC behaviour
   emerges from those aggregate shifts, not from per-NPC broadcast
   processing.

5. **Do not stack without decay** -- Multiple broadcasts to the same
   zone/category must not produce unbounded pressure accumulation. Each
   broadcast's freshness decays, and the system must enforce a maximum
   perceived pressure cap to prevent runaway feedback loops.

6. **Do not make broadcasts free** -- Every broadcast must consume
   resources (power, calibration, cooldown). If broadcasts are free,
   the player will spam them, which destroys the strategic decision-making
   that makes the system interesting.

---

## 11. Implementation Phases

### Phase 1: Broadcast Record + Market Signal Consumption

- Implement broadcast record creation from Tier IV uplink
- Generate market_signal records from broadcast records
- Living Market economy tick consumes market_signal records
- Perceived pressure shifts apply to zone-category pairs
- Basic freshness decay and expiry pruning
- Persistence in `POSNET.Broadcasts`

### Phase 2: Agent Advisory + Telemetry

- Generate agent_advisory records from broadcast records
- Free Agent Service reads relevant advisories during agent tick
- Telemetry quality bonus applies when Tier IV is operational
- Recall assistance bonus applies during recall attempts
- Agent behavioural modulation (per-archetype response profiles)

### Phase 3: Trust System + Rumour Echoes

- Regional trust scores initialised and persisted
- Trust mutation on broadcast resolution (accuracy measurement)
- Trust weighting applied to all market and agent effects
- Rumour echo generation from broadcasts
- Echo count formula responsive to signal strength, confidence,
  saturation, desperation, blackout, and volatility

### Phase 4: Tier V Relay Amplification

- Tier V Strategic Relay extends broadcast reach across regions
- Relay-amplified broadcasts carry relay metadata
- Trust effects propagate across relay-linked regions (with distance
  decay)
- Cross-region market_signal and agent_advisory generation
- Integration with relay intercept and bandwidth systems
