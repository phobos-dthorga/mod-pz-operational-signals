# POSnet Interoperability Matrix

This document is the authoritative reference for subsystem data flows within
POSnet. It defines what each subsystem consumes, produces, where it persists
its truth, and which dependencies are optional. All new subsystems must be
documented here before implementation begins. See `design-guidelines.md` §28
for the governing principles.

---

## Subsystem Data Flow

| Subsystem | Consumes | Produces | Persistence Owner | Optional Dependencies |
|---|---|---|---|---|
| Passive Recon | radio signals, zone pressure | observation records, recorder chunks | POS_MarketDatabase | POS_MarketSimulation |
| Data Recorder | datasource chunks | raw intel artifacts | recorder modData | POS_DataSourceRegistry |
| Terminal Analysis | raw intel artifacts, observations | compiled reports, analysis summaries | POS_MarketDatabase | POS_CameraService |
| Camera Service | building/zone context | compiled footage artifacts | camera modData | POS_MarketSimulation |
| Satellite Service | compiled reports, zone state | broadcast payloads, market effects | satellite modData | POS_MarketSimulation |
| Living Market | observations, market effects | zone pressure, rumours, wholesaler states | POSNET.Wholesalers, POSNET.MarketZones | POS_MarketDatabase |
| Operations/Missions | observations, building discoveries | rewards, reputation, demand shifts | POS_OperationLog | POS_Reputation |
| Market Service | MarketDatabase records | category summaries, freshness data | POS_MarketFileStore | — |
| Broadcast System | economy tick events | server commands (MP), direct calls (SP) | — | — |
| Tutorial System | milestone events from 6+ services | tutorial popups, progression flags | player modData | PhobosLib_Milestone |
| Rumour System | soft-class market events | rumour bulletins, BBS entries | POSNET.Rumours | POS_WholesalerService |

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
