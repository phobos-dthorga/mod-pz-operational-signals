# POSnet Interoperability Matrix

This document is the authoritative reference for subsystem data flows within
POSnet. It defines what each subsystem consumes, produces, where it persists
its truth, and which dependencies are optional. All new subsystems must be
documented here before implementation begins. See `design-guidelines.md` §28
for the governing principles.

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

---

## Screen Refresh Triggers

Each terminal screen should update when specific domain actions occur. Rather than asking "How do I use this screen?", ask: "What events should make this screen meaningfully change?"

| Screen | Refreshed When |
|---|---|
| Intel Summary | analysis completes, recon finishes, tapes compiled, broadcasts sent |
| Event Log | missions complete, notes uploaded, broadcasts sent, investments resolve, alerts fire |
| Watchlist | market snapshots change, economy tick completes |
| Zone Overview | new observations arrive, economy tick completes, zone pressure changes |
| Wholesaler Directory | stock levels change, rumours fire, wholesaler state transitions |
| BBS Rumours | soft-class market events fire, rumours expire |
| Commodities | economy tick completes, new observations recorded |
| Market Reports | analysis completes, economy tick completes |

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
