# Living Market — Implementation Status & Roadmap

> Last updated: 2026-03-22
> Design reference: `docs/living-market-design.md`
> Architecture rules: `docs/design-guidelines.md` §24, §26, §27

---

## Overview

The Living Market is **Layer 0: World Economy** — an autonomous economic simulation that runs beneath the existing three-layer POSnet architecture (Field Intel → POSnet Aggregation → Terminal UI). It transforms the market system from a reactive reporting tool ("player creates data") into a living world the player intercepts ("world produces data, player samples it").

The simulation is driven by **market agents** (invisible economic personalities in 7 archetypes), **wholesalers** (structural actors that shape the environment agents operate in), and **market zones** (6 geographically fractured economic regions). A server-side tick updates wholesaler lifecycles, aggregates zone pressure, and updates agent hidden-state meters each in-game day. Everything is gated behind `POS.EnableLivingMarket` (sandbox, default OFF).

---

## Implementation Status

### Phase 1: Infrastructure (Complete)

Everything in this phase is fully implemented, tested, and live in the codebase.

**Constants (`POS_Constants.lua`)**

- All 7 agent archetype IDs (`AGENT_ARCHETYPE_*`)
- All 6 wholesaler operational state enums (`WHOLESALER_STATE_*`)
- All 6 market zone IDs (`MARKET_ZONE_*`) + `MARKET_ZONES` ordered array
- All 6 market event IDs (`MARKET_EVENT_*`)
- All 3 signal class enums (`SIGNAL_CLASS_HARD/SOFT/STRUCTURAL`)
- Full simulation parameter defaults: tick interval (20 min), pressure clamp (−2.0/+2.0), throughput factor (0.5), zone default volatility (0.20), decay rates, replenish rate, demand pull multipliers by population tier, essential categories list, event probability multiplier, per-wholesaler stock/pressure/disruption clamp bounds, state threshold values, downstream delay days, agent meter approach rates
- World ModData keys: `WMD_WHOLESALERS = "POSNET.Wholesalers"`, `WMD_MARKET_ZONES = "POSNET.MarketZones"`

**Data-Pack Architecture**

4 schema files, each alongside the module that consumes it:

| Schema file | Validates |
|---|---|
| `POS_ArchetypeSchema.lua` | Archetype definition files |
| `POS_ZoneSchema.lua` | Zone definition files |
| `POS_EventSchema.lua` | Event definition files |
| `POS_WholesalerSchema.lua` | Wholesaler definition files |

23 definition files across 4 subdirectories (all built-in; `_template.lua` files never loaded):

- `Definitions/Archetypes/` — 7 definitions: `scavenger_trader`, `quartermaster`, `wholesaler`, `smuggler`, `military_logistician`, `speculator`, `specialist_crafter` (+ `_template.lua`)
- `Definitions/Zones/` — 6 definitions: `muldraugh`, `west_point`, `riverside`, `louisville_edge`, `military_corridor`, `rural_east` (+ `_template.lua`)
- `Definitions/Events/` — 6 definitions: `bulk_arrival`, `convoy_delay`, `theft_raid`, `controlled_release`, `strategic_withholding`, `requisition_diversion` (+ `_template.lua`)
- `Definitions/Wholesalers/` — 8 definitions: `muldraugh_general`, `west_point_consolidated`, `riverside_supply`, `louisville_arms`, `louisville_medical`, `military_depot`, `military_field_hospital`, `rural_east_salvage` (+ `_template.lua`)

All definitions loaded via `PhobosLib.loadDefinitions()` + `PhobosLib.createRegistry()`. Invalid definitions are rejected with actionable error messages (§26.7).

**Sandbox Options**

| Option | Type | Default | Range |
|---|---|---|---|
| `POS.EnableLivingMarket` | boolean | false | — |
| `POS.SimulationTickInterval` | integer | 20 | 5–120 |
| `POS.MarketFileChunkSize` | integer | 4 | 1–20 |

Note: `MarketFileChunkSize` is shared with general file-store chunking, not Living Market-specific.

**Sandbox Accessors (`POS_SandboxIntegration.lua`)**

- `POS_Sandbox.isLivingMarketEnabled()` — returns boolean
- `POS_Sandbox.getSimulationTickInterval()` — returns integer (game minutes)

**Translation Keys (32 keys)**

