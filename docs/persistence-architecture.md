# POSnet Persistence Architecture

## Overview

POSnet uses a three-layer persistence model. Each layer has a distinct scope, authority, and retention policy. The design prioritises minimal save bloat, server-authoritative writes, and disposable supplementary logs.

| Layer | Scope | Location | Authority |
|-------|-------|----------|-----------|
| 1. World ModData | Shared economy state | PZ world save (engine-managed) | Server-only writes |
| 2. Player ModData | Per-character scalar state (rep, cash, prefs) | PZ player save (engine-managed) | Server validates, client reads |
| 3. Event Logs | Historical append-only records | World ModData (`POSNET.EventLog`) | Server-only writes, disposable |

---

## Layer 1: World ModData

Primary authoritative store for the shared economy. All connected players see the same canonical state.

### Containers

| Key | Purpose |
|-----|---------|
| `POSNET.World` | Global economy counters, current game day, tick state |
| `POSNET.Exchange` | Category indices, company listings, rolling closes, order book |
| `POSNET.Wholesalers` | NPC wholesaler inventories, restock timers, behaviour state |
| `POSNET.Meta` | Schema version, migration flags, feature toggles |
| `POSNET.Buildings` | Discovered building cache (id, coords, roomDef, zone) |
| `POSNET.Mailboxes` | Discovered mailbox cache (id, coords, paired building) |
| `POSNET.MarketData` | Market observations and ambient intel records |
| `POSNET.EventLog` | Event logs (economy/stocks/recon per-day) + snapshots |
| `POSNET.BuildingCache` | Building discovery cache (array of {x, y, rooms}) |
| `POSNET.MailboxCache` | Mailbox discovery cache (array of {x, y}) |

### Storage Location

Inside the PZ world save file, managed by the engine via `getGameTime():getModData()`. No manual file I/O required.

### Caps

All caps are sandbox-configurable:

| Data | Cap | Sandbox Option |
|------|-----|----------------|
| Observations per category | 24 | `MaxObservationsPerCategory` |
| Rolling daily closes | 14 | `MaxRollingCloses` |
| Global market events | 100 | `MaxGlobalEvents` |

Older entries are discarded FIFO when caps are exceeded.

---

## Layer 2: Player ModData

Tiny character-bound scalar state. Kept deliberately small to avoid save bloat across many players on a server. Growth-prone arrays (watchlist, alerts, orders, holdings) are stored in Layer 2b instead.

### Schema

| Field | Type | Purpose |
|-------|------|---------|
| `rep` | integer | Current reputation score |
| `cash` | integer | Cash balance (dollars) |
| `intelAccess` | table (category IDs) | Categories player has gathered intel on |
| `uiPrefs` | table | Terminal colour theme, font size, panel toggles |
| `lastMarketSyncDay` | integer | Last game day the player received a market snapshot |

### Storage Location

Inside the player character save, managed by the engine via `player:getModData()`.

---

## Layer 2b: Player File Store (DEPRECATED)

Previous versions stored growth-prone arrays (watchlist, alerts, orders, holdings)
in per-player `.dat` files via `POS_PlayerFileStore.lua`. This system has been
removed because `getFileReader` causes silent JVM crashes in multiple PZ lifecycle
contexts (OnGameStart, render frames, event ticks).

All per-player data now uses player modData exclusively via
`PhobosLib.getPlayerModDataTable()` — see design-guidelines.md §27.6.
Old `.dat` files in `Zomboid/Lua/POSNET/` are safely ignored.

---

## Layer 3: Event Logs (World ModData)

Historical append-only records stored in world ModData under `POSNET.EventLog`.
Intended for debugging, admin auditing, and optional analytics. The economy
does not depend on these logs — if cleared, the economy continues from Layer 1
state.

> **Migration note**: Event logs were previously stored as flat files in
> `Zomboid/Lua/POSNET/`. This caused silent Kahlua JVM crashes because PZ
> scans and compiles all files in that directory. All file I/O has been
> eliminated — POSnet has **zero** `getFileWriter`/`getFileReader` calls.
> Building and mailbox caches also moved to world ModData (`POSNET.BuildingCache`,
> `POSNET.MailboxCache`). Old files in `Zomboid/Lua/POSNET/` can be safely deleted.

