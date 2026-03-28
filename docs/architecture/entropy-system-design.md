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

# POSnet Entropy System -- Design Document

**Branch**: `main`
**Date**: 2026-03-28
**Status**: Design phase -- implementation not started
**Prerequisites**: Living Market active, WBN pipeline operational,
Signal Ecology layer registered

> **Core doctrine**: Every information source in POSnet should have both
> a yield path and a loss path. The world should trend toward
> informational decay unless effort, infrastructure, and verification
> actively resist it.

> **Design principle**: Do not only simulate changing prices; simulate
> the decay of the right to believe those prices.

**Cross-references**: `design-guidelines.md` (market entropy doctrine),
`signal-ecology-design.md`, `broadcast-influence-design.md`,
`world-broadcast-network-design.md`, `living-market-design.md`

---

## 1. Problem Statement

POSnet's economy currently trends toward positive accumulation: new intel
enters, the world becomes more legible, price reactions accumulate. All
feedback loops are productive: wholesalers, event pressure, observations,
fragments, confidence gains, and reinforcing rumours.

What is missing is a set of **negative influencers that behave like
sinks** -- systems that consume information quality, consume certainty,
and consume market signal strength over time.

The player should sense:

- Information is never permanent
- Yesterday's certainty can become today's rumour
- Too much chatter can be as bad as too little
- Bad broadcasts leave scars
- Markets react to belief, not just reality
- Neglected regions become foggy and unreliable

---

## 2. The Three Kinds of Decay

### 2.1 Information Decay

What you know becomes stale. Every observation, fragment, rumour, and
compiled conclusion loses systemic weight over time -- not just freshness
labels for UI, but actual pricing and confidence weight.

Decay rates vary by source tier:

| Source Tier | Decay Speed | Notes |
|-------------|-------------|-------|
| Raw observations | Fastest | Direct field data, most perishable |
| Broadcast fragments | Fast | Unless reinforced by corroboration |
| Rumours | Moderate | Decay slower but distort more over time |
| Compiled artifacts | Slowest | Terminal analysis, never stays perfect forever |

A category should be able to move through states:

**known accurately -> roughly known -> rumoured -> effectively unknown**

### 2.2 Interpretation Decay

Even if data still exists, confidence in what it means degrades. Sources
can contradict each other, creating friction rather than clarity.
Saturation from too many low-quality inputs pollutes rather than informs.

### 2.3 Market Memory Decay

Prices should not stay under pressure forever unless reinforced by fresh
causes. Zone pressure should drift back toward neutral in the absence of
new inputs. This is partially implemented via
`SIMULATION_PRESSURE_DECAY_RATE` (0.12) but the entropy system makes
this conditional on the fog-of-market state.

---

## 3. The Fog-of-Market Layer

The single most important mechanical addition. A hidden per-zone,
per-category state bundle that every system reads from and writes to.

### 3.1 State Bundle Schema

```lua
zoneIntelState[zoneId][categoryId] = {
    certainty     = 0.50,  -- how trustworthy the current picture is (0-1)
    freshness     = 0.50,  -- how recent the picture is (0-1)
    rumourLoad    = 0.00,  -- rumour/static contamination (0-1)
    contradiction = 0.00,  -- disagreement between sources (0-1)
    trust         = 0.50,  -- regional trust in broadcast-origin info (0-1)
    silenceDays   = 0,     -- days since meaningful verification
    concealment   = 0.00,  -- wholesaler concealment pressure (0-1)
}
```

### 3.2 Per-Tick Update Formulas

Each economy tick applies these updates:

```
freshness     = freshness * ENTROPY_FRESHNESS_DECAY
certainty     = certainty - silencePenalty - contradictionPenalty
                          - noisePenalty
noise         = rumourLoad + blackoutMod + panicMod
                          - verificationRelief
contradiction = contradiction * ENTROPY_CONTRADICTION_DECAY
trust         = trust + accuracyDelta - misinformationDelta
```

Where:
- `silencePenalty` scales with `silenceDays` (more silence = faster decay)
- `contradictionPenalty` scales with `contradiction` score
- `noisePenalty` scales with `rumourLoad`
- `verificationRelief` applies when a fresh verified observation arrives
- `accuracyDelta` is positive when broadcast predictions matched reality
- `misinformationDelta` is positive when they didn't

### 3.3 Effective Pressure Formula

Raw zone pressure is attenuated by the fog-of-market state before
reaching the price engine:

