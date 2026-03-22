# Satellite Passive Background Data Acquisition — Design Document

> **Status:** Design only — not yet implemented.
> **Prerequisite:** Satellite wiring connection (§5.6).
> **Phase:** Future (post-Living Market Phase 1).

## Overview

When a satellite dish is physically wired to a terminal, the player can enable **Passive Collection Mode** — a persistent background process that gathers raw signal data from the satellite uplink. This transforms the satellite from a one-shot broadcast tool into an always-on intelligence appliance.

## Three Operating States

### 1. Idle
- Satellite linked but not actively collecting
- Negligible standby power drain
- No passive data gain
- Terminal can still be used manually for all existing functions

### 2. Passive Collection
- Low-interaction background work
- **Heavy continuous power drain** (generator fuel or grid)
- Generates raw intermediary data over time (not finished intelligence)
- Less efficient than manual operations short-term, more efficient over very long durations
- Only functions while powered + satellite link intact + terminal in collection mode

### 3. Deep Sweep / Intensive Scan
- Temporary boosted mode (late-game)
- Extremely high power drain
- Higher chance of rare/high-value intercepts
- Increased wear, heat, interruption risk
- Suited for advanced base infrastructure

## Core Design Principle

Passive collection must feel like **feeding a hungry machine**:
- Generator fuel burn is visible and painful
- Priority conflicts with refrigeration, lighting, industry
- Power stability matters — outages cause partial data loss
- Making it aspirational: a reward for an advanced base, not a default habit

## Data Pipeline

```
Satellite → Passive Collection → Raw Data Backlog → Analysis/Processing → Useful Intel
```

Passive mode generates **intermediate resources** (not finished intelligence):
- Raw signal logs
- Recorded traffic fragments
- Market chatter snippets
- Reconnaissance notes
- Unidentified transmissions
- Signal traces

The player/terminal then **processes** these into useful outputs. This preserves player agency — the machine helps the player rather than replacing them.

## Power Model

- **Standby draw** when linked but idle
- **Active draw** while passively collecting (one of the most expensive always-on systems)
- **Surge draw** when starting scans, processing batches, or transmitting

## Failure Behaviours

If power cuts out during passive collection:
- No data gain for the outage period
- Small backlog corruption chance
- Interrupted sweep progress
- Partial data retained
- Terminal logs the outage
- Restart delay before reacquiring stable lock

Not brutal punishment — just enough to make stable infrastructure matter.

## Output Quality Factors

- Satellite dish placement (rooftop = better)
- Terminal tier
- Operator SIGINT skill
- Power stability
- Band access (AZAS frequency coverage)
- Weather / atmospheric interference
- Collection duration (longer ≠ automatically perfect)

## Future Expansion Hooks

- Wire degradation over time
- Environmental/zombie break chance
- Lightning/storm disruption
- Concealed vs exposed installation bonuses
- Signal quality bonuses for elevation
- Amplifiers / boosters / junction boxes
- Military-grade shielded cable upgrade path