### ModData Structure

```lua
POSNET.EventLog = {
    logs = {
        ["economy_day821"] = "day|system|...\nday|system|...\n",
        ["stocks_day821"]  = "...",
        ["recon_day821"]   = "...",
    },
    snapshots = {
        ["economy"]  = "header\n---\ndata\n",
        ["exchange"] = "...",
    },
}
```

### Event Format

Pipe-delimited text, one line per event (newline-delimited within each
ModData string value):

```
day|system|eventType|entityId|regionId|actorId|qty|unitPriceBps|cause|version
```

| Field | Type | Description |
|-------|------|-------------|
| `day` | integer | Game day number |
| `system` | string | Subsystem identifier (economy, stocks, recon) |
| `eventType` | string | Event type code |
| `entityId` | string | Target entity (category, company, building) |
| `regionId` | string | Map region identifier |
| `actorId` | string | Player or NPC triggering the event |
| `qty` | integer | Quantity involved |
| `unitPriceBps` | integer | Unit price in basis points |
| `cause` | string | Causal reason code |
| `version` | integer | Schema version for forward compatibility |

### Retention

- Sandbox-configurable via `EventLogRetentionDays`
- Default: 30 days, range: 7-90
- Older log keys are deleted (not truncated) during the daily economy tick
- Server-only writes, append-only
- Uses `PhobosLib.getWorldModDataTable()` for access

---

## Storage Rules

1. **IDs instead of names** -- all references use stable integer or short-string IDs, never display names.
2. **Day numbers, not text timestamps** -- game day integers for all temporal data. No date strings.
3. **Basis points for prices** -- all prices stored as integers in basis points (1 bps = 0.01%). No floats.
4. **Capped rolling windows everywhere** -- every array has an explicit maximum. FIFO eviction when full.
5. **Never duplicate raw + summary + per-player copies** -- one canonical source per datum.
6. **Server-only writes for world state and event logs** -- clients never mutate shared data directly.
7. **Clients receive filtered projections** -- delivered via `sendServerCommand`, scoped to what the player should see.

---

## Authority Model

Server-authoritative from day one. Single-player runs the server locally, so the same code path applies.

- Only the server mutates world ModData (`POSNET.World`, `POSNET.Exchange`, etc.)
- Clients request snapshots; they never write canonical state
- All buy/sell/order actions are submitted to the server for validation before execution
- Player ModData is updated by server-side callbacks after validated actions complete

---

## Network Protocol

All communication uses PZ `sendServerCommand` / `sendClientCommand` with module `"POS"` (`POS_Constants.CMD_MODULE`).

### Client to Server (Submissions)

| Command | Purpose |
|---------|---------|
| `SubmitObservation` | Player submits a field recon observation |
| `SubmitBuilding` | Player reports a newly discovered building |
| `SubmitMailbox` | Player reports a newly discovered mailbox |

### Client to Server (Requests)

| Command | Purpose |
|---------|---------|
| `RequestMarketSnapshot` | Player requests current market overview |
| `RequestCategoryDetail` | Player requests detailed data for a specific category |

### Server to Client (Responses)

| Command | Purpose |
|---------|---------|
| `MarketSnapshot` | Filtered market overview for the requesting player |
| `CategoryDetail` | Detailed category data for the requesting player |
| `EconomyTickComplete` | Notification that a daily tick has been processed |
| `BuildingCacheSync` | Updated building cache data |
| `MailboxCacheSync` | Updated mailbox cache data |

### Admin Commands (Client to Server)

| Command | Purpose | Guard |
|---------|---------|-------|
| `AdminForceTick` | Force an immediate economy tick | `PhobosLib.isPlayerAdmin()` |
| `AdminDumpState` | Request compact world state summary | `PhobosLib.isPlayerAdmin()` |

Admin commands are rejected silently (no response, no log) when the sending player is not a server admin. `AdminForceTick` resets `meta.lastProcessedDay` to `-1` then invokes `POS_EconomyTick.processDayTick()`. `AdminDumpState` responds to the requesting player with a summary table containing `schemaVersion`, `lastProcessedDay`, `categoryCount`, and `totalObservations`.

---

## Server-Side Validation