```
effectivePressure =
    rawPressure
    * certaintyModifier
    * trustModifier
    * (1.0 - rumourLoad * ENTROPY_NOISE_WEIGHT)
```

This does not erase raw pressure -- it determines how **believably** it
manifests in player-visible prices.

### 3.4 Storage

The fog-of-market state is stored in world ModData alongside existing
zone state:

```
ModData.getOrCreate("POSNET")[zoneId].intelState[categoryId] = { ... }
```

Flat keys for Java ModData compatibility (same pattern as existing zone
pressure storage).

---

## 4. The Five Negative Influencer Families

### 4.1 Silence -- The Passive Destroyer

A category that goes unobserved becomes progressively unreliable.

Each tick:
- Increment `silenceDays` if no meaningful observation arrived
- Reduce `certainty` proportional to silence duration
- Increase `rumourLoad` when `certainty` drops below threshold
- Last-known price drifts toward estimated baseline
- UI signals atmospheric state labels (see section 7)

**Gameplay consequence**: "Not checking" has a cost. The player must
maintain their intelligence network, not just build it once.

### 4.2 Contradiction -- The Confidence Killer

When sources disagree, the result is not averaged -- it creates
**confidence damage**.

Triggers:
- Fragment contradicts existing rumour direction
- Broadcast contradicts most recent observation
- Multiple agents report opposing directions in same tick

Effects:
- `contradiction` score rises
- `certainty` drops sharply
- Price certainty band widens on terminal display
- WBN editorial filter becomes more conservative
- Agent reaction speed slows

**Existing hook**: `reinforceRumours()` in `POS_WBN_ClientListener.lua`
already detects contradicting fragments and applies
`WBN_RUMOUR_CONTRADICT_DROP`. Promote this from a local rumour tweak
into a fog-of-market state writer.

### 4.3 Saturation -- Too Much Noise

Too many broadcasts, fragments, or low-quality observations in a short
window should pollute knowledge, not improve it.

When saturation is high:
- Confidence gain per new observation falls
- `rumourLoad` increases
- Contradictions become more likely
- Editorial suppression becomes harsher
- Fragment duplication feels messy rather than reassuring

**Existing hook**: Signal Ecology's `saturation` pillar already models
this conceptually. Wire it into the fog-of-market `rumourLoad`.

### 4.4 Trust Erosion -- The Long Memory

Single scalar per zone. Hard to build, easy to damage, slow to recover.

Trust drops from:
- Broadcasts that contradicted reality
- Stale repetition
- Overuse of broadcast channel
- Untimely warnings

Trust rises from:
- Accurate predictions verified by subsequent observations
- Cross-corroborated sources
- Direct player-collected data (recon, camera, scanner)

Effects of low trust:
- Broadcast-sourced pressure is attenuated
- Rumours derived from broadcasts distort more
- Agent advisory uptake drops
- WBN fragment confidence ceiling lowers

### 4.5 Structural World Stressors

Environmental pressors that are not player-caused:

| Stressor | Fog-of-Market Effect |
|----------|---------------------|
| Blackout | Certainty drops, rumourLoad rises, authoritative signal weakens |
| Bad weather | Decay rate increases, observation rate falls (see section 5) |
| Wholesaler concealment | `concealment` rises, false gaps generated |
| Event aftershocks | Temporary volatility floor, contradiction spikes |

---

## 5. Weather and Seasonal Entropy

> **Doctrine**: Weather governs signal integrity. Seasons govern systemic
> entropy. Markets react not to reality -- but to what survives
> transmission.

Weather does not directly change prices. It changes **how information
moves**, **how quickly it decays**, and **how much it can be trusted**.

### 5.1 Weather State Modifier

A unified modifier bundle computed from vanilla PZ climate each tick:

```lua
weatherState = {
    signalQuality       = 0.80,  -- multiplier on fragment confidence
    decayRate           = 1.20,  -- multiplier on freshness/certainty decay
    noiseFactor         = 1.30,  -- multiplier on rumour spawn chance
    contradictionFactor = 1.10,  -- multiplier on contradiction damage
    trustDrift          = -0.01, -- per-tick trust adjustment
    observationRate     = 0.70,  -- probability scaling for agent observations
}
```

### 5.2 Weather Condition Mappings

