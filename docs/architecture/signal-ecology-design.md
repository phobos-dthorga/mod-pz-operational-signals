# POSnet Signal Ecology -- Future Architecture (v2)

## Status

**This document describes the target signal architecture (v2).** The
current implementation uses a flat signal-strength percentage (v1) as
documented in design-guidelines.md section 5. Migration from v1 to v2 is a
future milestone; this document defines the destination.

**Design Principle**:
> Signal should never be a guarantee. It should be a negotiation
> between physics, infrastructure, people, systems, and the player's
> intent.

---

## 1. The Core Shift

### 1.1 From Signal Strength to Signal Ecology

Replace the flat single percentage:

```
signalStrength = 100%
```

With a multi-dimensional field of interacting forces:

```
signal = f(propagation, infrastructure, clarity, saturation, intent)
```

The output is not just a number -- it is **behaviour**. Different
signal conditions produce qualitatively different experiences, not
just higher or lower percentages.

### 1.2 Why This Matters

The current flat 100% signal at top-tier radios collapses an entire
dimension of gameplay into a solved state. POSnet thrives on
uncertainty, degradation, and interpretation. A solved signal means:
- Radios become "done" once you find the best one
- Weather, markets, and world state have no effect on communication
- The information the player receives is always equally reliable
- Infrastructure investment has no ongoing payoff

---

## 2. The Five Pillars of Signal

### 2.1 Propagation Quality (Physics Layer)

> "How well can the signal travel?"

Affected by:
- **Weather**: rain reduces propagation; storms spike noise +
  instability; fog causes mild but persistent degradation; wind
  causes antenna instability
- **Season**: summer = better propagation but higher saturation;
  winter = worse propagation but clearer channels; autumn = unstable
  transitions; spring = volatile noise patterns
- **Time of day**: ionospheric effects (optional future detail)
- **Terrain**: urban clutter vs open rural
- **Building obstruction**: interior penalty
- **Antenna type**: handheld vs base station vs satellite dish

This is the **RF realism layer**.

**Bonus**: storms could increase intercept opportunities due to signal
scatter.

### 2.2 Infrastructure Integrity (Power & Hardware Layer)

> "How stable is the network itself?"

Affected by:
- **Grid power status**: blackouts cause instability spikes
- **Generator fuel levels**: low fuel = unstable bursts, periodic
  dropouts
- **Hardware condition**: wear, damage, component age
- **Calibration drift**: especially critical for satellite dishes
- **Wiring quality**: cable-distance mechanic (section 5.6 in design
  guidelines) maps directly here

This is the **diegetic survival layer**.

### 2.3 Signal Clarity (Information Layer)

> "How readable is what you're receiving?"

Affected by:
- **Noise**: environmental + artificial sources
- **Encoding/decoding quality**: terminal analysis level
- **Terminal analysis tier**: higher analysis = better reconstruction
- **Interference**: intentional or incidental
- **Competing broadcasts**: overlapping transmissions

This is where **terminal and compilation systems** contribute to
signal quality.

### 2.4 Network Saturation (Economic/Social Layer)

> "How crowded is the air?"

Affected by:
- **Number of active agents**: more agents = more traffic
- **Market chatter volume**: active trading generates noise
- **Panic events**: outbreak spikes, scarcity waves flood airwaves
- **Wholesaler activity**: bulk operations generate detectable signals
- **Military vs civilian band usage**: band competition

This is where **market + free agent systems plug directly into
signal**.

**Critical insight**: markets don't just respond to signal -- they
**distort** it.

### 2.5 Intent & Priority (Player Control Layer)

> "What are you trying to do with the signal?"

Affected by:
- **Bandwidth allocation**: agents vs market vs intercepts (Tier V)
- **Priority routing**: relay-directed traffic shaping
- **Transmission type**: burst vs continuous vs broadcast
- **Encryption strength**: future system hook

This is where **player agency** lives.

---

## 3. The Composite Formula

### 3.1 Conceptual Model

```
Signal Result =
    Propagation
  x Infrastructure
  x (Clarity - Noise)
  x (1 - Saturation)
  x Intent Modifier
```