### CMD_SUBMIT_OBSERVATION

All market observation submissions pass through server-side validation before reaching `POS_MarketDatabase.addRecord()`:

1. **Nil guard** -- rejects if `args` or `args.record` is nil.
2. **categoryId type check** -- rejects if `record.categoryId` is not a non-empty string.
3. **Registry check** -- rejects if `POS_MarketRegistry.getCategory(record.categoryId)` returns nil (unknown category).
4. **Price range check** -- rejects if `record.price` is present but not a number, negative, or exceeds 10 000.
5. **Server-authoritative fields** -- the server overwrites `record.recordedDay` with the current world day and assigns `record.id` if the client did not provide one.

All rejections are logged via `PhobosLib.debug` with the submitting player's username.

---

## Intel Gathering Context Menu (4-State Model)

The right-click "Gather Market Intel" option (`POS_MarketContextMenu`) is always visible but transitions through four states:

| State | Condition | Behaviour |
|-------|-----------|-----------|
| `wrong_location` | Player is not inside a mapped building room | Greyed out, tooltip explains location requirement |
| `missing_items` | Player lacks a writing tool or paper | Greyed out, tooltip lists missing items |
| `cooldown` | Location visited within `IntelCooldownDays` | Greyed out, tooltip shows remaining days |
| `ready` | All conditions met | Clickable, starts `POS_MarketReconAction` timed action |

### Intel Cooldown System

Cooldown is tracked per-location in **player modData** using keys of the form `POS_IntelVisit_<x>_<y>`, where `<x>` and `<y>` are tile coordinates. The value is the game day of the last visit. The cooldown duration is sandbox-configurable (`IntelCooldownDays`, default 12). Expired cooldown keys are cleaned up when their age exceeds `INTEL_COOLDOWN_DAYS * INTEL_CLEANUP_MULTIPLIER`.

This is intentionally stored in player modData (not world ModData) because it is per-character, tiny (one integer per visited location), and has no server-authority requirement.

---

## VHS Tape Event Log Storage

VHS tapes use a hybrid storage pattern: **summary metadata in item modData** and **full entry data in the event log** (Layer 3).

### Item modData (carried on the tape item)

| Key | Type | Purpose |
|-----|------|---------|
| `POS_TapeId` | string | Unique tape identifier for linking entries in the event log |
| `POS_TapeEntryCount` | integer | Number of entries recorded |
| `POS_TapeCapacity` | integer | Maximum entries (set by tape type) |
| `POS_TapeQuality` | string | Quality tier (high, medium, low, very_low) |
| `POS_TapeRegion` | string | Region of first recording |
| `POS_TapeDuration` | integer | Cumulative recording duration |
| `POS_TapeWear` | integer | Degradation percentage (0-100) |

### Event log (detailed entry data)

Each tape recording appends to the `recon` event log system with `eventType = "tape_entry"`. The `actorId` field stores the tape's `POS_TapeId`, allowing all entries for a given tape to be queried by filtering the recon log. This avoids bloating item modData with unbounded arrays while preserving full audit history.

Tape types have different capacities and confidence modifiers (in basis points):

| Tape Type | Capacity | Confidence Mod (BPS) |
|-----------|----------|---------------------|
| Factory blank | 20 | 0 |
| Refurbished | 15 | -1000 |
| Spliced | 8 | -2500 |
| Improvised | 4 | -5000 |

Wear further reduces confidence at -100 BPS per wear point. When wear reaches 100, the tape is considered worn out and should be replaced.

---

## What NOT to Use

| Anti-pattern | Reason |
|--------------|--------|
| JSON for primary persistence | PZ modData is Lua tables serialised by the engine. Adding a JSON layer adds complexity and fragility for no benefit. |
| Binary formats | Not human-readable, not debuggable, unnecessary for the data sizes involved. |
| Per-player market state copies | Violates single-source-of-truth. Market state lives in world ModData only. |
| Unbounded arrays | Guaranteed save bloat over long-running servers. Every array must have a cap. |
| `getFileWriter()` / `getFileReader()` anywhere | PZ compiles all files in `Zomboid/Lua/`; data files cause silent JVM crashes. All persistence must use ModData exclusively. Zero file I/O in POSnet. |