| Condition | Signal Quality | Decay Rate | Noise | Trust Drift |
|-----------|---------------|-----------|-------|-------------|
| Clear | 1.00 | 1.00 | 1.00 | +0.005 |
| Rain (moderate) | 0.85 | 1.10 | 1.10 | 0.000 |
| Rain (heavy) / Storm | 0.65 | 1.30 | 1.40 | -0.010 |
| Blizzard | 0.40 | 1.50 | 1.60 | -0.020 |
| Fog | 0.90 | 1.05 | 1.30 | -0.005 |
| Heatwave | 0.90 | 1.15 | 1.20 | -0.005 |
| Electrical storm | 0.30 | 1.20 | 1.80 | -0.015 |

### 5.3 Seasonal Baseline Modifiers

Seasons define the baseline entropy behaviour. These multiply the
weather modifiers:

| Season | Decay Mult | Noise Mult | Trust Drift | Character |
|--------|-----------|-----------|-------------|-----------|
| Spring | 1.00 | 1.20 | +0.005 | Recovery and noise -- chaotic, rebuilding |
| Summer | 0.90 | 1.30 | 0.000 | Signal-rich, truth-poor -- loud, saturated |
| Autumn | 0.95 | 0.80 | +0.010 | Stabilisation and hoarding -- tightening |
| Winter | 1.40 | 1.50 | -0.010 | Maximum entropy -- ghosts and guesses |

### 5.4 Integration with Signal Ecology

The existing Signal Ecology service already computes weather and seasonal
modifiers via `POS_SignalModifierRegistry`. The entropy system should
**read from Signal Ecology's propagation pillar**, not duplicate weather
detection. This keeps weather detection authoritative in one place.

```
certainty = certainty - baseDecay * weather.decayRate - silencePenalty
fragmentConfidence = fragmentConfidence * weather.signalQuality
rumourSpawnChance = baseChance * weather.noiseFactor * (1.0 - certainty)
trust = trust + accuracyDelta + weather.trustDrift
```

### 5.5 Information Shadows

In severe conditions, zones can fall into **informational shadow
states**: data still exists but becomes unreliable. Broadcasts from
shadowed zones gain distortion tags. Price signals from those zones
weaken or lag.

This creates not just unknown zones -- but **untrustworthy zones**.

---

## 6. Wholesaler Concealment as Intelligence Attack

Wholesaler concealment should attack intel quality, not just supply.

### 6.1 Concealment Effects

A concealed wholesaler:
- Reduces visibility of true stock posture
- Increases chance of false scarcity signals
- Generates ghost-stock rumours
- Produces mismatched observations in nearby zones

### 6.2 Sandbox Gate

Wholesaler concealment intel effects are gated behind a sandbox option:
`POS.EnableConcealmentEffects` (default: true). When disabled, wholesaler
concealment still affects supply pressure (existing behaviour) but does
not write to the fog-of-market `concealment` field or generate ghost
rumours. This lets players who find concealment frustrating opt out
while keeping the supply-side mechanic intact.

### 6.3 Detection via SIGINT (Requires Concealment Enabled)

Concealment effects are **detectable via SIGINT skill**:

| SIGINT Level | Detection |
|-------------|-----------|
| 0-2 | No indicators -- fog just thickens |
| 3-5 | Terminal shows "Concealment suspected" on zone overview |
| 6-8 | Shows affected categories and estimated concealment level |
| 9-10 | Shows which wholesaler archetype is concealing |

This creates a counter-play loop: players who invest in SIGINT can see
through concealment, rewarding the skill's late-game progression.

### 6.4 Posture Secondary Effects

| Posture | Certainty Effect | Rumour Effect | Notes |
|---------|-----------------|---------------|-------|
| `hold` | Slight reduction | Modest scarcity | Conservative |
| `conceal` | Strong damage | Ghost-stock rumours, false gaps | Active deception |
| `dump` | Short-term surplus | Later contradiction risk | Unstable |
| `reroute` | Cross-zone mismatch | Delayed intel drift | Regional noise |
| `accumulate` | Scarcity pressure | Speculative noise | Hoarding |

---

## 7. Terminal UI Atmospheric States

The terminal should surface fog-of-market state using atmospheric
language, not just percentages:

| Certainty Range | UI Label |
|----------------|----------|
| 0.80 - 1.00 | "Market picture clear" |
| 0.60 - 0.79 | "Market picture ageing" |
| 0.40 - 0.59 | "Conflicting field readings" |
| 0.20 - 0.39 | "High distortion suspected" |
| 0.00 - 0.19 | "Cold market -- verification overdue" |