This produces a composite score that maps to qualitative signal states
(section 4) rather than a raw percentage.

### 3.2 Pillar Ranges

Each pillar is normalised to [0.0, 1.0]:

| Pillar          | 0.0 Means              | 1.0 Means               |
|-----------------|------------------------|--------------------------|
| Propagation     | Total atmospheric block | Perfect conditions       |
| Infrastructure  | No power, broken gear  | Full grid, pristine gear |
| Clarity         | Pure noise             | Crystal clear            |
| Saturation      | Dead air               | Completely jammed        |
| Intent          | Unfocused              | Optimal allocation       |

### 3.3 Per-Tier Modifiers

Each intelligence tier applies a floor and ceiling to the composite:

| Tier | Baseline Floor | Max Ceiling | Notes                          |
|------|---------------|-------------|--------------------------------|
| I    | 0.10          | 0.60        | Handheld, field conditions     |
| II   | 0.25          | 0.80        | Base station, powered terminal |
| III  | 0.35          | 0.85        | Workstation with camera feeds  |
| IV   | 0.45          | 0.92        | Satellite dish, regional reach |
| V    | 0.55          | 0.98        | Strategic relay, managed chaos |

Even at Tier V, 100% is practically unreachable. This is intentional.

### 3.4 Per-Subsystem Pillar Contributions

Each POSnet subsystem feeds into or consumes the five signal pillars:

| Subsystem | Propagation | Infrastructure | Clarity | Saturation | Intent |
|-----------|-------------|---------------|---------|------------|--------|
| Weather / Season | Direct input (rain, storms, fog, wind) | — | Noise source | — | — |
| Power Grid | — | Direct input (blackouts, generator fuel) | — | — | — |
| Hardware Condition | — | Direct input (wear, calibration drift) | — | — | — |
| Wiring Distance | — | Degrades (cable-distance mechanic) | — | — | — |
| Wholesaler Activity | — | — | — | Contributes (market chatter volume) | — |
| Free Agent Count | — | — | — | Contributes (active agent transmissions) | — |
| Panic Events | — | — | Noise spike | Spike (desperate broadcasts) | — |
| Tier IV Broadcast | — | Consumes (power draw) | Consumes (distortion risk) | Increases (broadcast adds to chatter) | — |
| Tier V Relay | — | Stabilises (floor raised) | Improves (reconstruction) | Buffers (priority filtering) | Enables (player-controlled allocation) |
| Terminal Analysis | — | — | Direct input (encoding/decoding quality) | — | — |
| Competing Broadcasts | — | — | Interference source | Contributes | — |

> **Reading the table**: "Direct input" means the subsystem is a primary data source
> for that pillar. "Contributes" means it adds pressure. "Consumes" means it draws
> from the pillar's capacity. "Stabilises/Buffers/Improves" means it counteracts
> degradation.

See `broadcast-influence-design.md` §3–4 for how broadcasts specifically
affect the market and agent systems through these pillars.

---

## 4. Signal States

### 4.1 Qualitative Bands

Instead of displaying a raw 0-100% number, the player sees qualitative
signal states:

| State         | Range      | Behaviour                         |
|---------------|------------|-----------------------------------|
| **Locked**    | 85-100%    | Stable, high-confidence data      |
| **Clear**     | 65-84%     | Minor degradation, reliable       |
| **Faded**     | 45-64%     | Partial loss, gaps in data        |
| **Fragmented**| 25-44%     | Intermittent, reconstructable     |
| **Ghosted**   | 10-24%     | Misleading or ambiguous signals   |
| **Lost**      | 0-9%       | Nothing usable                    |

### 4.2 State Effects

Each state affects system behaviour qualitatively:

**Locked**: Full data fidelity. Agent telemetry complete. Market data
fresh. Broadcasts land cleanly.

**Clear**: Minor noise artifacts. Occasional data gaps. Agent updates
may be slightly delayed. Market data has small confidence reduction.