- 7 agent archetype display names: `UI_POS_Agent_ScavengerTrader`, `..._Quartermaster`, `..._Wholesaler`, `..._Smuggler`, `..._MilitaryLogistician`, `..._Speculator`, `..._SpecialistCrafter`
- 6 market zone names: `UI_POS_Zone_Muldraugh`, `..._WestPoint`, `..._Riverside`, `..._LouisvilleEdge`, `..._MilitaryCorridor`, `..._RuralEast`
- 6 wholesaler state names: `UI_POS_Wholesaler_State_Stable`, `..._Tight`, `..._Strained`, `..._Dumping`, `..._Withholding`, `..._Collapsing`
- 6 market event names: `UI_POS_MarketEvent_BulkArrival`, `..._ConvoyDelay`, `..._TheftRaid`, `..._ControlledRelease`, `..._Withholding`, `..._Requisition`
- 3 signal class names: `UI_POS_Signal_Hard`, `..._Soft`, `..._Structural`
- 4 signal strength labels: `UI_POS_Signal_Critical`, `..._Excellent`, `..._Good`, `..._Weak`

**Economy Tick Hook (`POS_EconomyTick.lua`)**

Phase 5.75 in `processDayTick()` calls `POS_MarketSimulation.tickSimulation(currentDay)` wrapped in `PhobosLib.safecall()`, gated behind `POS_Sandbox.isLivingMarketEnabled()`. Runs once per in-game day (the broader tick is driven by `EveryOneMinute`).

**World State Accessors (`POS_WorldState.lua`)**

- `POS_WorldState.getWholesalers()` — returns/creates `ModData["POSNET.Wholesalers"]`
- `POS_WorldState.getMarketZones()` — returns/creates `ModData["POSNET.MarketZones"]`
- Both called during world reset/wipe to include Living Market data in the cleanup path

**Simulation Modules — Core Logic (Complete)**

`POS_MarketSimulation.lua`:
- `init()` — idempotent loader: archetypes, zones, events, wholesalers; pre-creates zone state cache
- `getZoneRegistry()`, `getEventRegistry()` — addon-mod entry points
- `registerAgent()`, `getAgentsForZone()` — runtime agent management
- `getZoneState()`, `getZonePressure()` — live zone reads
- `_getWholesalerStore()` — bridge to `POS_WorldState`
- `_spawnWholesalers()` — first-tick bootstrap from registry definitions
- `_updateAgentMeters()` (internal) — updates all 5 hidden-state meters per agent using zone conditions and `PhobosLib.approach()`
- `tickSimulation()` — full orchestration: spawn check → tick all wholesalers → aggregate zone pressure → update agent meters → persist zone states to ModData
- `getZoneDisplayName()`, `getEventDisplayName()` — registry-backed display name accessors

`POS_WholesalerService.lua`:
- `createWholesaler()` — factory with sensible defaults
- `createFromRegistry()` — create from a registered definition ID
- `getRegistry()` — addon-mod entry point
- `resolveOperationalState()` — 6-state machine, first-match logic against thresholds from constants
- `computePressureContribution()` — per-category formula: `influence × categoryWeight × (disruption + pressure − stockLevel − throughput × factor)`, clamped
- `tickWholesaler()` — full 6-phase lifecycle per wholesaler: natural drift (approach 0), demand pull (population-tier erosion), convoy resolution (arrival boost/overdue block), event roll (probability check against all event definitions), market influence (compute `_lastContributions`), signal emission (placeholder)
- `_applyEvent()` (internal) — applies pressure/stock/disruption effects from event definition + `EVENT_EFFECTS` map
- `getDownstreamInfluence()` — `DOWNSTREAM_PROFILES[state][archetype]` lookup returning `{stockBias, priceBias, opportunity, strainDelay}`
- `getStateDisplayName()` — translation-key-backed accessor

`POS_MarketAgent.lua`:
- `init()` — loads built-in archetype definitions
- `getRegistry()` — addon-mod entry point
- `createAgent()` — factory: copies tuning from archetype definition, initialises 5 hidden meters to 0
- `getProfile()`, `getAffinityWeight()` — archetype accessors
- `getDisplayName()` — registry-backed accessor

**Documentation**

- `design-guidelines.md` §24 (Living Market rules), §26 (Data-Pack Architecture), §27 (Init-Time Performance)
- `living-market-design.md` — full design specification

---

### Phase 2: Archetype Definitions (Complete)

All 7 built-in archetype definitions are now written and loaded via the data-pack architecture.

