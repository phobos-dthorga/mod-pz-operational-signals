# POSnet Living Market — Autonomous Economic Simulation Design

> **Status**: Phase 1 implemented — wholesaler lifecycle, zone pressure
> aggregation, agent meter updates, and simulation tick active.
> Signal emission remains placeholder. Living Market is always active (no longer gated behind a sandbox option).
> **Prerequisite reading**: `market-exchange-design.md` (current 3-layer architecture),
> `design-guidelines.md` Sections 12–13, 24 (Living Market), 26 (Data-Pack Architecture).

This document describes the design for **Layer 0: World Economy** — an
autonomous economic simulation that runs independently of the player,
transforming the market system from reactive intelligence ("player creates
data") into intercepted reality ("world produces data, player samples it").

For related systems, see:
- `data-recorder-design.md` — Field intelligence gathering
- `camera-workstation-design.md` — Intelligence compilation
- `satellite-uplink-design.md` — Market propagation
- `sigint-skill-design.md` — SIGINT skill and intel quality
- `design-guidelines.md` §26 — Data-pack architecture (schemas, registries, definitions)

---

## 1. Architectural Evolution

### Current State (Layers A–C)

```
Layer A: Field Intelligence       (player actions → raw data)
    ↓
Layer B: POSnet Aggregation       (data processing → summaries)
    ↓
Layer C: Presentation             (terminal screens → player decisions)
```

### Target State (Layer 0 + Layers A–C)

```
Layer 0: World Economy Simulation ← NEW (autonomous heartbeat)
    ↓
Layer A: Field Intelligence       (player intercepts signals from Layer 0)
    ↓
Layer B: POSnet Aggregation       (POSnet compiles intercepted data)
    ↓
Layer C: Presentation             (terminal UI displays actionable intel)
```

### Core Philosophy Shift

| Before | After |
|--------|-------|
| Player "creates" market data | Player **samples** an already-moving system |
| "What does the player know?" | "What is the world doing, regardless of the player?" |
| Reporting system | Living market |

---

## 2. Market Zones (Geographically Fractured Economy)

> **Implementation**: Zone definitions are data-only Lua files in
> `Definitions/Zones/`, validated by `POS_ZoneSchema.lua`.

The market is **not global**. Each zone tracks localised supply and demand.

### Zone Schema

```lua
MarketZone = {
    id          = "west_point",     -- unique identifier
    supply      = {},               -- { [categoryId] = number }
    demand      = {},               -- { [categoryId] = number }
    volatility  = 0.20,            -- baseline zone volatility
    pressure    = {},               -- { [categoryId] = number } (derived)
}
```

### Recommended Starting Zones

| Zone ID | Description |
|---------|-------------|
| `muldraugh` | Small town, sparse market |
| `west_point` | Medium hub, balanced |
| `riverside` | Moderate, slightly isolated |
| `louisville_edge` | Dense, deep but unstable |
| `military_corridor` | Military-dominated, distorted |
| `rural_east` | Remote, scavenger-heavy |

### Zone Interaction

Wholesalers belong primarily to one zone but may exert **spillover
influence** on adjacent zones. This provides route texture without
requiring full freight simulation.

---

## 3. Market Agent Architecture

> **Implementation**: Archetype profiles are defined as data-only Lua files in
> `Definitions/Archetypes/`, validated by `POS_ArchetypeSchema.lua`, and
> registered through `POS_MarketAgent.getRegistry()`. See `design-guidelines.md`
> §26 for the full data-pack architecture.

Market agents are **invisible economic personalities** that generate
observations, stock posture, rumours, and price drift — without simulating
every survivor in Kentucky.

### Design Goal

Each archetype answers:
1. How accurate are its quotes?
2. How much stock does it usually claim?
3. How volatile is it?
4. Does it lead, lag, or distort a market?
5. Does it create rumours, stability, shortages, or spikes?
6. How much should POSnet trust it?

### Core Agent Schema

```lua
MarketAgent = {
    id              = "wp_wholesaler_01",
    archetype       = "wholesaler",
    displayName     = "Knox Consolidated Supply",
    zoneId          = "west_point",
    categories      = { "food", "medicine", "tools" },
    reliability     = 0.75,     -- truthfulness of quotes
    volatility      = 0.20,     -- how jumpy prices are
    stockBias       = "high",   -- usual stock posture
    priceBias       = 0.05,     -- markup/discount vs zone baseline
    refreshDays     = 1,        -- how often they meaningfully update
    influence       = 3,        -- how much they move the zone
    secrecy         = 0.20,     -- chance intel is incomplete/obscured
    rumorRate       = 0.10,     -- chance to emit soft intel per tick
    riskTolerance   = 0.50,     -- how aggressively they change
    faction         = "civilian",-- civilian, criminal, military, mixed
}
```

### Hidden Agent State

To avoid robotic repetition, each agent maintains internal meters that
create texture without being visible to the player:

```lua
agentState = {
    pressure    = 0.0,  -- supply chain stress
    greed       = 0.0,  -- temporary markup urge
    exposure    = 0.0,  -- risk of compromise/raid
    surplus     = 0.0,  -- tendency to dump inventory
    trustShift  = 0.0,  -- temporary change in quote honesty
}
```

---

## 4. Agent Archetypes (7 Core Types)

### 4.1 Scavenger Trader

**Fiction**: Mobile survivor, small cache, opportunistic, inconsistent.

**Market role**: Noisy local quotes, low-medium stock, prices swing hard,
good early-game source of "something changed nearby".

```lua
{
    archetype     = "scavenger_trader",
    reliability   = 0.55,  volatility  = 0.45,
    stockBias     = "low",  priceBias  = 0.10,
    refreshDays   = 1,      influence  = 1,
    secrecy       = 0.25,  rumorRate   = 0.20,
    riskTolerance = 0.80,
}
```

**POSnet role**: Generates lots of raw notes and weak-confidence chatter.

### 4.2 Settlement Quartermaster

**Fiction**: Stable civilian node tied to a camp, commune, or enclave.
Pricing is practical rather than speculative.

**Market role**: Stable regional anchor, medium-high stock in necessities,
slow movement, high confidence source. Smooths volatility.

```lua
{
    archetype     = "quartermaster",
    reliability   = 0.85,  volatility  = 0.15,
    stockBias     = "medium", priceBias = 0.00,
    refreshDays   = 2,      influence  = 3,
    secrecy       = 0.10,  rumorRate   = 0.05,
    riskTolerance = 0.25,
}
```

### 4.3 Wholesaler / Stockpile Broker

**Fiction**: Survivor group with warehousing, convoy access, or
pre-collapse storage holdings.

**Market role**: Bulk categories, suppresses or amplifies scarcity, sets
the "real" regional tone. Low frequency, high consequence.

```lua
{
    archetype     = "wholesaler",
    reliability   = 0.80,  volatility  = 0.20,
    stockBias     = "high", priceBias  = -0.05,
    refreshDays   = 3,      influence  = 5,
    secrecy       = 0.15,  rumorRate   = 0.08,
    riskTolerance = 0.40,
}
```

**Special mechanic**: Can trigger bulk arrivals, stock dumps, regional
shortages, and delayed shock propagation to downstream traders.

### 4.4 Smuggler

**Fiction**: Moves contraband, scarce luxuries, restricted tools, ammo,
radios, medicines through hidden channels.

**Market role**: High value, low visibility, distorts scarcity signals,
intermittent but meaningful quotes, sometimes lies.

```lua
{
    archetype     = "smuggler",
    reliability   = 0.45,  volatility  = 0.50,
    stockBias     = "low",  priceBias  = 0.25,
    refreshDays   = 2,      influence  = 2,
    secrecy       = 0.60,  rumorRate   = 0.30,
    riskTolerance = 0.90,
}
```

**Special mechanic**: Produces incomplete observations, confidence
penalties, sudden availability reversals, "ghost stock" rumours that
later prove wrong. Makes the player's intel work matter.

### 4.5 Military Logistician

**Fiction**: Checkpoint stores, requisition depots, motor-pool caches,
field units, or raided military stores.

**Market role**: Dominates ammo, fuel, radios, medical supplies. Can flood
or starve a market. High authority, not always accessible.

```lua
{
    archetype     = "military_logistician",
    reliability   = 0.90,  volatility  = 0.25,
    stockBias     = "high", priceBias  = -0.10,
    refreshDays   = 3,      influence  = 6,
    secrecy       = 0.50,  rumorRate   = 0.12,
    riskTolerance = 0.35,
}
```

**Special mechanic**: Indirectly affects civilian categories — fuel
diverted from settlements, radio gear becoming scarce, medicine
disappearing into secured channels. Geopolitical texture.

### 4.6 Panic Hoarder / Crisis Speculator

**Fiction**: Buys and sits on essentials, releases them at obscene prices.

**Market role**: Creates local spikes, makes scarcity feel human,
excellent event catalyst.

```lua
{
    archetype     = "speculator",
    reliability   = 0.35,  volatility  = 0.60,
    stockBias     = "hidden", priceBias = 0.35,
    refreshDays   = 2,      influence  = 3,
    secrecy       = 0.55,  rumorRate   = 0.25,
    riskTolerance = 0.70,
}
```

**Design note**: Do not spam. A few make the economy feel cruel; too many
make it feel silly.

### 4.7 Specialist Crafter

**Fiction**: Mechanic, radio technician, gunsmith, medic, machinist.

**Market role**: Converts junk into useful stock, buffers shortages in
narrow categories, keeps late-game supply believable.

```lua
{
    archetype     = "specialist_crafter",
    reliability   = 0.75,  volatility  = 0.30,
    stockBias     = "medium", priceBias = 0.10,
    refreshDays   = 2,      influence  = 2,
    secrecy       = 0.15,  rumorRate   = 0.08,
    riskTolerance = 0.45,
}
```

**Why this matters**: Allows the manufacturing vision (PCP tie-in) to
connect into the market without needing a full factory simulation.

---

## 5. Category Affinities

Use **weighted affinities**, not hard bans. A quartermaster might still
sometimes emit a radio quote, but rarely and weakly.

| Archetype | food | medicine | ammo | fuel | tools | radio | weapons |
|-----------|------|----------|------|------|-------|-------|---------|
| Scavenger Trader | 1.0 | 0.4 | 0.2 | 0.8 | 1.0 | 0.1 | 0.3 |
| Quartermaster | 1.0 | 0.7 | 0.2 | 0.5 | 0.6 | 0.1 | 0.1 |
| Wholesaler | 1.0 | 0.6 | 0.3 | 0.4 | 0.4 | 0.1 | 0.1 |
| Smuggler | 0.2 | 0.8 | 1.0 | 0.7 | 0.3 | 0.9 | 0.6 |
| Military Logistician | 0.2 | 0.8 | 1.0 | 0.9 | 0.3 | 0.9 | 0.5 |
| Speculator | 1.0 | 0.8 | 0.5 | 0.8 | 0.3 | 0.2 | 0.3 |
| Specialist Crafter | 0.1 | 0.5 | 0.6 | 0.2 | 1.0 | 0.7 | 0.4 |

---

## 6. Market Functions & Interaction Triangles

### Five Market Functions

| Function | Best Archetypes |
|----------|----------------|
| Baseline supply | Quartermaster, Wholesaler |
| Noise generation | Scavenger Trader, Smuggler |
| Shock generation | Speculator, Military Logistician |
| Recovery / buffering | Specialist Crafter, Quartermaster |
| Hidden markets | Smuggler, Military Logistician |

### Interaction Triangles

**Stable triangle** — Quartermaster stabilises, Wholesaler anchors,
Scavenger Trader adds noise.

**Conflict triangle** — Smuggler bypasses Wholesaler, Military distorts
access, Speculator weaponises shortages.

**Industrial triangle** — Specialist Crafter reduces dependence on raw
scavenging, Wholesaler supplies inputs, Smuggler fills forbidden gaps.

### Regional Composition Examples

**Small rural town**: 2 Scavenger Traders + 1 Quartermaster +
1 Specialist Crafter + rare Smuggler appearance.
Result: sparse but survivable, tools/food somewhat stable, ammo erratic.

**Louisville edge**: 2 Wholesalers + 2 Quartermasters + 2 Smugglers +
1 Speculator + 1 Military Logistician.
Result: deep but unstable, big swings, high-value intel opportunities.

**Military corridor**: 1 Military Logistician + 1 Smuggler +
1 Quartermaster + 1 Scavenger Trader.
Result: fuel/ammo/radio dominated, civilian essentials distorted.

---

## 7. Confidence Mapping

Archetypes feed directly into the existing confidence system
(see `market-exchange-design.md` § 5).

| Confidence Tier | Archetypes |
|-----------------|------------|
| Stronger base | Quartermaster, Wholesaler, Military Logistician |
| Medium-high (narrow) | Specialist Crafter (in specialty categories only) |
| Weaker base | Scavenger Trader, Smuggler, Speculator |

This makes the player naturally learn who to trust, who to cross-check,
and who to exploit.

---

## 8. Wholesaler System (Deep Design)

Wholesalers are the first **structural** market actor — they operate one
layer deeper than ordinary observations.

### Role Hierarchy

```
Scavengers    → create observations
Quartermasters → stabilise observations
Wholesalers   → shape the environment that observations emerge from
```

### Wholesaler Schema

```lua
Wholesaler = {
    id              = "wp_bulk_food_01",
    name            = "Knox Consolidated Supply",
    regionId        = "west_point",
    archetype       = "wholesaler",
    faction         = "civilian",
    active          = true,
    categoryWeights = { food = 1.0, medicine = 0.6, tools = 0.4, fuel = 0.3 },
    stockLevel      = 0.75,     -- 0.0–1.0 abstract bulk reserve
    throughput      = 0.60,     -- how quickly stock turns over
    resilience      = 0.70,     -- resistance to disruption
    visibility      = 0.35,     -- how obvious activity is to POSnet
    reliability     = 0.80,     -- truthfulness when observed
    influence       = 0.85,     -- impact on regional market state
    secrecy         = 0.20,     -- hidden stock / incomplete visibility
    markupBias      = -0.08,    -- bulk discount posture
    panicThreshold  = 0.25,     -- below this, behaviour changes
    dumpThreshold   = 0.90,     -- above this, may flood market
    convoyState     = {
        inTransit     = false,
        etaDay        = nil,
        cargoStrength = 0.0,
    },
    pressure        = 0.0,      -- current system stress
    disruption      = 0.0,      -- raids, failures, breakdowns
    lastUpdateDay   = 0,
}
```

### Design Principle: Abstract, Not Inventory-Perfect

Do NOT simulate exact crates or drum counts. Use abstract bulk state
(`stockLevel`, `pressure`, `disruption`, `throughput`, `categoryWeights`)
and derive market effects from those. Richness without unmaintainable
logistics.

### Wholesaler Subtypes

| Subtype | Strong Categories | Behaviour |
|---------|-------------------|-----------|
| Civilian Bulk Supplier | food 1.0, medicine 0.7, tools 0.6, fuel 0.4 | Low markup, conservative price increases, healthiest texture |
| Salvage Consolidator | tools 1.0, survival 0.8, radio 0.7, misc 0.6 | More erratic, stock fluctuates with scavenging ecology |
| Black-Market Broker | ammo 1.0, radio 0.9, medicine 0.8, fuel 0.7 | High secrecy, inconsistent confidence, strong local distortion |
| Military Surplus Node | ammo 1.0, fuel 0.9, radio 0.9, medicine 0.8 | Huge influence, low visibility, may cause civilian shortages by diversion |

### Six Wholesaler Jobs

1. **Anchor regional category supply** — push category baselines up/down
2. **Propagate delayed shocks** — day 1: faint rumours → day 2: lower
   stock → day 3+: prices rise, confidence falls (the delay is what
   makes it feel alive)
3. **Emit high-consequence market events** — bulk arrival, convoy loss,
   warehouse fire, controlled release, withholding, requisition
4. **Generate trader ecology downstream** — bias nearby scavengers,
   quartermasters, and smugglers (influence, not ownership)
5. **Create reportable intelligence** — patterns the player can notice
   (regional abundance, shortage cascades, unusual prices)
6. **Feed missions** (future) — supply runs, convoy tracking, warehouse
   recon, broker contacts, contract deliveries, interceptions

### Operational States

| State | Effect |
|-------|--------|
| **Stable** | Mild discounts, healthy stock posture, fewer rumours |
| **Tight** | Prices edge up, medium increase in low-stock reports, difficulty rumours begin |
| **Strained** | Clear upward bias, downstream traders show reduced stock, confidence weakens |
| **Dumping** | Lower prices, sudden high-stock reports, market sentiment softens |
| **Withholding** | Prices rise despite stock existing, rumours conflict with availability |
| **Collapsing** | Very strong scarcity signal, downstream stock craters, delayed shock waves |

### Downstream Influence

| Target Archetype | Wholesaler Stable | Wholesaler Collapsing | Wholesaler Withholding |
|------------------|-------------------|-----------------------|------------------------|
| Scavenger Trader | More medium-stock reports | More low-stock opportunism | Mixed signals |
| Quartermaster | Tighter, calmer pricing | Strain rises (delayed) | Gradually tightens |
| Smuggler | Normal margins | Opportunity rises | Opportunity rises sharply |
| Speculator | Low activity | Hoarding chance increases | Exploits information gap |

### 8.8 Broadcast Influence on Wholesaler Behaviour

When the Tier IV Broadcast Influence system is active (see
`broadcast-influence-design.md` §3.2), satellite broadcasts can nudge
wholesaler behavioural posture without directly forcing inventory actions.

Broadcast influence is a **weighted nudge**, not a hard state rewrite:

- A high-confidence **scarcity alert** on ammunition might cause a military
  wholesaler to shift toward `hold`/`accumulate`, a black-market broker
  toward `conceal`, and a speculator toward `probe`.
- A **surplus notice** on crops might cause an agricultural wholesaler to
  `dump`, a speculator to `hold`, and a smuggler to ignore the broadcast.

The key distinction: Tier IV does not tell wholesalers what *is* true.
It changes how they *behave toward what seems true*.

---

## 9. Supply Pressure System

The most important hidden value — regional pressure per category, driven
partly by wholesalers.

### Mental Model

```
high stock + low disruption   = negative pressure = calmer prices
low stock + high disruption   = positive pressure = scarcity
strong throughput             = faster recovery
high visibility              = easier intel confidence
high secrecy                 = weaker confidence, noisier market
```

### Pressure Formula (Conceptual)

```
regionalPressure =
    scarcityPressure
  + disruptionPressure
  + demandPressure
  - stockBuffer
  - throughputBuffer
```

Per-wholesaler contribution:

```
contribution =
    influence
  × categoryWeight
  × (disruption + pressure - stockLevel - throughput × 0.5)
```

Clamped to a sane range. This lets a powerful wholesaler calm a category,
mildly distort it, or catastrophically destabilise it.

---

## 10. Simulation Tick

### Architecture

Server-side tick runs every 10–30 in-game minutes (sandbox-configurable).

### Per-Tick Flow

1. **Agent reads zone state** — baseline prices, current scarcity, recent
   event modifiers, faction conditions
2. **Archetype posture applied** — markup/discount, volatility roll, stock
   bias, secrecy/reliability
3. **Outputs emitted** — one or more observations, optional rumour,
   optional zone influence change
4. **Wholesaler lifecycle** (see § 10.1)
5. **Events may trigger** (see § 11)
6. **Prices update** via `POS_PriceEngine` integration

### 10.1 Wholesaler Lifecycle (Per Tick)

| Phase | Action |
|-------|--------|
| Natural drift | Stock rises/falls slightly; pressure eases/worsens; disruption decays unless reinforced |
| Demand pull | Essential categories (food, medicine, fuel) steadily erode stock unless replenished |
| Event roll | Chance for convoy arrival, delay, theft, requisition, spoilage, dump, broker opportunism |
| Market influence | Wholesaler modifies regional category pressure |
| Signal emission | Optional generation of observation packets, rumours, bulletins, delivery hooks |

---

## 11. Event System

> **Implementation**: Event definitions are data-only Lua files in
> `Definitions/Events/`, validated by `POS_EventSchema.lua`.

Events plug into the simulation tick and make the market feel alive.

### Starting Event Set (6 Events)

| Event | Effect |
|-------|--------|
| **Bulk Arrival** | Stock rises, pressure falls, downstream stock improves |
| **Convoy Delay** | Stock does not refill, rumours begin, pressure slowly rises |
| **Theft / Raid** | Disruption spikes, stock drops, confidence becomes noisy |
| **Controlled Release** | Temporary discount posture, stronger medium/high stock signals |
| **Strategic Withholding** | Pressure rises despite reserve, rumours conflict, black market strengthens |
| **Requisition / Diversion** | Military/factional redirection, civilian categories tighten sharply |

### Advanced Events (Future)

- **Supply Shock** — warehouse looted, zone impact (e.g. food −80)
- **Military Supply Drop** — ammo surge in zone
- **Panic Buying** — demand spikes randomly (50–200)
- **Trade Convoy** — agents physically move goods between zones over time

---

## 12. Observation Generation

Agents should NOT directly write UI data. Each archetype generates
observations in the same shape the existing market system understands
(see `market-exchange-design.md` § 4 for record schema).

### Example

```lua
{
    id          = "obs_123",
    categoryId  = "medicine",
    source      = "Knox Consolidated Supply",
    location    = "West Point",
    price       = 48.00,
    stock       = "medium",
    recordedDay = 23,
    confidence  = "medium",
    sourceTier  = POS_Constants.SOURCE_TIER_BROADCAST,
    quality     = 72,
}
```

The simulation layer becomes a **producer of familiar inputs** rather than
a rewrite of the architecture.

### Signal Types

| Class | Description | Destination |
|-------|-------------|-------------|
| **Hard signals** | Proper market observations (broadcasts, trader quotes) | `POS_MarketDatabase` |
| **Soft signals** | Rumours, bulletins, weak reports. Affect confidence and flavour. | Field notes / BBS |
| **Structural signals** | Invisible modifiers — bias scavenger stock claims, smuggler activity levels | Simulation state only |

---

## 13. Intelligence Quality (SIGINT Tie-In)

Connects directly to the SIGINT skill system
(see `sigint-skill-design.md`).

| Skill Level | Effect |
|-------------|--------|
| Low | Old, noisy, incomplete data |
| Mid | Better averaging, more consistent |
| High | Detect trends, spot manipulation |

### Layer A Upgrade

`POS_MarketReconAction` evolves from "generate data" to "sample reality":

```lua
function gatherMarketIntel(zone)
    return sample(zone.currentPrices, noise, bias)
end
```

With noise (inaccuracy), bias (agent reliability), and partial visibility.

---

## 14. Performance & Storage

### Data Partitioning

| Data Type | Storage |
|-----------|---------|
| Simulation state (zones, agents, wholesalers) | Server memory (world modData) |
| Player intel (observations, reports) | Player modData |
| History (price trends, rolling closes) | File-backed (`POS_MarketFileStore`) |

### Persistence

- `POS_WorldState` already provides 6 named containers — wholesaler data
  fits naturally into a new container (`WMD_WHOLESALERS`)
- Rolling window caps from `market-exchange-design.md` § 13 apply
  (MAX_OBSERVATIONS_PER_CATEGORY: 24, MAX_ROLLING_CLOSES: 14)

### ModData Store Iteration Safety

When counting or iterating records in a ModData store that uses an
`.entries` sub-table (e.g. wholesalers, zones), always guard with
`v.id` or an equivalent record-specific field check. The `.entries`
table itself passes `type(v) == "table"` and will cause false positives
in count checks.

```lua
-- WRONG: counts .entries metadata table as a record
for _, v in pairs(store) do
    if type(v) == "table" then count = count + 1 end
end

-- CORRECT: only counts actual records with an id field
for _, v in pairs(store) do
    if type(v) == "table" and v.id then count = count + 1 end
end
```

---

## 15. Integration Points (Existing Modules)

| Module | Change |
|--------|--------|
| `POS_MarketBroadcaster` (server) | Add simulation tick trigger; broadcast economic changes from agents |
| `POS_MarketDatabase` | Keep storing only observations — NOT wholesaler truth |
| `POS_MarketIngestion` | Change from "generate data" to "sample reality" |
| `POS_PriceEngine` | Add regional wholesaler pressure bias into drift calculation |
| `POS_ExchangeEngine` | Consume agent-generated observations for richer index data |
| `POS_WorldState` | Add `getWholesalers()` / `getMarketZones()` containers |
| `POS_MarketService` | Remains read-only facade — no changes to API contract |
| `POS_CrossModMarkets` | Remains unchanged — category registration still works |

### New Modules Required

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_MarketSimulation` | Shared | Agent registry, zone state, tick orchestration |
| `POS_WholesalerService` | Shared | Wholesaler lifecycle, pressure contribution, signal generation |
| `POS_EconomyTick` | Server | Server-side tick driver, calls MarketSimulation + WholesalerService |

---

## 16. Emergent Gameplay (Unlocked By This System)

Once autonomous simulation is in place, the following gameplay emerges
naturally:

- **Arbitrage** — buy low in one zone, sell high in another
- **Smuggling routes** — contraband flows through hidden channels
- **Information trading** — intel becomes a commodity itself
- **Market manipulation** — player actions influence price drift
- **Regional collapse economies** — zone failure cascades
- **Convoy tracking** — intercept supply lines for missions

---

## 17. Implementation Phasing

### Phase 0 — Scaffolding ✅

Data-pack architecture implemented: 4 schema files, 15 definition files,
4 templates, 3 stub modules (`POS_MarketAgent`, `POS_WholesalerService`,
`POS_MarketSimulation`), sandbox gate, translation keys, economy tick hook
(commented out). Living Market is always active (the `EnableLivingMarket` sandbox gate was removed). PhobosLib
provides `PhobosLib_Schema`, `PhobosLib_Registry`, and `PhobosLib_DataLoader`.

### Phase 1 — Foundation (3 Archetypes) ✅

Implement: Scavenger Trader, Quartermaster, Wholesaler.
Result: noise, stability, regional backbone.

Implemented: 8 wholesaler definitions (scaled by zone population),
6-state operational state machine, supply pressure formula, 6-phase
wholesaler tick lifecycle (natural drift, demand pull, convoy resolution,
event roll, market influence, signal emission placeholder), zone pressure
aggregation, agent hidden state meter updates, hybrid persistence.
`PhobosLib.approach()` added for natural drift smoothing.

### Phase 2 — Tension (2 Archetypes)

Add: Smuggler, Military Logistician.
Result: secrecy, strategic distortion.

### Phase 3 — Depth (2 Archetypes)

Add: Speculator, Specialist Crafter.
Result: crisis behaviour, long-tail recovery.

### Phase 4 — Events & Delivery Integration

Connect wholesaler events to mission system. Supply runs, convoy
tracking, warehouse recon, broker contact establishment.

---

## 18. Anti-Patterns (What NOT To Do)

1. **Do not make every archetype trade everything** — category affinities
   must be weighted.
2. **Do not make smugglers pure random chaos** — risky, not clownish.
3. **Do not make military actors constant price fountains** — sparse,
   powerful, partially opaque.
4. **Do not fully expose archetype names to the player at first** — let
   identity emerge through repeated observation and report style.
5. **Do not begin with exact crate inventories** — abstract bulk state.
6. **Do not implement routefinding convoys** — abstract transit state.
7. **Do not build direct player-wholesaler UI** — wholesalers are
   invisible infrastructure, felt through market effects.
8. **Do not simulate wholesaler-to-wholesaler commerce** — unnecessary
   for Phase 1.

---

## 19. Design Insight

> These archetypes should not merely differ by price.
> They should differ by **relationship to truth**.
>
> - Some actors know more than they say
> - Some say more than they know
> - Some stabilise, some distort
> - Some conceal, some reveal
>
> That is what makes them feel like POSnet agents rather than generic
> market NPCs — and it is fertile ground for the broader SIGINT vision.

---

## 20. Implementation Status

**All phases complete as of v0.17.0.** The Living Market Layer 0 is fully
implemented, including the trading system (Phase 8) and ambient market
intelligence (`POS_AmbientIntel.lua`).

### 20.1 Module Dependency Graph

```
POS_Constants
    ├── POS_ArchetypeSchema ──── POS_MarketAgent
    ├── POS_ZoneSchema    ──┐
    ├── POS_EventSchema   ──┼── POS_MarketSimulation ──── POS_EconomyTick (Phase 5.75)
    └── POS_WholesalerSchema ─── POS_WholesalerService ──┘
                                        ↑
                                 POS_MarketSimulation
                                        ↑
                                  POS_WorldState
                                  (getWholesalers, getMarketZones, getRumours)

Active connections:
    POS_MarketSimulation ──→ POS_MarketIngestion ──→ POS_MarketDatabase
    POS_MarketSimulation ──→ POS_PriceEngine
    POS_MarketSimulation ──→ POS_MarketNoteGenerator
    POS_TradeService ──→ POS_WorldState (wholesaler stock)
    POS_TradeService ──→ POS_PriceEngine (buy prices)
    POS_TradeService ──→ POS_ItemPool (category items, base prices)
    POS_TradeService ──→ POS_WholesalerService (state resolution)
    POS_TradeService ──→ PhobosLib (inventory, money, notifications)
    POS_MarketReconAction ──→ POS_MarketSimulation.getZonePressure()
    POS_MarketAgent ──→ POS_MarketIngestion (agent observations)
    POS_WholesalerService ──→ POS_MarketAgent (downstream influence)
```

### 20.2 Key Engine Modules

| Module | Description |
|---|---|
| `POS_MarketSimulation.lua` | Orchestrator: init, tick, zone state, agent registry, wholesaler spawning |
| `POS_WholesalerService.lua` | Wholesaler factory, 6-phase tick lifecycle, state machine, pressure formula |
| `POS_MarketAgent.lua` | Agent factory, archetype registry, observation generation |
| `POS_TradeService.lua` | Trading business logic: query, validate, execute buy/sell |
| `POS_AmbientIntel.lua` | Passive market observations on EveryOneMinute tick |
| `POS_WorldState.lua` | ModData accessors for wholesalers, zones, rumours |
| `POS_EconomyTick.lua` | Phase 5.75 server tick hook |

Definition files live under `common/media/lua/shared/Definitions/` in four
subdirectories: `Archetypes/` (7), `Zones/` (6), `Events/` (6),
`Wholesalers/` (8). Each has a `_template.lua` reference file.

### 20.3 Known Gaps & Future Work

- **Integration testing**: End-to-end testing of the full pipeline across all
  phases is still required.
- **Balance tuning**: Simulation parameters (tick rates, pressure clamps, XP
  multipliers, noise ranges) will require adjustment based on real gameplay data.
- **Satellite passive collection**: Background passive-collection mode (idle /
  passive / deep sweep) not yet implemented. See `satellite-uplink-design.md`
  §24.