Additional contextual labels:
- "Broadcast environment saturated" (rumourLoad > threshold)
- "Wholesaler concealment likely" (concealment > threshold, SIGINT >= 3)
- "Signal-rich, truth-poor" (high observation count + low certainty)

---

## 8. Implementation Phases

### Phase 1 -- Foundational Entropy (Priority: Highest)

1. Add `zoneIntelState` bundle to zone state in `POS_MarketSimulation`
2. Implement certainty decay by silence (each economy tick)
3. Implement contradiction score per zone/category (on fragment receipt)
4. Implement rumourLoad per zone/category (from WBN chatter volume)
5. Wire `effectivePressure` formula into `POS_PriceEngine`
6. Add atmospheric state labels to Market Overview terminal screen

### Phase 2 -- Actor-Based Distortion

7. Wholesaler concealment affecting `concealment` field
8. SIGINT-gated concealment detection on terminal
9. Blackout state degrading authoritative signal quality
10. Weather modifier integration via Signal Ecology propagation pillar

### Phase 3 -- Richer Downstream Consequences

11. Seasonal baseline modifiers
12. Trust erosion from failed broadcast predictions
13. Speculative overreaction / false scarcity waves
14. Information shadow zones in severe weather
15. Desperation multipliers on bad inference

---

## 9. Constants (Suggested Initial Values)

All constants should live in `POS_Constants_Entropy.lua` on the
`POS_Constants` table with prefix `ENTROPY_`.

```lua
-- Fog-of-market decay rates (per economy tick)
ENTROPY_FRESHNESS_DECAY          = 0.88
ENTROPY_CONTRADICTION_DECAY      = 0.75
ENTROPY_CERTAINTY_SILENCE_RATE   = 0.03  -- per silenceDay
ENTROPY_CERTAINTY_NOISE_RATE     = 0.02  -- per unit rumourLoad
ENTROPY_NOISE_WEIGHT             = 0.50  -- rumourLoad impact on pressure

-- Trust parameters
ENTROPY_TRUST_ACCURACY_GAIN      = 0.02
ENTROPY_TRUST_MISINFO_LOSS       = 0.05
ENTROPY_TRUST_MIN                = 0.10
ENTROPY_TRUST_MAX                = 0.95
ENTROPY_TRUST_DEFAULT            = 0.50

-- Silence thresholds
ENTROPY_SILENCE_WARNING_DAYS     = 3
ENTROPY_SILENCE_STALE_DAYS       = 5
ENTROPY_SILENCE_COLD_DAYS        = 8

-- Concealment
ENTROPY_CONCEALMENT_DECAY        = 0.90
ENTROPY_CONCEALMENT_SIGINT_GATE  = 3  -- min SIGINT to see indicators

-- Saturation
ENTROPY_SATURATION_THRESHOLD     = 8  -- fragments/tick before penalties
ENTROPY_SATURATION_CONF_PENALTY  = 0.10  -- per excess fragment

-- Weather multiplier ranges
ENTROPY_WEATHER_DECAY_MIN        = 1.00
ENTROPY_WEATHER_DECAY_MAX        = 1.50
ENTROPY_WEATHER_NOISE_MIN        = 1.00
ENTROPY_WEATHER_NOISE_MAX        = 1.80
```

---

## 10. File Locations (Planned)

| File | Purpose |
|------|---------|
| `shared/POS_Constants_Entropy.lua` | All entropy named constants |
| `shared/POS_EntropyService.lua` | Fog-of-market tick logic, state management |
| `shared/POS_MarketSimulation.lua` | Zone state extended with `intelState` |
| `shared/POS_PriceEngine.lua` | `effectivePressure` reads fog-of-market |
| `shared/POS_WBN_ClientListener.lua` | Contradiction writes to fog state |
| `shared/POS_WholesalerService.lua` | Concealment writes to fog state |
| `client/POS_Screen_MarketOverview.lua` | Atmospheric state labels |

---

## 11. Anti-Patterns

- Treating negative influencers as just "price goes down" -- they should
  damage clarity, confidence, timeliness, trust, and consistency
- Making decay too harsh -- aim for calibration drift, not punishment
- Duplicating weather detection -- read from Signal Ecology, don't
  reimplement
- Storing entropy state per-record instead of per-zone/category -- the
  fog-of-market layer is the authoritative state
- Hardcoding decay rates -- use `POS_Constants.ENTROPY_*` for all values