| Archetype | File | Status |
|---|---|---|
| `scavenger_trader` | `Definitions/Archetypes/scavenger_trader.lua` | ✅ Complete |
| `quartermaster` | `Definitions/Archetypes/quartermaster.lua` | ✅ Complete |
| `wholesaler` | `Definitions/Archetypes/wholesaler.lua` | ✅ Complete |
| `smuggler` | `Definitions/Archetypes/smuggler.lua` | ✅ Complete |
| `military_logistician` | `Definitions/Archetypes/military_logistician.lua` | ✅ Complete |
| `speculator` | `Definitions/Archetypes/speculator.lua` | ✅ Complete |
| `specialist_crafter` | `Definitions/Archetypes/specialist_crafter.lua` | ✅ Complete |

Tuning values follow `living-market-design.md` §4 and the category affinity table in §5. All downstream influence profiles are present in `POS_WholesalerService.DOWNSTREAM_PROFILES`.

---

### Phase 3: Signal Emission (Complete)

**3A. Hard Signal Emission** — ✅ Complete

`POS_WholesalerService.emitSignals()` now generates observation records per category for each wholesaler during Phase 6 of `tickWholesaler()`. Implementation follows the Signal Emission Rules in `design-guidelines.md` §24.10:

- Visibility gate: `PhobosLib.randFloat(0, 1) > wholesaler.visibility` skips high-secrecy wholesalers probabilistically
- Price formula: `CATEGORY_BASE_PRICE[catId] * (1 + markupBias) * WHOLESALER_PRICE_MULTIPLIER[state] * (1 +/- SIGNAL_PRICE_NOISE)`
- Stock bucketing via `PhobosLib.getQualityTier()` with `STOCK_LEVEL_TIERS` (abundant/moderate/low/scarce)
- Confidence mapping via `PhobosLib.getQualityTier()` with `CONFIDENCE_TIERS` (high/medium/low)
- Display names resolved via `PhobosLib.getRegistryDisplayName()` — all definitions have `displayNameKey`
- Cross-mod base prices: `CATEGORY_BASE_PRICE` includes PCP (chemicals/agriculture/biofuel) and PIP (specimens/biohazard) categories
- All observations tagged with `POS_Constants.SOURCE_TIER_BROADCAST`
- Records injected via `POS_MarketIngestion.ingestObservation()`

**3B. Soft Signal Emission (Rumours)** — ✅ Complete

Soft-class events in `tickWholesaler()` Phase 4 now generate rumour records stored in world ModData via `POS_WorldState.getRumours()`. Rumours expire after `RUMOUR_EXPIRY_DAYS` (7) and are capped at `RUMOUR_MAX_ACTIVE` (20). Impact hints are derived from the event's `pressureEffect` sign; confidence is always `"low"`. The BBS screen displays active rumours with region, category, duration, and impact hint. Hard-class events do not generate rumours. See `design-guidelines.md` §24.11 for the full rule set.

**3C. Structural Signals** — ✅ Complete (implicit)
- These are invisible — they bias downstream agent behaviour rather than producing UI records
- `getDownstreamInfluence()` is called during agent observation generation (Phase 4B) to modify quote reliability and stock claim biases

**3D. PriceEngine Integration** — ✅ Complete

Zone pressure from the Living Market simulation biases the S/D factor in `POS_PriceEngine.generatePrice()`. Two new constants govern the effect: `PRICE_ZONE_PRESSURE_WEIGHT = 0.05` and `PRICE_ZONE_PRESSURE_CLAMP = 0.10`. The bias is additive to `sdFactor`, clamped to ±0.10, and gated behind `EnableLivingMarket`. Callers pass `ctx.zoneId`; `nil` gracefully skips the pressure term. See `design-guidelines.md` §24.10 for the full rule set.

---

### Phase 4: Agent Observation Generation (Complete)

Agent hidden-state meters (pressure, greed, exposure, surplus, trustShift) now drive actual observation output through the full agent observation pipeline.

**4A. Per-Agent Observation Generator** — ✅ Complete

`POS_MarketAgent.generateObservations(agent, zoneState, currentDay)` iterates agent categories weighted by affinity, generating 0–N observations per tick gated by `refreshDays` and probability roll. Observation quality/reliability is adjusted by hidden meters: high `greed` inflates price, high `exposure` reduces confidence, high `surplus` lowers price bias and raises stock claims, non-zero `trustShift` applies a temporary reliability modifier. Archetype-specific behaviours: smugglers apply confidence penalty with occasional ghost stock inversion; speculators exaggerate price with hidden stock bias; specialist crafters only observe high-affinity categories; scavengers add extra noise. All observations use `SOURCE_TIER_FIELD` with `"agent_"` prefix. See `design-guidelines.md` §24.12 for the full rule set.

