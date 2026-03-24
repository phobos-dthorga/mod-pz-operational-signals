# POSnet Interoperability Matrix

This document is the authoritative reference for subsystem data flows within
POSnet. It defines what each subsystem consumes, produces, where it persists
its truth, and which dependencies are optional. All new subsystems must be
documented here before implementation begins. See `design-guidelines.md` §28
for the governing principles. Sandbox option conventions (when to add one, naming,
anti-patterns) are covered in `design-guidelines.md` §34.

---

## Subsystem Data Flow

| Subsystem | Consumes | Produces | Persistence Owner | Optional Dependencies | Refreshed By |
|---|---|---|---|---|---|
| Passive Recon | radio signals, zone pressure | observation records, recorder chunks | POS_MarketDatabase | POS_MarketSimulation | EveryOneMinute tick |
| Data Recorder | datasource chunks | raw intel artifacts | recorder modData | POS_DataSourceRegistry | chunk append, media insert/eject |
| Terminal Analysis | raw intel artifacts, observations | compiled reports, analysis summaries | POS_MarketDatabase | POS_CameraService | analysis completion, tape review |
| Camera Service | building/zone context | compiled footage artifacts | camera modData | POS_MarketSimulation | footage compilation |
| Satellite Service | compiled reports, zone state | broadcast payloads, market effects | satellite modData | POS_MarketSimulation | broadcast sent, calibration change |
| Living Market | observations, market effects | zone pressure, rumours, wholesaler states | POSNET.Wholesalers, POSNET.MarketZones | POS_MarketDatabase | economy day tick |
| Operations/Missions | observations, building discoveries | rewards, reputation, demand shifts | POS_OperationLog | POS_Reputation | operation accept/complete, delivery complete |
| Market Service | MarketDatabase records | category summaries, freshness data | POS_MarketFileStore | — | economy tick, note upload |
| Broadcast System | economy tick events | server commands (MP), direct calls (SP) | — | — | economy tick complete |
| Tutorial System | milestone events from 6+ services | tutorial popups, progression flags | player modData | PhobosLib_Milestone | any milestone-eligible action |
| Rumour System | soft-class market events | rumour bulletins, BBS entries | POSNET.Rumours | POS_WholesalerService | wholesaler event firing |
| Recipe Callbacks | recipe items, player modData, sandbox options | field reports, market notes, media items | player modData (note content), item modData (media state) | POS_CraftHelpers | player crafts recipe |
| Trade Service | wholesaler state, PriceEngine prices, ItemPool categories, player inventory/money | inventory changes, money changes, stock mutations, state transitions, PN notifications | POSNET.Wholesalers (stock), player inventory (items/money) | POS_MarketSimulation, PhobosNotifications | player trade action |
| Ambient Intel | terminal connection, market categories, base prices | low-confidence observations, item discoveries, item-level price data (`record.items` + `record.discoveredItems`) | POS_MarketDatabase (world ModData) | POS_ConnectionManager, POS_MarketSimulation | EveryOneMinute (30 min interval) |
| Discovery System | observation records with discoveredItems | player ModData discoveries, PN notifications | player ModData (POSNET_Discoveries) | POS_MarketDatabase, PhobosLib | observation addRecord |
| Strategic Relay | broadcast payloads, agent telemetry, market signals | relay queue packets, intercept results, agent backhaul data, fused intelligence | relay site modData | POS_FreeAgentService, POS_MarketSimulation, POS_SatelliteService | relay tick, intercept sweep, bandwidth change |
| Signal Ecology | weather state, grid power, market volatility, agent count, hardware condition | composite signal state (5 pillars), qualitative signal band | cached per-hour | POS_ConnectionManager, POS_MarketSimulation, POS_FreeAgentService | hourly tick, state change events |
| Broadcast Influence | compiled artifacts, broadcast mode, trust score | market_signal records, agent_advisory records, rumour echoes, trust mutations | POSNET.Broadcasts | POS_WholesalerService, POS_FreeAgentService, POS_RumourGenerator | broadcast sent |

---

## Screen Refresh Triggers

Each terminal screen should update when specific domain actions occur. Rather than asking "How do I use this screen?", ask: "What events should make this screen meaningfully change?"