**Faded**: Noticeable gaps. Some agent updates missed. Market data
requires terminal reconstruction. Briefings may be garbled.

**Fragmented**: Intermittent contact. Agent status uncertain.
Market data fragmentary -- requires compilation to be usable.
Broadcasts may partially fail.

**Ghosted**: Signal present but unreliable. Agent telemetry is
ambiguous -- state reports may be inaccurate. Market data may
contain misinformation. Broadcasts distorted on reception.

**Lost**: No usable signal. Agents are in the dark. Market feeds
dead. Broadcasts cannot be sent.

### 4.3 Diegetic Display

The left side panel shows signal diagnostics using the pillar model:

```
SIGNAL STATUS: FADED
  Propagation:    GOOD     (clear skies, summer)
  Infrastructure: UNSTABLE (generator low)
  Noise Floor:    HIGH     (market panic event)
  Saturation:     HEAVY    (3 agents active)
```

The right side panel shows interpretation aids:
- Confidence rating for current data
- Missing segments indicator
- Anomaly flags
- Reconstruction suggestions

---

## 5. Environmental Factor Mapping

### 5.1 Weather Effects

| Condition | Propagation | Noise  | Notes                              |
|-----------|-------------|--------|------------------------------------|
| Clear     | +0.00       | +0.00  | Baseline                           |
| Rain      | -0.10       | +0.05  | Steady degradation                 |
| Storm     | -0.25       | +0.20  | Spike noise + instability          |
| Fog       | -0.05       | +0.03  | Mild but persistent                |
| Wind      | -0.08       | +0.02  | Antenna instability                |
| Snow      | -0.12       | +0.04  | RF absorption                      |

**Bonus**: storms increase intercept opportunities due to signal
scatter (atmospheric bouncing).

### 5.2 Season Effects

| Season | Propagation | Saturation | Notes                            |
|--------|-------------|------------|----------------------------------|
| Summer | +0.05       | +0.10      | Better propagation, more activity|
| Autumn | -0.05       | +0.00      | Unstable transitions             |
| Winter | -0.10       | -0.10      | Worse propagation, clearer bands |
| Spring | +0.00       | +0.05      | Volatile noise patterns          |

This gives the signal system **long-term seasonal rhythm**.

### 5.3 Market Dynamics

| Market State      | Saturation | Noise  | Notes                        |
|-------------------|------------|--------|------------------------------|
| Stable            | +0.00      | +0.00  | Cleaner signal               |
| High demand       | +0.15      | +0.05  | More chatter                 |
| Scarcity          | +0.10      | +0.15  | Desperate broadcasts         |
| Volatile          | +0.20      | +0.20  | Misinformation risk          |
| Panic             | +0.30      | +0.25  | Airwaves flooded             |

### 5.4 Blackouts / Power Grid

| Grid State       | Infrastructure | Saturation | Notes                     |
|------------------|---------------|------------|---------------------------|
| Grid ON          | +0.20         | +0.10      | Stable but crowded        |
| Grid FAILING     | +0.05         | +0.05      | Transition state          |
| Grid OFF         | -0.15         | -0.15      | Weak infrastructure, quiet|
| Generator only   | -0.05         | -0.10      | Unstable bursts           |

**Paradox**: fewer signals (blackout) does NOT equal better clarity.
The infrastructure degradation offsets the reduced saturation.

### 5.5 Desperation / Human Behaviour

| Social State     | Noise  | Saturation | Notes                       |
|------------------|--------|------------|-----------------------------|
| Calm             | +0.00  | +0.00      | Baseline                    |
| Anxious          | +0.05  | +0.05      | Increased chatter           |
| Panicked         | +0.20  | +0.15      | Spam transmissions          |
| Organised        | -0.05  | +0.10      | Structured, high-quality    |
| Hostile          | +0.15  | +0.05      | Misinformation / bait       |

---

## 6. Tier V Enhancement of Signal Ecology

The Strategic Relay (Tier V) does NOT give "100% signal." Instead:

- **Stabilises** the infrastructure pillar (floor raised)
- **Reduces** the noise floor (clarity improved)
- **Improves** clarity reconstruction (terminal cross-reference)
- **Buffers** saturation effects (priority filtering)
- **Allows** priority routing (player-controlled intent pillar)

So instead of `signal = 100%`, it becomes:
**"Signal chaos becomes manageable."**

---

## 7. Emergent System Loop

The signal ecology creates a closed emergent loop:

```
Weather affects Signal
    -> Signal affects Agents
        -> Agents affect Markets
            -> Markets affect Signal
```

This means:
1. **Radios are never "solved"** -- even top-tier gear struggles under
   storms, panic markets, and blackout cascades.
2. **Players must interpret, not consume** -- they receive evidence,
   not truth.
3. **Systems finally interlock** -- every pillar connects to every
   other system in POSnet.

---

## 8. Migration Path (v1 -> v2)

### 8.1 Current State (v1)

Signal is a flat percentage derived from radio power:
```
signal = clamp(0, 1, (power / reference)^2)
```

Five quality bands: EXCELLENT, GOOD, WEAK, CRITICAL, Cannot Connect.

### 8.2 Transition Strategy

**Phase A -- Introduce weather effects** (minimal disruption):
Add weather modifier to existing signal calculation. Player sees
signal fluctuate with rain/storms. No new UI needed.

**Phase B -- Add infrastructure pillar**:
Factor in power source stability and hardware condition. Generator
fuel level affects signal. Cable distance already exists (section 5.6).

**Phase C -- Add saturation from market/agents**:
Active agents and market activity create background noise. This
is invisible initially, becomes visible when market is active.

**Phase D -- Full ecology UI**:
Replace single percentage display with qualitative states and
pillar diagnostics in side panels.

**Phase E -- Intent pillar** (Tier V only):
Bandwidth allocation and priority routing. Requires Tier V
implementation.

### 8.3 Backward Compatibility

During transition, the composite signal value must still produce
a [0, 1] float that existing code can consume via
`POS_ConnectionManager.getSignalStrength()`. Internal computation
changes; external interface stays stable.

---

## 9. Data Structures

### 9.1 Signal State Record

```lua
SignalState = {
    composite        = 0.0,    -- final [0, 1] value
    qualitativeState = "clear", -- locked/clear/faded/fragmented/ghosted/lost
    pillars = {
        propagation    = 0.0,
        infrastructure = 0.0,
        clarity        = 0.0,
        saturation     = 0.0,
        intent         = 0.0,
    },
    modifiers = {
        weather        = 0.0,   -- current weather effect
        season         = 0.0,   -- current season effect
        marketState    = 0.0,   -- market-derived noise
        gridState      = 0.0,   -- power grid effect
        socialState    = 0.0,   -- desperation/organisation
    },
    lastCalculated     = 0,     -- game tick of last computation
}
```

### 9.2 Performance Considerations

Signal recalculation is **not per-frame**. Computed:
- Once per game hour (normal operation)
- On significant state change (weather transition, power loss,
  market event)
- Cached and reused between calculations

---

## 10. Relationship to Other Systems

| System                    | Interaction                              |
|---------------------------|------------------------------------------|
| `POS_ConnectionManager`   | Primary consumer; provides getSignalStrength() |
| `POS_FreeAgentService`    | Agent telemetry quality from signal state |
| `POS_MarketSimulation`    | Market state feeds saturation pillar     |
| `POS_StrategicRelayService`| Tier V modifies infrastructure + intent  |
| `POS_SatelliteService`    | Tier IV broadcast quality from signal    |
| Weather API (vanilla PZ)  | Propagation + noise from weather state   |
| Power system (PhobosLib)  | Infrastructure pillar from power state   |

---

## 11. Design Principle Summary

1. Signal is a **negotiation**, not a guarantee
2. Every pillar connects to a different game system
3. The player sees **qualitative states**, not raw percentages
4. Even the best equipment struggles under adverse conditions
5. The emergent loop (weather -> signal -> agents -> markets -> signal)
   creates a living, breathing communications layer
6. Tier V manages chaos; it does not eliminate it