**4B. Downstream Influence Application** — ✅ Complete

Before generating observations, the system looks up all wholesalers in the same zone and calls `POS_WholesalerService.getDownstreamInfluence(wholesaler, agent.archetype)` for each. The weighted sum of `stockBias` and `priceBias` modifiers is applied to agent observation parameters. `strainDelay` is respected — effects from state changes propagate with a day lag.

---

### Phase 5: Persistence & Save Safety (Complete)

All persistence and save safety components are fully implemented.

- `POS_WorldState.getWholesalers()` and `getMarketZones()` provide ModData containers
- `tickSimulation()` persists zone pressure snapshots to `WMD_MARKET_ZONES` each tick
- Wholesaler runtime state (including `stockLevel`, `pressure`, `disruption`, `_operationalState`) lives in `WMD_WHOLESALERS` via `_getWholesalerStore()`
- World reset/wipe clears both containers

**5A. Load Restoration** — ✅ Complete

On world load, wholesalers are restored from `WMD_WHOLESALERS` ModData. `_spawnWholesalers()` only runs if the store is empty. A migration/revalidation pass on load checks `schemaVersion` and rebuilds missing fields from current definition defaults.

**5B. Zone State Load** — ✅ Complete

`_ensureZoneState()` checks `WMD_MARKET_ZONES` ModData first and restores saved zone state if available. Zone pressure snapshots survive world load/save cycles, consistent with wholesaler state persistence.

**5C. Save Migration Path** — ✅ Complete

Schema evolution is handled via `schemaVersion` field in saved state with a migration function called during `_spawnWholesalers()` and zone restore. When wholesaler or zone definition schemas evolve, existing saves are migrated to the current schema on load.

---

### Phase 6: Terminal UI Integration (Complete)

The Living Market simulation state is now exposed to the player through the intelligence pipeline via three terminal screens.

**Screens implemented:**

| Screen | Purpose | Status |
|---|---|---|
| Market Zone Overview | Shows all 6 zones with aggregated pressure per category (colour-coded), active wholesaler count, volatility indicator | ✅ Complete |
| Wholesaler Directory | Lists active wholesalers with current operational state, zone, and stock level (visibility-gated — high-secrecy wholesalers are obscured) | ✅ Complete |
| Market Event Log | Recent market events with signal classification, zone, affected categories, day | ✅ Complete |

**Price integration:**
- `POS_Screen_Markets.lua` and `POS_Screen_Stockmarket.lua` show prices from `POS_MarketDatabase`
- Living Market observations flow through the same database — prices update without UI changes
- Zone pressure annotates category rows with a trend indicator (rising/falling)

Wholesaler identity is not exposed directly. Players infer existence through repeated observation patterns. The Wholesaler Directory is an advanced intel screen, gated behind SIGINT skill tier or camera/satellite analysis.

---

### Phase 7: SIGINT & Intel Pipeline Integration (Complete)

The Living Market's events are fully connected to the intelligence collection pipeline. See `design-guidelines.md` §24.13 for the full rule set.

**7A. Passive Recon Integration** — ✅ Complete

`POS_MarketReconAction` samples `getZonePressure()` with SIGINT-scaled noise. Low skill produces noisy readings (high variance); high skill produces accurate readings and can detect trends by comparing current tick pressure to rolling average.

**7B. SIGINT XP from Market Events** — ✅ Complete

When a soft-class market event fires and the player has active passive recon in that zone, SIGINT XP is awarded. XP is scaled by wholesaler operational state: Collapsing/Dumping award full XP, Strained/Withholding reduced, Tight minimal, Stable none. Gated behind `POS_Sandbox.isLivingMarketEnabled()`.

**7C. Field Notes from Significant Shifts** — ✅ Complete

When a wholesaler transitions into Collapsing or Dumping state, a field note is generated via `POS_MarketNoteGenerator`. Notes describe zone and affected categories in vague terms (no numerical values). Cooldown: once per in-game day per wholesaler to prevent note spam.

**7D. Camera/Satellite Intel** — ✅ Complete

