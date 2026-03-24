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

# POSnet Data Stores Reference

**Status**: Living document — update with every ModData change
**Last updated**: 2026-03-25

---

## 1. Purpose

This document is the **authoritative registry** of every persistent data store
used by POSnet. Every new ModData key MUST be added here before merge.

For each store, document: constant name, owner module, purpose, cap/pruning
strategy, growth classification, reset coverage, and multiplayer scope.

> **Maintenance rule**: If you add a new `getWorldModDataTable()`,
> `getPlayerModDataTable()`, or raw `getModData()` call, update this
> document in the same commit.

---

## 2. World-Scoped Stores

All world stores live under `getGameTime():getModData()` and are
server-authoritative. Every connected player sees the same canonical state.

| # | Key | Constant | Owner | Purpose | Cap / Pruning | Growth | Reset |
|---|-----|----------|-------|---------|---------------|--------|-------|
| 1 | `POSNET` | *(legacy root)* | Core | Root namespace for nested tables | N/A — container | LOW | Yes |
| 2 | `POSNET.World` | `WMD_WORLD` | POS_WorldState | World state (zones, power, day) | Fixed fields | LOW | Yes |
| 3 | `POSNET.Exchange` | `WMD_EXCHANGE` | POS_ExchangeService | Market exchange (prices, stock) | Fixed fields per category | LOW | Yes |
| 4 | `POSNET.Wholesalers` | `WMD_WHOLESALERS` | POS_WholesalerService | Wholesaler registry (7 arch x 6 zones) | Fixed by zone count | LOW | Yes |
| 5 | `POSNET.Meta` | `WMD_META` | POS_API | Mod metadata (version, first-run) | Fixed fields | LOW | Yes |
| 6 | `POSNET.Buildings` | `WMD_BUILDINGS` | POS_WorldState | Known building definitions | Grows with exploration | MEDIUM | Yes |
| 7 | `POSNET.Mailboxes` | `WMD_MAILBOXES` | POS_WorldState | Discovered mailbox locations | Grows with exploration | MEDIUM | Yes |
| 8 | `POSNET.MarketZones` | `WMD_MARKET_ZONES` | POS_MarketSimulation | Zone pressure + configuration | Fixed by zone count | LOW | Yes |
| 9 | `POSNET.Rumours` | `WMD_RUMOURS` | POS_RumourGenerator | Active rumour entries | pushRolling (`RUMOUR_MAX_ACTIVE`) | LOW | Yes |
| 10 | `POSNET.MarketData` | `WMD_MARKET_DATA` | POS_MarketDatabase | Market observations per category | pushRolling per category | LOW | Yes |
| 11 | `POSNET.TradeHistory` | `WMD_TRADE_HISTORY` | POS_TradeService | Trade transaction log | **UNBOUNDED — needs cap** | HIGH | **No** |
| 12 | `POSNET.BuildingCache` | `WMD_BUILDING_CACHE`* | POS_ConnectionManager | Building discovery cache | Grows with world exploration | MEDIUM | **No** |
| 13 | `POSNET.MailboxCache` | `WMD_MAILBOX_CACHE`* | POS_ConnectionManager | Mailbox discovery cache | Grows with world exploration | MEDIUM | **No** |
| 14 | `POSNET.Contracts` | `WMD_CONTRACTS`* | POS_ContractService | Contract lifecycle records | Settled contracts should expire | MEDIUM | **No** |
| 15 | `POSNET.FreeAgents` | `WMD_FREE_AGENTS`* | POS_FreeAgentService | Agent registry | Capped at `FREE_AGENT_MAX_ACTIVE` | LOW | **No** |
| 16 | `POSNET.ActiveEvents` | `WMD_ACTIVE_EVENTS`* | POS_EventService | Currently-firing market events | Self-expiring by `expiryDay` | LOW | **No** |
| 17 | `POSNET.RecentEvents` | `WMD_RECENT_EVENTS`* | POS_EventService | Recent events for Market Signals | Should use pushRolling | MEDIUM | **No** |
| 18 | `POSNET.EventLog` | `WMD_EVENT_LOG`* | POS_EventLog | System logs + daily snapshots | **UNBOUNDED — needs trimByAge** | HIGH | **No** |
| 19 | `POS_PendingResolutions` | `WMD_PENDING_RESOLUTIONS`* | POS_InvestmentResolver | Investment maturation queue | Self-clearing on resolution | LOW | **No** |
| 20 | `POS_PendingPayouts_{user}` | *(dynamic)* | POS_InvestmentResolver | Per-player offline payouts | Self-clearing on collection | LOW | **No** |
| 21 | *(within MarketData)* | — | POS_EconomyTick | Rolling price closes | pushRolling (`maxRollingCloses`) | LOW | *(via parent)* |

