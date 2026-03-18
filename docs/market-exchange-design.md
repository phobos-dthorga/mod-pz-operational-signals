# POSnet Market & Exchange — Economic System Design

> **Governing Principle**: POSnet brokers and compiles market intelligence.
> It does not behave like a magical online shop.

This document defines the data models, business rules, and architectural
pipeline for POSnet's economic systems: the Marketplace (commodity
intelligence) and the Exchange (commodity indices and portfolio tracking).

For UI/UX rules, see `design-guidelines.md` Sections 2, 7, 8, and 9.

---

## 1. Governing Principles

1. **Intelligence, not commerce** — The terminal reveals information about
   goods. It does not sell them. Physical trading happens at world contacts.

2. **Summary before detail** — Every economic screen shows a high-level
   summary first. Detailed listings are drill-down only.

3. **Freshness always visible** — All data is timestamped. The player must
   always know how old the information is.

4. **Confidence always visible** — Aggregated data shows a confidence level
   derived from source count, recency, and reputation.

5. **Player effort improves information** — Early game: sparse, low-confidence
   data. Late game: rich, high-confidence intelligence from many sources.

6. **Terminal-native aesthetic** — 1990s BBS economic bulletin boards, not
   Bloomberg terminals. Text-based trend indicators, no graphical charts.

7. **Never break the fiction** — Everything must feel like it was produced by
   radios, survivors, scribbled notes, and limited computing power.

---

## 2. Three-Layer Architecture

```
Layer A: Field Intelligence       (player actions → raw data)
    ↓
Layer B: POSnet Aggregation       (data processing → summaries)
    ↓
Layer C: Presentation             (terminal screens → player decisions)
```

### Layer A — Field Intelligence

Raw market data gathered by the player in the field:
- Timed "discuss and write notes" action at trader/contact locations
- Consumes paper + writing implement (pen/pencil durability)
- Produces **Raw Market Notes** (inventory item with modData)
- Each note contains: source, category, price, stock estimate, date
- Notes are messy, single-source, potentially inaccurate

### Layer B — POSnet Aggregation

The terminal processes raw intel into structured summaries:
- Player feeds notes into the terminal (ingestion action)
- Records stored in player modData (`POS_MarketIntel`)
- Aggregation computes: min/max/avg price, source count, freshness, confidence, trend
- Expired records automatically purged
- Multiple sources for the same category increase confidence

### Layer C — Presentation

Terminal screens display actionable intelligence:
- Commodity summaries (summary-first layout)
- Known traders (paginated listings)
- Compiled market reports (regional dossiers)
- Price ledger (historical trend data)
- Exchange indices (commodity index + sentiment)

---

## 3. Commodity Categories

Categories are **registry-driven** — third-party mods can register additional
commodity types via `POS_MarketRegistry.registerCategory()`.

### Default Categories

| ID | Label Key | Sort Order |
|----|-----------|------------|
| `fuel` | `UI_POS_Market_Cat_Fuel` | 10 |
| `medicine` | `UI_POS_Market_Cat_Medicine` | 20 |
| `food` | `UI_POS_Market_Cat_Food` | 30 |
| `ammunition` | `UI_POS_Market_Cat_Ammunition` | 40 |
| `tools` | `UI_POS_Market_Cat_Tools` | 50 |
| `radio` | `UI_POS_Market_Cat_Radio` | 60 |

### Category Definition

```lua
{
    id = "fuel",                           -- unique identifier
    labelKey = "UI_POS_Market_Cat_Fuel",   -- translation key
    sortOrder = 10,                        -- menu ordering (lower = higher)
    shouldShow = function(ctx)             -- optional visibility gate
        return true
    end,
}
```

### Third-Party Registration

```lua
POS_MarketRegistry.registerCategory({
    id = "radio_parts",
    labelKey = "UI_POS_Category_RadioParts",
    sortOrder = 60,
})
```

---

## 4. Intel Record Schema

Each intel record represents one observation from one source at one time.

```lua
{
    id = string,           -- "POS_INTEL_" .. getTimestampMs()
    categoryId = string,   -- e.g. "fuel"
    source = string,       -- trader/contact display name
    location = string,     -- resolved address or area name
    price = number,        -- quoted price per unit
    stock = string,        -- "none" | "low" | "medium" | "high"
    recordedDay = number,  -- game day when recorded
    confidence = string,   -- "low" | "medium" | "high"
}
```

### Persistence

- **Storage**: Player modData key `POS_MarketIntel` (array of records)
- **Purge cycle**: Expired records (older than `IntelFreshnessDecayDays`)
  removed hourly via `EveryOneMinute` hook
- **No server sync**: Intel is per-player (each survivor builds their own
  intelligence network)

---

## 5. Aggregation Rules

### Per-Category Summary

| Field | Calculation |
|-------|-------------|
| `low` | Minimum price across all fresh records |
| `high` | Maximum price across all fresh records |
| `avg` | Mean price across all fresh records |
| `sourceCount` | Number of distinct sources |
| `freshestDay` | Most recent record's game day |
| `confidence` | Calculated from source count + recency (see below) |
| `trend` | Direction from price history (see below) |

### Confidence Calculation

```
HIGH:   >= 5 sources AND freshest record <= 2 days old
MEDIUM: >= 2 sources AND freshest record <= 7 days old
LOW:    everything else
```