Camera-tier analysis of a zone produces a per-category pressure breakdown with trend indicators (rising/falling/stable). Satellite-tier broadcast propagates zone state summaries to all connected POSnet terminals, showing the aggregate picture across all zones.

---

### Phase 8: Trading System (Complete)

A standalone trading system allows players to buy and sell physical items
directly through wholesalers via the POSnet terminal. All business logic
lives in `POS_TradeService` (shared); four new terminal screens handle
presentation. See `design-guidelines.md` §30 for the full rule set.

**Service Layer (`POS_TradeService.lua`)** — Complete

- `getTradeableWholesalers(player)` — returns wholesalers with at least one
  trade direction open, sorted by region
- `getBuyableItems(wholesalerId, categoryId, player)` — items available for
  purchase with computed buy/sell prices and stock indicators
- `getSellableItems(wholesalerId, categoryId, player)` — player inventory
  items matching a wholesaler's categories with sell prices
- `computeBuyPrice(fullType, categoryId, wholesaler, player)` — formula:
  `basePrice * stateMultiplier * (1 + markupBias)`, with extra dumping
  discount
- `computeSellPrice(fullType, categoryId, wholesaler, player)` — `buyPrice
  * SellPriceRatio` (sandbox-configurable)
- `computeBulkDiscount(quantity)` — threshold + percent from sandbox options
- `validateBuy` / `validateSell` — state gates, stock checks, affordability,
  quantity caps
- `executeBuy` / `executeSell` — atomic transactions with rollback on
  failure; adjusts wholesaler stock, re-evaluates operational state, awards
  SIGINT XP, sends PN notifications

**Terminal Screens** — Complete

| Screen | File | Purpose |
|---|---|---|
| Trade Terminal | `POS_Screen_TradeTerminal.lua` | Paginated wholesaler list; gated behind Living Market + SIGINT level |
| Trade Catalog | `POS_Screen_TradeCatalog.lua` | Category browser, paginated item list with BUY/SELL mode toggle |
| Trade Confirm | `POS_Screen_TradeConfirm.lua` | Quantity picker, price preview, bulk discount display, execute button |
| Trade Receipt | `POS_Screen_TradeReceipt.lua` | Static transaction summary (items, cost/revenue, new balance) |

**Key design decisions:**

- Screens are presentation only — all inventory/money mutations happen in
  `POS_TradeService` (§30.7 anti-patterns)
- Buy depletes wholesaler stock; sell replenishes it — creating a feedback
  loop with the Living Market simulation
- State gates: Withholding blocks buys, Collapsing blocks all trade,
  Dumping adds extra discount
- SIGINT skill gates access to the Trade Terminal (intel advantage)
- Bulk discount threshold and percent are sandbox-configurable
- Transactions award SIGINT XP with a bonus for bulk orders

---

## Module Dependency Graph

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

---

## Implementation Priority Matrix

| Component | Complexity | Depends On | Suggested Order |
|---|---|---|---|
| ~~Remaining archetype definitions (Phase 2)~~ | ~~Low~~ | — | ✅ Complete |
| ~~Zone state load restoration (Phase 5B)~~ | ~~Low~~ | — | ✅ Complete |
| ~~Hard signal emission (Phase 3A)~~ | ~~Medium~~ | — | ✅ Complete |
| ~~PriceEngine pressure bias (Phase 3D)~~ | ~~Medium~~ | ~~Phase 3A schema work~~ | ✅ Complete |
| ~~Soft signal / rumour emission (Phase 3B)~~ | ~~Medium~~ | ~~Phase 3A done, note generator~~ | ✅ Complete |
| ~~Per-agent observation generator (Phase 4A)~~ | ~~High~~ | ~~Phase 3A, archetype definitions~~ | ✅ Complete |
| ~~Downstream influence application (Phase 4B)~~ | ~~Medium~~ | ~~Phase 4A~~ | ✅ Complete |
| ~~Save migration path (Phase 5C)~~ | ~~Medium~~ | ~~Phase 5A done~~ | ✅ Complete |
| ~~Terminal UI: Zone Overview screen (Phase 6)~~ | ~~High~~ | ~~Phase 3 producing real data~~ | ✅ Complete |
| ~~Terminal UI: Event Log screen (Phase 6)~~ | ~~Medium~~ | ~~Phase 3 producing events~~ | ✅ Complete |
| ~~Terminal UI: Wholesaler Directory (Phase 6)~~ | ~~High~~ | ~~Phase 6 Zone Overview, SIGINT gating~~ | ✅ Complete |
| ~~Passive recon SIGINT integration (Phase 7A)~~ | ~~Medium~~ | ~~Phase 3, SIGINT skill system~~ | ✅ Complete |
| ~~SIGINT XP from market events (Phase 7B)~~ | ~~Low~~ | ~~Phase 3A signals firing~~ | ✅ Complete |
| ~~Field notes from state transitions (Phase 7C)~~ | ~~Low~~ | ~~Phase 3 + POS_MarketNoteGenerator~~ | ✅ Complete |
| ~~Camera/satellite intel tier (Phase 7D)~~ | ~~High~~ | ~~Camera/satellite systems~~ | ✅ Complete |