Items marked with **\*** denote constants that are yet to be added to
`POS_Constants`.

---

## 3. Player-Scoped Stores

All player stores live under `player:getModData()` and are per-character.
Each survivor maintains independent state.

| # | Key | Constant | Owner | Purpose | Cap / Pruning | Growth | Reset |
|---|-----|----------|-------|---------|---------------|--------|-------|
| 1 | `POS_Operations` | `MODDATA_OPERATIONS` | POS_OperationLog | Completed operation records | **UNBOUNDED — needs cap** | HIGH | Yes |
| 2 | `POS_Opportunities` | `MODDATA_OPPORTUNITIES` | POS_InvestmentLog | Investment opportunities | pushRolling (`MAX_OPPORTUNITIES`) | LOW | Yes |
| 3 | `POS_Investments` | `MODDATA_INVESTMENTS` | POS_InvestmentLog | Active investments | Lifecycle-limited | LOW | Yes |
| 4 | `POS_Watchlist` | `MODDATA_WATCHLIST` | POS_PlayerState | Player watchlist items | Player-managed | LOW | Yes |
| 5 | `POS_Alerts` | `MODDATA_ALERTS` | POS_PlayerState | Player alert queue | pushRolling (`MAX_PLAYER_ALERTS`) | LOW | Yes |
| 6 | `POS_SIGINT_TotalXP` | `MODDATA_SIGINT_TOTAL_XP` | POS_SIGINTSkill | Cumulative SIGINT XP | Single number | LOW | Yes |
| 7 | `POS_SIGINT_CrossCorrelations` | `MODDATA_SIGINT_CROSSCOR_COUNT` | POS_SIGINTSkill | Cross-correlation count | Single number | LOW | Yes |
| 8 | `POSNET_Discoveries` | `DISCOVERY_NAMESPACE` | POS_MarketDatabase | Discovered items/locations | Grows with gameplay | MEDIUM | Yes |

---

## 4. PhobosLib Persistence Utilities

These utilities are provided by PhobosLib and available to all Phobos mods.
POSnet should prefer library functions over hand-rolled equivalents.

| Utility | Signature | Purpose | POSnet Usage |
|---------|-----------|---------|--------------|
| pushRolling | `(arr, val, cap)` | Auto-trim array to cap, oldest first | Rumours, MarketData, Alerts, PriceCloses |
| trimArray | `(arr, cap)` | Manual trim to cap | Available — unused |
| trimByAge | `(arr, dayField, maxDays, currentDay)` | Age-based expiry | Available — **should be used by EventLog, TradeHistory** |
| getWorldModDataTable | `(namespace, key)` | Get/create nested world table | 42 uses across 10+ modules |
| getPlayerModDataTable | `(player, key)` | Get/create player sub-table | 5 uses |
| registerMigration | `(modId, from, to, fn, label)` | Version-to-version data migrations | Available — unused |
| validateSchema | `(data, schema)` | Declarative structure validation | Available — unused |
| ChunkedWriter | `createChunkedWriter(opts)` | Large file writes without frame drops | Available — unused |

---

## 5. Growth Risk Assessment

| Risk | Stores | Current Mitigation | Recommended Action |
|------|--------|--------------------|--------------------|
| **HIGH** | TradeHistory, EventLog, POS_Operations | None — unbounded arrays | Add pushRolling or trimByAge caps |
| **MEDIUM** | Buildings, Mailboxes, BuildingCache, MailboxCache, Contracts, RecentEvents, Discoveries | Natural limits but no hard caps | Monitor; add trimByAge if growth observed |
| **LOW** | All others | pushRolling, lifecycle expiry, or fixed fields | No action needed |

### Recommended Caps

| Store | Strategy | Suggested Value | Rationale |
|-------|----------|-----------------|-----------|
| TradeHistory | trimByAge | 30 game-days | Older trades have no gameplay value |
| EventLog | trimByAge | 14 game-days | Snapshots only needed for recent trend analysis |
| POS_Operations | pushRolling | 200 entries | Sufficient for scrollback; oldest ops are stale |

