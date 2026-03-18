# POSnet Persistence Architecture

## Overview

POSnet uses a three-layer persistence model. Each layer has a distinct scope, authority, and retention policy. The design prioritises minimal save bloat, server-authoritative writes, and disposable supplementary logs.

| Layer | Scope | Location | Authority |
|-------|-------|----------|-----------|
| 1. World ModData | Shared economy state | PZ world save (engine-managed) | Server-only writes |
| 2. Player ModData | Per-character UI/portfolio state | PZ player save (engine-managed) | Server validates, client reads |
| 3. Event Logs | Historical append-only records | `<Zomboid>/Lua/POSNET/` on disk | Server-only writes, disposable |

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

Tiny character-bound state. Kept deliberately small to avoid save bloat across many players on a server.

### Schema

| Field | Type | Purpose |
|-------|------|---------|
| `rep` | integer | Current reputation score |
| `cash` | integer | Cash balance (dollars) |
| `watchlist` | table (category IDs) | Player's watched commodity categories |
| `openOrders` | table (order stubs) | Active buy/sell orders (max bounded) |
| `holdings` | table (position stubs) | Current investment/portfolio positions |
| `intelAccess` | table (category IDs) | Categories player has gathered intel on |
| `alerts` | table (alert entries) | Market alerts, capped at 20 |
| `uiPrefs` | table | Terminal colour theme, font size, panel toggles |
| `lastMarketSyncDay` | integer | Last game day the player received a market snapshot |

### Storage Location

Inside the player character save, managed by the engine via `player:getModData()`.

---

## Layer 3: Event Logs

Historical append-only records stored outside modData. Intended for debugging, admin auditing, and optional analytics. The economy does not depend on these files -- if deleted, the economy continues from Layer 1 state.

### Location

```
<Zomboid user folder>/Lua/POSNET/
```

### File Structure

```
POSNET/
  events/
    economy/<day>.log
    stocks/<day>.log
    recon/<day>.log
  snapshots/
    economy_latest.txt
    exchange_latest.txt
```

### Event Format

Pipe-delimited text, one line per event:

```
day|system|eventType|entityId|regionId|actorId|qty|unitPriceBps|cause|version
```

Fields:

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

### Snapshot Format

Header line followed by `---` separator followed by data rows:

```
snapshot_type|day|generated_at|version
---
<data rows in format specific to snapshot type>
```

### Retention

- Sandbox-configurable via `EventLogRetentionDays`
- Default: 30 days, range: 7-90
- Older log files are purged during the daily economy tick
- Server-only writes, append-only

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

All communication uses PZ `sendServerCommand` / `sendClientCommand` with module `"POSNET"`.

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

### Admin Commands

| Command | Purpose |
|---------|---------|
| `AdminForceTick` | Force an immediate economy tick (admin only) |
| `AdminDumpState` | Dump current world ModData to server log (admin only) |

---

## What NOT to Use

| Anti-pattern | Reason |
|--------------|--------|
| JSON for primary persistence | PZ modData is Lua tables serialised by the engine. Adding a JSON layer adds complexity and fragility for no benefit. |
| Binary formats | Not human-readable, not debuggable, unnecessary for the data sizes involved. |
| Per-player market state copies | Violates single-source-of-truth. Market state lives in world ModData only. |
| Unbounded arrays | Guaranteed save bloat over long-running servers. Every array must have a cap. |
| `getFileWriter()` for economy database | Economy state belongs in world ModData (engine-managed, save-consistent). File I/O is reserved for disposable event logs only. |