**Current state:** All phases complete. Living Market Layer 0 is fully implemented, including the standalone trading system (Phase 8).

**Ambient Market Intelligence** (added post-Phase 8): A passive data source
(`POS_AmbientIntel.lua`) now complements the Living Market simulation by
generating low-confidence market observations when the player is connected to
a POSnet terminal. This provides a baseline trickle of market awareness
without requiring any recon equipment, ensuring players always have some
signal to act on while incentivising active collection for higher-quality
data. See `design-guidelines.md` §24.14 for the full rule set.

---

## File Reference

### Engine Modules (Shared)

| File | Status | Description |
|---|---|---|
| `common/media/lua/shared/POS_MarketSimulation.lua` | Complete | Orchestrator: init, tick, zone state, agent registry, wholesaler spawning, agent meter updates |
| `common/media/lua/shared/POS_WholesalerService.lua` | Complete | Wholesaler factory, 6-phase tick lifecycle, state machine, pressure formula, downstream influence, event application |
| `common/media/lua/shared/POS_MarketAgent.lua` | Complete | Agent factory, archetype registry, profile/affinity accessors, display name accessor |
| `common/media/lua/shared/POS_ArchetypeSchema.lua` | Complete | Schema for archetype definition files |
| `common/media/lua/shared/POS_ZoneSchema.lua` | Complete | Schema for zone definition files |
| `common/media/lua/shared/POS_EventSchema.lua` | Complete | Schema for event definition files |
| `common/media/lua/shared/POS_WholesalerSchema.lua` | Complete | Schema for wholesaler definition files |
| `common/media/lua/shared/POS_TradeService.lua` | Complete | Trading business logic: query, validate, execute buy/sell transactions |

### Engine Modules (Client)

| File | Status | Description |
|---|---|---|
| `common/media/lua/client/POS_Screen_TradeTerminal.lua` | Complete | Paginated wholesaler list; SIGINT-gated |
| `common/media/lua/client/POS_Screen_TradeCatalog.lua` | Complete | Category browser + item list with BUY/SELL toggle |
| `common/media/lua/client/POS_Screen_TradeConfirm.lua` | Complete | Quantity picker, price preview, bulk discount, execute |
| `common/media/lua/client/POS_Screen_TradeReceipt.lua` | Complete | Static transaction receipt |

### Engine Modules (Server)

| File | Status | Description |
|---|---|---|
| `common/media/lua/server/POS_EconomyTick.lua` | Complete | Phase 5.75 tick hook; calls `tickSimulation()` when Living Market enabled |

### Definition Files — Archetypes

| File | Status | Description |
|---|---|---|
| `Definitions/Archetypes/scavenger_trader.lua` | Complete | Phase 1 archetype: noisy, opportunistic, low stock |
| `Definitions/Archetypes/quartermaster.lua` | Complete | Phase 1 archetype: stable anchor, medium stock, slow movement |
| `Definitions/Archetypes/wholesaler.lua` | Complete | Phase 1 archetype: bulk supplier, regional backbone |
| `Definitions/Archetypes/smuggler.lua` | Complete | High secrecy, contraband, confidence penalties |
| `Definitions/Archetypes/military_logistician.lua` | Complete | Dominates ammo/fuel/radio, high authority |
| `Definitions/Archetypes/speculator.lua` | Complete | Crisis hoarding, price spikes, use sparingly |
| `Definitions/Archetypes/specialist_crafter.lua` | Complete | Converts junk, buffers narrow categories |
| `Definitions/Archetypes/_template.lua` | Complete | Reference template; `enabled = false` |

### Definition Files — Zones