---

## 6. Reset Coverage Matrix

Stores are reset via `POS_DataResetService`. A tick indicates the store is
covered by the current reset logic; a cross indicates it is missing.

| # | Store | Scope | Currently Reset | After Fix |
|---|-------|-------|:---------------:|:---------:|
| 1 | POSNET (root) | World | Y | Y |
| 2 | POSNET.World | World | Y | Y |
| 3 | POSNET.Exchange | World | Y | Y |
| 4 | POSNET.Wholesalers | World | Y | Y |
| 5 | POSNET.Meta | World | Y | Y |
| 6 | POSNET.Buildings | World | Y | Y |
| 7 | POSNET.Mailboxes | World | Y | Y |
| 8 | POSNET.MarketZones | World | Y | Y |
| 9 | POSNET.Rumours | World | Y | Y |
| 10 | POSNET.MarketData | World | Y | Y |
| 11 | POSNET.TradeHistory | World | N | Y |
| 12 | POSNET.BuildingCache | World | N | Y |
| 13 | POSNET.MailboxCache | World | N | Y |
| 14 | POSNET.Contracts | World | N | Y |
| 15 | POSNET.FreeAgents | World | N | Y |
| 16 | POSNET.ActiveEvents | World | N | Y |
| 17 | POSNET.RecentEvents | World | N | Y |
| 18 | POSNET.EventLog | World | N | Y |
| 19 | POS_PendingResolutions | World | N | Y |
| 20 | POS_PendingPayouts_{user} | World | N | Y |
| 21 | (MarketData rolling closes) | World | *(via parent)* | *(via parent)* |
| 22 | POS_Operations | Player | Y | Y |
| 23 | POS_Opportunities | Player | Y | Y |
| 24 | POS_Investments | Player | Y | Y |
| 25 | POS_Watchlist | Player | Y | Y |
| 26 | POS_Alerts | Player | Y | Y |
| 27 | POS_SIGINT_TotalXP | Player | Y | Y |
| 28 | POS_SIGINT_CrossCorrelations | Player | Y | Y |
| 29 | POSNET_Discoveries | Player | Y | Y |

**Summary**: 10 world stores are currently missing from reset. All player
stores are covered.

---

## 7. Multiplayer Considerations

- **World stores (21)**: Shared across all players, server-authoritative. All
  players see the same market state, wholesalers, contracts, and events. Only
  the server writes to these tables; clients read cached copies.

- **Player stores (8)**: Per-character. Each player has their own operations,
  investments, watchlist, alerts, and SIGINT progress. These travel with the
  player save, not the world save.

- **Dynamic keys**: `POS_PendingPayouts_{username}` is generated per-player
  at runtime. Reset logic must construct the key from the current player's
  username — it cannot be statically enumerated.

- **Trade history**: World-scoped — all players see all trades. On
  high-traffic multiplayer servers, this store could see rapid growth.
  Implementing trimByAge is especially important for MP longevity.

- **Discovery data**: Player-scoped, so each survivor builds their own
  knowledge map. No cross-player leakage of discovered locations or items.

- **Event broadcasts**: ActiveEvents and RecentEvents are world-scoped.
  All connected players receive the same market event notifications
  simultaneously, ensuring consistent economic pressure across the server.

---

## 8. Maintenance Checklist

When adding a new data store:

1. Define a `WMD_` or `MODDATA_` constant in `POS_Constants` (or the
   appropriate split constants file).
2. Add to this document's world or player table (Section 2 or 3).
3. Add to `POS_DataResetService` reset list.
4. Choose a cap/pruning strategy — prefer PhobosLib utilities:
   - `pushRolling` for append-only logs with a fixed window.
   - `trimByAge` for time-sensitive records.
   - Lifecycle expiry for self-clearing queues.
5. Classify growth risk (LOW / MEDIUM / HIGH).
6. Document MP scope (shared world vs per-player).
7. Update the Reset Coverage Matrix (Section 6).

> **Review trigger**: Any PR that touches `getWorldModDataTable`,
> `getPlayerModDataTable`, or raw `getModData` calls should include an
> update to this document. Reviewers should verify the checklist above
> is satisfied before approving.