| Screen | Refreshed When |
|---|---|
| Market Overview | economy tick completes, new observations recorded, zone pressure changes |
| Known Contacts | wholesaler state changes, stock level changes, SIGINT level changes |
| Market Signals | soft-class events fire, rumours expire, hard events recorded |
| Watchlist | market snapshots change, economy tick completes, price history updated |
| Market Reports | analysis completes, economy tick completes |
| Trade Catalog | trade completes, stock changes (updated, inline confirm now) |
| Assignments | operation accepted/completed/expired/cancelled, new operations broadcast |

This mapping prepares for a future event bus without requiring one now.

---

## Canonical Payload Shapes

### Observation Record

```lua
{
    categoryId  = "food",           -- POS_Constants category ID
    price       = 125.50,           -- unit price (dollars, not basis points)
    stock       = "medium",         -- "low" | "medium" | "high"
    confidence  = "high",           -- "low" | "medium" | "high"
    source      = "agent_scavenger_trader",  -- source identifier
    sourceTier  = "field",          -- POS_Constants.SOURCE_TIER_*
    day         = 851,              -- world day (getNightsSurvived)
    zoneId      = "muldraugh",      -- POS_Constants zone ID (optional)
}
```

### Market Effect

```lua
{
    eventId       = "bulk_arrival",   -- POS_Constants.MARKET_EVENT_*
    zoneId        = "west_point",     -- target zone
    categoryId    = "ammunition",     -- affected category
    pressureDelta = -0.15,            -- pressure change (negative = surplus)
    durationDays  = 3,                -- how long the effect persists
    source        = "wholesaler_tick", -- originating system
}
```

### Rumour Payload

```lua
{
    id            = "rumour_851_1",     -- unique identifier
    eventId       = "convoy_delay",     -- originating event type
    categoryIds   = {"fuel", "tools"},  -- affected categories
    regionId      = "military_corridor", -- zone/region
    sourceName    = "Military Depot",   -- wholesaler display name
    confidence    = "low",              -- always "low" for rumours
    recordedDay   = 851,                -- when recorded
    expiryDay     = 858,               -- when it expires (recordedDay + 7)
    impactHint    = "shortage",         -- "surplus" | "neutral" | "shortage"
    messageKey    = "UI_POS_Rumour_ConvoyDelay", -- translation key
}
```

### Recorder Chunk

```lua
{
    chunkType     = "market_observation", -- POS_Constants.CHUNK_TYPE_*
    data          = { ... },             -- payload (varies by chunkType)
    day           = 851,                 -- world day
    confidence    = 7500,               -- confidence in basis points
    zoneId        = "muldraugh",         -- zone context (optional)
    sourceType    = "passive_recon",     -- originating system
}
```

### Broadcast Record (Tier IV Influence Layer)

```lua
{
    id            = "bc_1042",
    type          = "scarcity_alert",    -- scarcity_alert | surplus_notice | route_warning | contact_bulletin | strategic_rumour
    origin        = "satellite_tier4",   -- broadcast source
    zoneId        = "west_point",
    categoryId    = "ammo",
    confidence    = 0.81,                -- derived from artifact quality
    strength      = 0.46,                -- 0.0 to 1.0
    freshness     = 0.90,                -- decays over time
    trustWeight   = 0.67,                -- station broadcast credibility
    issuedDay     = 22,
    expiresDay    = 25,
}
```

### Market Effect Projection (from Broadcast)

```lua
{
    zoneId              = "west_point",
    categoryId          = "ammo",
    perceivedPressureMod = 0.22,         -- shifts perceived, not real pressure
    rumourChanceMod     = 0.18,
    wholesalerBias      = {
        accumulate = 0.14,
        conceal    = 0.09,
    },
}
```

### Agent Advisory (from Broadcast)

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

### Signal State (Signal Ecology v2 — Future)

```lua
{
    composite         = 0.72,            -- final [0, 1] value
    qualitativeState  = "clear",         -- locked | clear | faded | fragmented | ghosted | lost
    pillars = {
        propagation    = 0.85,
        infrastructure = 0.70,
        clarity        = 0.65,
        saturation     = 0.30,
        intent         = 0.80,
    },
}
```