| File | Status | Description |
|---|---|---|
| `Definitions/Zones/muldraugh.lua` | Complete | Small town, sparse, low population |
| `Definitions/Zones/west_point.lua` | Complete | Medium hub, balanced |
| `Definitions/Zones/riverside.lua` | Complete | Moderate, slightly isolated |
| `Definitions/Zones/louisville_edge.lua` | Complete | Dense, deep market, unstable |
| `Definitions/Zones/military_corridor.lua` | Complete | Military-dominated, distorted supply |
| `Definitions/Zones/rural_east.lua` | Complete | Remote, scavenger-heavy |
| `Definitions/Zones/_template.lua` | Complete | Reference template |

### Definition Files — Events

| File | Status | Description |
|---|---|---|
| `Definitions/Events/bulk_arrival.lua` | Complete | Stock rises, pressure falls |
| `Definitions/Events/convoy_delay.lua` | Complete | Stock stalls, pressure builds slowly |
| `Definitions/Events/theft_raid.lua` | Complete | Disruption spike, stock drop, noisy confidence |
| `Definitions/Events/controlled_release.lua` | Complete | Temporary discount, strong stock signals |
| `Definitions/Events/strategic_withholding.lua` | Complete | Pressure rises despite reserves, conflicting rumours |
| `Definitions/Events/requisition_diversion.lua` | Complete | Civilian categories tighten, military/faction diversion |
| `Definitions/Events/_template.lua` | Complete | Reference template |

### Definition Files — Wholesalers

| File | Status | Description |
|---|---|---|
| `Definitions/Wholesalers/muldraugh_general.lua` | Complete | Civilian bulk: food/medicine/tools, small town scale |
| `Definitions/Wholesalers/west_point_consolidated.lua` | Complete | Civilian bulk: food/medicine/tools/fuel, medium scale |
| `Definitions/Wholesalers/riverside_supply.lua` | Complete | Civilian bulk: food/tools/survival, moderate |
| `Definitions/Wholesalers/louisville_arms.lua` | Complete | Black-market broker: ammo/radio/medicine/fuel |
| `Definitions/Wholesalers/louisville_medical.lua` | Complete | Civilian bulk: medicine/food/tools |
| `Definitions/Wholesalers/military_depot.lua` | Complete | Military surplus: ammo/fuel/radio/medicine, huge influence |
| `Definitions/Wholesalers/military_field_hospital.lua` | Complete | Military medical: medicine/food/tools |
| `Definitions/Wholesalers/rural_east_salvage.lua` | Complete | Salvage consolidator: tools/survival/radio/misc |
| `Definitions/Wholesalers/_template.lua` | Complete | Reference template; no built-in instances when file was created |

### World State

| File | Status | Description |
|---|---|---|
| `common/media/lua/shared/POS_WorldState.lua` | Complete (accessors) | `getWholesalers()` and `getMarketZones()` implemented; reset/wipe includes both containers |

### Sandbox & Translation

| File | Status | Description |
|---|---|---|
| `common/media/sandbox-options.txt` | Complete | `EnableLivingMarket`, `SimulationTickInterval` defined |
| `common/media/lua/shared/POS_SandboxIntegration.lua` | Complete | `isLivingMarketEnabled()`, `getSimulationTickInterval()` |
| `42/media/lua/shared/Translate/EN/UI.json` | Complete | 32 Living Market translation keys |
| `42/media/lua/shared/Translate/EN/Sandbox.json` | Complete (assumed) | Sandbox option labels for Living Market options |

---

## Known Gaps Summary

1. ~~**No downstream influence from `getDownstreamInfluence()`**~~ — ✅ Resolved (Phase 4B). Downstream influence is applied during agent observation generation.
2. ~~**PriceEngine is not connected**~~ — ✅ Resolved (Phase 3D). Zone pressure biases the S/D factor in `generatePrice()`.
3. ~~**No terminal UI**~~ — ✅ Resolved (Phase 6). Three terminal screens expose Living Market state.
4. ~~**Soft signal / rumour emission not implemented**~~ — ✅ Resolved (Phase 3B). Soft-class events generate rumour bulletins displayed on the BBS screen.
5. ~~**Save migration path not designed**~~ — ✅ Resolved (Phase 5C). Schema versioning and migration implemented.
6. **Integration testing required** — end-to-end testing of the full Living Market pipeline across all phases.
7. **Balance tuning pending player feedback** — simulation parameters (tick rates, pressure clamps, XP multipliers, noise ranges) will require adjustment based on real gameplay data.