Confidence thresholds are named constants in `POS_Constants`:
- `MARKET_FRESH_DAYS = 2`
- `MARKET_STALE_DAYS = 7`
- `MARKET_EXPIRED_DAYS = 14` (sandbox-configurable)

### Trend Calculation

Calculated from daily average price history:

```
RISING:  latest avg > previous avg × (1 + TREND_RISING_PCT)
FALLING: latest avg < previous avg × (1 - TREND_FALLING_PCT)
STABLE:  within ± threshold
UNKNOWN: fewer than 2 data points
```

Threshold constants: `TREND_RISING_PCT = 0.02`, `TREND_FALLING_PCT = 0.02`

---

## 6. Exchange / Stockmarket

The Exchange extends the existing investment system with commodity indices
derived from aggregated market data.

### Commodity Index

- **Base value**: 100.0 (at world start or first data point)
- **Current value**: weighted average of known prices for the category,
  normalised against the base
- **History**: daily index values stored in modData (`POS_PriceHistory`)

### Market Sentiment

Derived from the overall direction of all tracked indices:

```
BULLISH:  majority of indices rising
BEARISH:  majority of indices falling
NEUTRAL:  mixed or insufficient data
```

### Portfolio

Extends the existing investment system:
- Existing `POS_InvestmentLog` investments become "positions"
- Future commodity futures/options build on the same data model
- Portfolio screen aggregates all active positions with P&L

---

## 7. Data Freshness Decay

| Age | Classification | Translation Key | Colour |
|-----|---------------|-----------------|--------|
| 0-2 days | Fresh | `UI_POS_Market_Fresh` | `success` (green) |
| 3-7 days | Stale | `UI_POS_Market_Stale` | `warn` (yellow) |
| 8+ days | Expired | `UI_POS_Market_Expired` | `error` (red) |

- Expired records are excluded from aggregation
- Records older than `IntelFreshnessDecayDays` (sandbox, default 14) are purged
- Freshness classification uses `POS_Constants.MARKET_*_DAYS` thresholds

---

## 8. Sandbox Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `EnableMarkets` | boolean | true | Master toggle for market intelligence system |
| `EnableExchange` | boolean | false | Master toggle for exchange (disabled until feature-complete) |
| `IntelFreshnessDecayDays` | integer | 14 | Days before intel records are purged |
| `MarketBroadcastInterval` | integer | 120 | Minutes between server market data broadcasts |

All market mechanics that could be considered harsh or opinionated must have
sandbox toggles, per the design guidelines philosophy.

---

## 9. Screen Hierarchy (Reserved)

These screen IDs are reserved in `POS_Constants` but not yet implemented.
Feature work will create the actual screen files.

```
pos.main
 ├── pos.markets                      Markets hub
 │    ├── pos.markets.commodities     Category list
 │    │    └── pos.markets.commodity.detail  Summary for one commodity
 │    ├── pos.markets.traders         Known traders (paginated)
 │    ├── pos.markets.reports         Compiled market reports
 │    └── pos.markets.ledger          Price history ledger
 └── pos.exchange                     Exchange hub (replaces stockmarket)
      ├── pos.exchange.overview       Commodity index dashboard
      ├── pos.exchange.commodity      Single commodity index detail
      └── pos.exchange.portfolio      Player positions + P&L
```

Menu categories registered:
- `pos.markets` (parent: `pos.main`, sortOrder: 40)
- `pos.exchange` (parent: `pos.main`, sortOrder: 50)

---

## 10. UX Rules for Economic Screens

These rules supplement `design-guidelines.md` Section 2 for economic content:

1. **Max 15 lines of information** per screen
2. **Summary before detail** — always show aggregated view first
3. **Freshness indicator** on every data display
4. **Confidence indicator** on every aggregated view
5. **Pagination** for lists exceeding 5 items
6. **Text-based trend indicators** — "Rising", "Falling", "Stable" (not charts)
7. **No graphical dashboards** — the interface should resemble early 1990s BBS
   market bulletins
8. **Player-authored feel** — data should feel like it was gathered by survivors
   with pencils and radios, not downloaded from a database
9. **Raw intel and compiled summaries are separate models** — never mix the
   two in the same view

---

## 11. Framework Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_MarketRegistry` | Shared | Commodity category + data provider registration |
| `POS_MarketDatabase` | Shared | Intel record storage + aggregation queries |
| `POS_ExchangeEngine` | Shared | Commodity index calculation + trend + sentiment |
| `POS_MarketService` | Shared | Read-only query facade for UI screens |

### Pipeline Flow

```lua
-- Ingestion (future: timed action creates note → terminal ingests)
POS_MarketDatabase.addRecord(record)

-- Query (UI screens call service layer)
local summary = POS_MarketService.getCommoditySummary("fuel")
-- Returns: { lowPrice, avgPrice, highPrice, sourceCount,
--            freshnessKey, confidenceKey, trendKey, trendPct }

-- Exchange (derived from market data)
local overview = POS_MarketService.getExchangeOverview()
-- Returns: { indices = { fuel = {value, trend}, ... }, sentiment }
```

---

## 12. What This Framework Does NOT Include

These items build ON TOP of the framework and are deferred to feature work:

- Terminal UI screens (`.lua` screen files)
- Raw Market Notes inventory item + Compiled Market Reports item
- Timed "discuss and write notes" field action
- Paper + pen consumption mechanics
- NPC trader generation system
- Server-side market data broadcasting
- Physical item trading at world contacts
- Biomass mod tie-in (paper production → market notes)
