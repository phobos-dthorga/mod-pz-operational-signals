# POSnet Data-Recorder — Design & Styling Guide

**Branch**: `dev/data-recorder` (future)
**Date**: 2026-03-20
**Status**: Design phase — implementation not started
**Prerequisites**: v0.11.0 (Market Exchange Framework) merged to main

---

## Executive Summary

The Data-Recorder is a **physical, player-carried data buffer** that unifies
POSnet's fragmented acquisition pipeline into a single coherent object. It sits
between the existing sensor/device layer (camcorder, field logger, scanner radio)
and the terminal processing layer, replacing the current pattern where devices
write directly to VHS tapes or internal memory with no intermediary.

This is not a new standalone system. It is the **missing middle layer** in an
existing data lifecycle that already looks like this:

```
WORLD → SIGNAL → DEVICE → [???] → TERMINAL → MARKET
```

The recorder fills that gap:

```
WORLD → SIGNAL → DEVICE → RECORDER → TERMINAL → ARTIFACT → MARKET
```

The recorder decouples acquisition from processing. Sensors feed raw data chunks
into the recorder's buffer. The player later processes that buffer at a terminal
(or TV station) to produce tradeable intelligence artifacts (market notes, field
reports, compiled reports). This eliminates manual recon fatigue while preserving
the physical, diegetic feel of POSnet's information economy.

---

## 1. What the Data-Recorder Is

A **portable, belt-mounted electronic device** that continuously captures and
buffers raw data from attached or nearby POSnet-compatible sensors. Think of it
as a 1990s field data logger — a ruggedized box with a small LCD counter, a
media slot, and ports for sensor cables.

It is:
- A persistent, player-carried data cache
- The single authoritative ingestion point for all sensor data
- A physical object with condition, weight, and loot presence
- Media-dependent (requires insertable storage media to record beyond its
  internal buffer)

It is NOT:
- A replacement for the terminal (processing still happens there)
- A replacement for sensors (it has no scanning capability of its own)
- A magical database (capacity is limited, media degrades)
- A UI element (it is an inventory item with context-menu interactions)

---

## 2. Why It Must Exist

### 2.1 Current Pain Points

The existing pipeline has three fragmentation issues:

1. **Sensors write to different targets**. The camcorder writes to VHS tapes.
   The field logger writes to an internal 10-entry buffer OR a VHS tape. The
   scanner radio writes to the building cache OR a VHS tape. Each path has
   its own code, its own capacity rules, and its own edge cases.

2. **No intermediate buffer**. When a VHS tape is full, the camcorder stops
   recording entirely. The field logger's 10-entry buffer fills quickly. There
   is no graceful overflow or queuing — data is silently lost.

3. **Manual recon is tedious**. The context-menu "Gather Intel" action requires
   the player to be at a mapped location, have pen and paper, wait through a
   cooldown, and not be in danger. This is correct for intentional intelligence
   gathering but offers no passive alternative beyond equipping a camcorder
   and walking around.

### 2.2 What the Recorder Solves

| Problem | Solution |
|---------|----------|
| Fragmented sensor output | All sensors write to one target: the recorder |
| Data loss on full media | Recorder has a small internal buffer as overflow |
| Manual-only intel for some sources | Recorder passively captures radio intercepts |
| VHS-only storage | Recorder supports multiple media types |
| No data interpretation layer | Terminal can decode/analyze recorder contents |

---

## 3. Physical Item Definition

### 3.1 Item Properties

| Property | Value | Notes |
|----------|-------|-------|
| DisplayName | Data-Recorder | Hyphenated per 1990s field equipment naming |
| DisplayCategory | Electronics | Consistent with existing POSnet devices |
| Weight | 1.2 kg | Heavier than a calculator (0.3), lighter than a camcorder (1.5) |
| ConditionMax | 100 | Degrades with use; repairable with Electronics skill |
| Tags | Electronic | Standard electronic equipment tag |
| Equip slot | Belt / holster | Same as field survey logger |
| Icon | `Item_POS_DataRecorder.png` | New icon required |
| Tooltip | `Tooltip_POS_DataRecorder` | Dynamic tooltip showing buffer status |

### 3.2 Item Script

```
item DataRecorder {
    DisplayCategory = Electronics,
    DisplayName = Data-Recorder,
    ItemType = base:normal,
    Weight = 1.2,
    Icon = Item_POS_DataRecorder,
    Tooltip = Tooltip_POS_DataRecorder,
    ConditionMax = 100,
    Tags = Electronic,
}
```

### 3.3 ModData Schema (Carried on the Item)

| Key | Type | Purpose |
|-----|------|---------|
| `POS_RecorderId` | string | Unique device identifier (UUID-style) |
| `POS_RecorderBufferCount` | integer | Current entries in internal buffer |
| `POS_RecorderBufferCapacity` | integer | Max internal buffer size (default 8) |
| `POS_RecorderMediaType` | string | Currently inserted media type (or `"none"`) |
| `POS_RecorderMediaId` | string | POS_TapeId of inserted media (for event log linking) |
| `POS_RecorderMediaUsed` | integer | Entries written to current media |
| `POS_RecorderMediaCapacity` | integer | Total capacity of current media |
| `POS_RecorderTotalRecorded` | integer | Lifetime recording counter |
| `POS_RecorderLastRegion` | string | Region of most recent recording |
| `POS_RecorderPowered` | boolean | Whether device is currently active |

The internal buffer stores summary metadata only (count, region, timestamp range).
Full entry data is written to the event log system (Layer 3, `recon` subsystem)
keyed by `POS_RecorderId`, consistent with the existing VHS tape event log pattern.

---

## 4. Media System

The recorder accepts insertable storage media through a single slot. Media
determines recording capacity and data fidelity. This extends the existing VHS
tape system with two new media families.

### 4.1 Media Type Comparison

| Media | Capacity | Fidelity | Confidence Mod | Weight | Source |
|-------|----------|----------|----------------|--------|--------|
| VHS-C Tape (Factory) | 20 entries | Standard | 0 BPS | 0.1 kg | World loot |
| VHS-C Tape (Refurbished) | 15 entries | Standard | -1000 BPS | 0.1 kg | Crafting |
| VHS-C Tape (Spliced) | 8 entries | Standard | -2500 BPS | 0.1 kg | Crafting |
| VHS-C Tape (Improvised) | 4 entries | Standard | -5000 BPS | 0.1 kg | Crafting |
| **Microcassette** (new) | 10 entries | High | +1000 BPS | 0.05 kg | World loot (rare) |
| **Microcassette Used** (new) | 10 entries | High | +500 BPS | 0.05 kg | Rewound microcassette |
| **Floppy Disk** (new) | 40 entries | Digital | +2000 BPS | 0.05 kg | World loot (very rare) |
| **Floppy Disk Worn** (new) | 40 entries | Digital | +1000 BPS | 0.05 kg | Degraded floppy |

### 4.2 Media Families

#### VHS-C Tapes (Existing)

Already implemented. 4 quality tiers with crafting lifecycle (blank → recorded
→ review → degrade → worn → recycle/splice). No changes needed — the recorder
simply becomes another device that can write to VHS-C tapes, alongside the
camcorder.

VHS tapes are the **workhorse medium**: plentiful, craftable, moderate capacity.
They represent the bulk of a player's recording budget.

#### Microcassettes (New)

Small dictaphone-style tapes. Higher fidelity than VHS (designed for voice/data
recording rather than video), but lower capacity. Cannot be crafted — found in
offices, police stations, journalism buildings, and emergency services.

The microcassette represents a **quality-over-quantity** trade-off. A player
who finds one gets fewer entries but with a confidence bonus, making each entry
more valuable for market intelligence accuracy.

**Lifecycle**: Fresh → Recorded → Review → Rewound (loses 500 BPS, reusable
once) → Spent (recycle to MagneticTapeScrap).

#### Floppy Disks (New)

3.5-inch floppy disks. Massive capacity (40 entries) and the highest confidence
bonus, but extremely rare and non-renewable. Found only in university computer
labs, government offices, military installations, and tech company offices.

The floppy disk is a **late-game treasure**: when you find one, it represents
a significant intelligence-gathering windfall. It cannot be crafted, repaired,
or recycled. Once full, it can be reviewed at a terminal (not a TV station —
digital media uses the computer directly).

**Lifecycle**: Blank → Recorded → Review at terminal → Worn (capacity intact
but -1000 BPS per cycle) → Eventually corrupt (random chance per cycle, sandbox-
configurable). Corrupt floppies yield MagneticTapeScrap + ElectronicsScrap.

### 4.3 New Item Definitions

```
item Microcassette {
    DisplayCategory = Electronics,
    DisplayName = Microcassette,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_Microcassette,
    Tooltip = Tooltip_POS_Microcassette,
}

item RecordedMicrocassette {
    DisplayCategory = Electronics,
    DisplayName = Recorded Microcassette,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_RecordedMicrocassette,
    Tooltip = Tooltip_POS_RecordedMicrocassette,
}

item RewoundMicrocassette {
    DisplayCategory = Electronics,
    DisplayName = Rewound Microcassette,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_RewoundMicrocassette,
    Tooltip = Tooltip_POS_RewoundMicrocassette,
}

item SpentMicrocassette {
    DisplayCategory = Junk,
    DisplayName = Spent Microcassette,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_SpentMicrocassette,
    Tooltip = Tooltip_POS_SpentMicrocassette,
}

item BlankFloppyDisk {
    DisplayCategory = Electronics,
    DisplayName = Blank Floppy Disk,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_BlankFloppyDisk,
    Tooltip = Tooltip_POS_BlankFloppyDisk,
}

item RecordedFloppyDisk {
    DisplayCategory = Electronics,
    DisplayName = Recorded Floppy Disk,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_RecordedFloppyDisk,
    Tooltip = Tooltip_POS_RecordedFloppyDisk,
}

item WornFloppyDisk {
    DisplayCategory = Electronics,
    DisplayName = Worn Floppy Disk,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_WornFloppyDisk,
    Tooltip = Tooltip_POS_WornFloppyDisk,
}

item CorruptFloppyDisk {
    DisplayCategory = Junk,
    DisplayName = Corrupt Floppy Disk,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_CorruptFloppyDisk,
    Tooltip = Tooltip_POS_CorruptFloppyDisk,
}
```

### 4.4 Media ModData Schema

All insertable media use a unified modData schema (extending the existing VHS
tape pattern):

| Key | Type | Purpose |
|-----|------|---------|
| `POS_MediaId` | string | Unique media identifier (for event log linking) |
| `POS_MediaFamily` | string | `"vhs"`, `"microcassette"`, `"floppy"` |
| `POS_MediaEntryCount` | integer | Current entries recorded |
| `POS_MediaCapacity` | integer | Maximum entries |
| `POS_MediaFidelity` | string | `"standard"`, `"high"`, `"digital"` |
| `POS_MediaConfidenceMod` | integer | BPS modifier for this specific media instance |
| `POS_MediaWear` | integer | Degradation percentage (0-100) |
| `POS_MediaRegion` | string | Region of first recorded entry |
| `POS_MediaCycleCount` | integer | Number of record/review cycles completed |

**Migration note**: Existing VHS tapes use `POS_Tape*` prefixed keys. A
one-time migration on first load renames these to `POS_Media*` keys and adds
`POS_MediaFamily = "vhs"`. The migration sets a modData guard flag to prevent
re-processing. Backward compatibility: if `POS_TapeId` exists but `POS_MediaId`
does not, the tape is treated as un-migrated and processed transparently.

---

## 5. Data Chunk Architecture

### 5.1 What Is a Chunk?

A "chunk" is a single atomic unit of recorded data — one observation from one
source at one moment. This replaces the current model where different sensors
produce different item types (photos, tape entries, buffer entries) with a
unified data format.

### 5.2 Chunk Schema

```lua
{
    chunkType = string,       -- "building_scan", "radio_intercept", "market_observation",
                              -- "signal_probe", "environmental"
    sourceDevice = string,    -- "camcorder", "logger", "radio", "manual"
    region = string,          -- map region identifier
    locationX = integer,      -- tile X
    locationY = integer,      -- tile Y
    signalQuality = integer,  -- BPS (from source device confidence)
    mediaFidelity = integer,  -- BPS (from recording media)
    timestamp = integer,      -- game day number
    decoded = boolean,        -- false until processed at terminal
    payload = string,         -- pipe-delimited payload (type-specific)
}
```

### 5.3 Chunk Types

| Type | Source | Payload Contents | Terminal Output |
|------|--------|------------------|-----------------|
| `building_scan` | Camcorder, Logger | `roomDef\|buildingType\|tileCount` | Building cache entry + market observation |
| `radio_intercept` | Scanner Radio | `band\|frequency\|transmitRange\|broadcastType` | Market broadcast data or mission intel |
| `market_observation` | Manual recon | `categoryId\|sourceContact\|priceEstimate\|stockLevel` | RawMarketNote |
| `signal_probe` | Any radio | `band\|signalStrength\|noiseFloor` | Signal intelligence (frequency mapping) |
| `environmental` | Logger | `weatherState\|temperature\|zombieDensity` | Regional threat assessment (future) |

### 5.4 Chunk Storage

Chunks are NOT stored as structured Lua tables in modData. That would cause
unbounded growth. Instead:

- **Summary counters** in item modData (entry count, capacity, region)
- **Full chunk data** in the event log system (Layer 3, `recon` subsystem)
- Each chunk is one line in the event log, pipe-delimited
- Linked to the recorder/media via `POS_MediaId` in the `actorId` field

This is the exact same pattern used by VHS tapes today (`POS_TapeManager`
writes to the event log keyed by `POS_TapeId`). The recorder simply
generalizes it.

---

## 6. Sensor Integration

### 6.1 Current Flow (Before Recorder)

```
Camcorder (equipped) ──► POS_PassiveRecon ──► VHS tape modData + event log
Logger (equipped)    ──► POS_PassiveRecon ──► internal buffer OR VHS tape
Radio (powered on)   ──► POS_PassiveRecon ──► building cache OR VHS tape
Manual recon         ──► POS_MarketReconAction ──► RawMarketNote item
```

Each path has its own writing logic, capacity checks, and failure modes.

### 6.2 New Flow (With Recorder)

```
Camcorder (equipped) ──┐
Logger (equipped)    ──┼──► POS_DataRecorderService.appendChunk() ──► Recorder buffer/media
Radio (powered on)   ──┘                                                    │
                                                                            ▼
Manual recon         ──► POS_MarketReconAction ──► Recorder OR direct note
                                                                            │
                                                   ┌────────────────────────┘
                                                   ▼
                                        Terminal / TV Station
                                                   │
                                                   ▼
                              RawMarketNote / FieldReport / CompiledMarketReport
```

### 6.3 Recorder Presence Detection

`POS_PassiveRecon.lua` currently iterates equipped devices and processes each
independently. With the recorder, the scan cycle becomes:

1. Check if player has a **powered Data-Recorder** equipped (belt slot)
2. If YES: all sensor data routes through the recorder
3. If NO: sensors fall back to their existing direct-write behavior (backward
   compatible — no recorder required to use camcorder/logger)

This means the recorder is an **upgrade**, not a gate. Players who never find
a recorder continue using the existing system unchanged.

### 6.4 Sensor Priority When Recorder Is Present

When the recorder is equipped, the scan cycle changes:

| Step | Action |
|------|--------|
| 1 | `POS_PassiveRecon` detects equipped scanner devices (existing logic) |
| 2 | For each active device, generate a chunk (instead of writing to tape) |
| 3 | Call `POS_DataRecorderService.appendChunk(recorder, chunk)` |
| 4 | Service writes to media if present, else to internal buffer |
| 5 | If both media and buffer are full, chunk is dropped (with debug log) |

The stagger rule (one device per minute cycle) still applies. The recorder
does not change scanning frequency — only the destination.

---

## 7. Recording Behavior

### 7.1 Automatic Recording

When the recorder is equipped and powered:

- Sensors route all output through the recorder
- Radio intercepts are captured passively (even without a dedicated scanner
  radio device, if the player has any powered radio nearby — existing
  `POS_RadioInterception` behavior, now writing to the recorder)
- No player interaction required beyond equipping the device

### 7.2 Internal Buffer

The recorder has a small built-in buffer (default 8 entries, sandbox-
configurable via `RecorderInternalBufferSize`). This serves as overflow
when no media is inserted or when media is full.

Buffer behavior:
- FIFO eviction when full (oldest chunk dropped, with debug log)
- Buffer contents are preserved across save/load (stored in item modData
  as a count + event log entries)
- Buffer can be manually flushed at a terminal without media

### 7.3 Media Recording

When media is inserted, chunks write to media first. The internal buffer
is used only when:
- No media is present
- Media is full (overflow buffer)
- Media is being ejected/swapped

### 7.4 Media Insertion / Ejection

Right-click context menu on the Data-Recorder:

| Action | Condition | Effect |
|--------|-----------|--------|
| Insert Media | Recorder has no media; player has compatible media in inventory | Opens media selection submenu |
| Eject Media | Recorder has media inserted | Returns media item to inventory |
| View Status | Always | Shows buffer/media status tooltip |

Media selection submenu lists all compatible media in inventory, sorted by
family (floppy > microcassette > VHS-C) then by quality tier descending.

### 7.5 Power

The recorder requires battery power (uses item condition as battery proxy,
same as the Portable Computer). Condition drains slowly while equipped and
active. Rate is sandbox-configurable (`RecorderPowerDrainRate`, default 0.5%
per in-game hour).

When condition reaches 0, the recorder powers off. Recording stops. The
player must repair it (Electronics skill + ElectronicsScrap) to resume.

---

## 8. Terminal Processing

### 8.1 The Interpretation Layer

The PDF concept document identified a missing **data interpretation layer** in
POSnet's pipeline. The recorder provides the physical container; the terminal
provides the interpretation.

Current flow: sensor → artifact (direct, no transformation)
New flow: sensor → recorder (raw chunks) → terminal (decode + analyze) → artifact

The terminal "decodes" raw chunks into meaningful intelligence. This is where
signal quality, media fidelity, and device confidence all combine to determine
the quality of the output.

### 8.2 New Terminal Screen: Data Management

Screen ID: `pos.data` (registered under `pos.main`, sortOrder 25)

```
POSnet > Data Management
═══════════════════════════════════════
  RECORDER: POS-DR-4A7B  [■■■■■□□□] 5/8 buffer
  MEDIA:    VHS-C (Factory)  [■■■■■■■■■■■■░░░░░░░░] 12/20

  [1] Process All Data          (decode + generate artifacts)
  [2] Process Selected          (choose chunk types to process)
  [3] View Raw Buffer           (inspect unprocessed chunks)
  [4] Eject Media               (return media to inventory)
  [5] Flush Buffer to Media     (move buffer contents to media)
  [6] Media History             (past media statistics)

  [0] Back
═══════════════════════════════════════
```

### 8.3 Processing Actions

#### Process All Data

Decodes all chunks on the recorder (buffer + media) and generates output
artifacts based on chunk type:

| Chunk Type | Output Artifact | Requires |
|------------|----------------|----------|
| `building_scan` | Building cache entry + optional RawMarketNote | Paper + pen (for note) |
| `radio_intercept` | RawMarketNote (if market data) or mission intel | Paper + pen |
| `market_observation` | RawMarketNote (enhanced with recorder metadata) | Paper + pen |
| `signal_probe` | Signal intelligence record (terminal-only, no item) | Nothing |
| `environmental` | Regional assessment (terminal-only, no item) | Nothing |

Processing time: 30 seconds per chunk (sandbox-configurable via
`RecorderProcessingTimePerChunk`). Uses a timed action, interruptible by
danger detection.

**Paper and pen remain the final medium.** This is a core POSnet design
principle (see `design-guidelines.md` Section 12.5): all intelligence that
leaves the terminal as a physical item requires pen and paper. The recorder
automates collection, not transcription.

#### Process Selected

Same as above but the player chooses which chunk types to process. Useful
when paper is scarce and the player wants to prioritize market data over
building scans.

#### View Raw Buffer

Lists unprocessed chunks with summary information:

```
  RAW BUFFER — 5 entries
  ─────────────────────────────
  [1] BLDG  Muldraugh  Day 14  ■■■░ (med confidence)
  [2] RADIO  Amateur   Day 14  ■■░░ (low confidence)
  [3] BLDG  Muldraugh  Day 14  ■■■■ (high confidence)
  [4] MKT   Rosewood   Day 15  ■■■░ (med confidence)
  [5] RADIO  Military  Day 15  ■■■■ (high confidence)
```

No interaction beyond viewing. Processing happens via [1] or [2].

### 8.4 Confidence Calculation at Processing Time

When a chunk is decoded, its final confidence is calculated from the full
chain:

```
finalConfidence = baseDeviceConfidence
                + mediaFidelityMod
                + tapeQualityMod (if VHS)
                + recorderConditionMod
                + carryBonusMod (stacked device bonuses)
                + signalQualityMod (for radio intercepts)
```

All values in BPS, converted to percentage via existing formula:
`effective = max(10, 50 + floor(totalBPS / 100))`

| Factor | BPS Range | Notes |
|--------|-----------|-------|
| Camcorder base | +3000 | High-quality device |
| Logger base | +1000 | Medium-quality device |
| Radio base | -5000 to 0 | Tier-dependent (existing) |
| Microcassette fidelity | +1000 | High-fidelity media |
| Floppy disk fidelity | +2000 | Digital precision |
| VHS factory fidelity | 0 | Baseline |
| VHS spliced fidelity | -2500 | Degraded media |
| Recorder condition | -50 per missing % | Damaged recorder = noise |
| Carry bonus stack | +500 to +3000 | Existing device bonuses |

### 8.5 Review Location Rules

| Media Family | Review Location | Rationale |
|--------------|----------------|-----------|
| VHS-C tapes | TV station (CraftBench entity) | Requires VCR playback — existing rule |
| Microcassettes | Any location (right-click recorder) | Dictaphone playback is portable |
| Floppy disks | Terminal (desktop computer) | Requires computer to read digital data |
| Internal buffer | Terminal (desktop computer) | Data is in the recorder's memory |

This means:
- VHS-heavy players need a TV station setup (existing requirement, unchanged)
- Microcassette users can process in the field (portable advantage)
- Floppy disk users must be at a computer (but get the best data)
- Buffer-only users must be at a computer (same as floppy)

---

## 9. Crafting Recipes

### 9.1 New Recipes

| Recipe | Inputs | Output | Time | Skill | Notes |
|--------|--------|--------|------|-------|-------|
| Rewind Microcassette | 1 RecordedMicrocassette + 1 Pencil (keep) | 1 RewoundMicrocassette | 60s | — | Pencil-in-spoolhole trick |
| Recycle Microcassette | 1 SpentMicrocassette | 1 MagneticTapeScrap | 60s | — | Same as VHS recycle |
| Review Microcassette | 1 RecordedMicrocassette + Paper + Pen (keep) | 1 RawMarketNote | 200s | — | Portable, no TV needed |
| Review Floppy Disk | 1 RecordedFloppyDisk + Paper + Pen (keep) | 1 RawMarketNote | 150s | — | Requires POS_TerminalStation entity |
| Salvage Corrupt Floppy | 1 CorruptFloppyDisk + 1 Screwdriver (keep) | 1 ElectronicsScrap | 60s | Electrical 2 | Reclaim materials |
| Repair Data-Recorder | 1 DataRecorder + 1 ElectronicsScrap + 1 Screwdriver (keep) | 1 DataRecorder | 300s | Electrical 3 | Restores condition |

### 9.2 Existing Recipes — No Changes

All 6 existing VHS tape recipes remain unchanged. The recorder is additive —
it does not replace or modify any existing crafting paths.

### 9.3 Recipe Category

All new recipes use the existing `PhobosFieldOps` category for consistency.

---

## 10. Gameplay Loops

### Loop 1 — Passive Accumulation (Zero-Click)

The player equips the recorder on their belt and goes about their business.
As they walk, drive, or explore:

- Equipped camcorder/logger generates scan chunks → recorder captures them
- Nearby powered radio generates intercept chunks → recorder captures them
- No player interaction required
- Data accumulates silently on inserted media

This replaces the current "equip camcorder and hope you remembered to
insert a tape" workflow with a unified, set-and-forget system.

### Loop 2 — Media Management (Light Interaction)

Periodically, the player checks their recorder status:

- Right-click → View Status → see buffer/media fullness
- When media is full: eject, insert fresh media
- When at base: swap to high-capacity media (floppy) for extended trips

This adds a resource management dimension without tedium. Media scarcity
creates natural gameplay tension — do you use your last blank floppy for
a dangerous expedition or save it?

### Loop 3 — Terminal Processing (Intentional)

At a terminal (or TV station for VHS), the player processes recorded data:

- Opens Data Management screen
- Chooses "Process All" or selects specific chunk types
- Waits through timed action (30s per chunk)
- Receives RawMarketNotes, field reports, building cache updates
- Paper + pen consumed per physical artifact produced

This preserves the **player effort = better information** principle while
automating the tedious collection phase.

### Loop 4 — Economy Injection (Existing Pipeline)

Produced artifacts feed directly into existing systems:

- RawMarketNotes → terminal ingestion → `POS_MarketDatabase.addRecord()`
- Building cache entries → `POS_BuildingCache` enrichment
- Field reports → mission completion validation
- Compiled reports → aggregated from multiple notes (existing recipe)

No changes needed to downstream systems. The recorder changes how data
enters the pipeline, not what happens after.

---

## 11. Loot Distribution

### 11.1 Data-Recorder

| Location | Rarity | Notes |
|----------|--------|-------|
| Military checkpoints | Rare | Field survey equipment |
| Research laboratories | Rare | Scientific data logging |
| University tech labs | Uncommon | Academic equipment |
| Government offices | Rare | Administrative data systems |
| Ranger stations | Uncommon | Environmental monitoring |
| TV studios | Rare | Broadcast data recording |

The recorder is deliberately **rare**. It is an upgrade item, not a
starter item. Players should typically find their first one 2-4 weeks
into a playthrough, after they've already been using the manual recon
system and VHS tape pipeline.

### 11.2 Microcassettes

| Location | Rarity | Notes |
|----------|--------|-------|
| Office buildings | Uncommon | Dictaphone tapes |
| Police stations | Uncommon | Interview recordings |
| Journalism offices | Common | Reporter's tapes |
| Medical offices | Uncommon | Dictated notes |
| Courthouses | Uncommon | Deposition recordings |

### 11.3 Floppy Disks

| Location | Rarity | Notes |
|----------|--------|-------|
| University computer labs | Rare | Academic data storage |
| Government offices | Very rare | Administrative records |
| Military installations | Very rare | Classified data carriers |
| Tech company offices | Rare | Software distribution |
| Libraries (reference desk) | Very rare | Digital catalogue backups |

### 11.4 Foraging

| Item | Zone | Rarity | Notes |
|------|------|--------|-------|
| SpentMicrocassette | Urban, Suburban | Uncommon | Recyclable to scrap |
| CorruptFloppyDisk | Urban | Rare | Salvageable for electronics |

---

## 12. Sandbox Options

### 12.1 New Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `EnableDataRecorder` | boolean | true | — | Master toggle for the data-recorder system |
| `RecorderInternalBufferSize` | integer | 8 | 4-20 | Internal buffer capacity (entries) |
| `RecorderPowerDrainRate` | integer | 50 | 0-200 | Condition drain per in-game hour (hundredths of %) |
| `RecorderProcessingTimePerChunk` | integer | 30 | 10-120 | Seconds per chunk when processing at terminal |
| `EnableMicrocassettes` | boolean | true | — | Whether microcassettes spawn in loot |
| `EnableFloppyDisks` | boolean | true | — | Whether floppy disks spawn in loot |
| `FloppyCorruptionChance` | integer | 5 | 0-25 | % chance of corruption per review cycle |
| `MicrocassetteMaxRewins` | integer | 1 | 0-3 | Times a microcassette can be rewound |

### 12.2 Existing Options — No Changes

All existing passive recon, VHS tape, and terminal power options continue
to function as-is. The recorder respects `EnablePassiveRecon`,
`TapeDegradationRate`, `CamcorderScanRadius`, etc.

---

## 13. Module Architecture

### 13.1 New Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_DataRecorderService.lua` | Shared | Core recorder logic: append, eject, flush, capacity checks |
| `POS_MediaManager.lua` | Shared | Unified media handling (extends POS_TapeManager for new types) |
| `POS_ChunkProcessor.lua` | Shared | Decodes raw chunks into intelligence artifacts |
| `POS_Screen_DataManagement.lua` | Client | Terminal screen for recorder data management |
| `POS_RecorderContextMenu.lua` | Client | Right-click context menu for the recorder item |

### 13.2 Modified Modules

| Module | Change |
|--------|--------|
| `POS_PassiveRecon.lua` | Add recorder-routing path alongside existing direct-write |
| `POS_RadioInterception.lua` | Route intercepts through recorder when present |
| `POS_TapeManager.lua` | Refactor to delegate media operations to `POS_MediaManager` |
| `POS_ReconDeviceRegistry.lua` | Register DataRecorder as a device (no scan, buffer-only) |
| `POS_CraftCallbacks.lua` | Add callbacks for new recipes |
| `POS_Constants.lua` | Add chunk type constants, media family constants, screen IDs |

### 13.3 Unchanged Modules

The following are explicitly NOT modified:

- `POS_MarketNoteGenerator.lua` — output format unchanged
- `POS_PriceEngine.lua` — pricing unchanged
- `POS_MarketDatabase.lua` — record schema unchanged
- `POS_EventLog.lua` — already supports arbitrary event types
- `POS_BuildingCache.lua` — already accepts external entries
- `POS_ScreenManager.lua` — screen registration is additive
- All existing terminal screens — no UI changes needed

---

## 14. Persistence Strategy

Following the established 3-layer model from `persistence-architecture.md`:

### Layer 1 (World ModData): No changes

The recorder does not introduce new world state. All recorder data is
per-player (carried on items).

### Layer 2 (Player ModData): Minimal additions

| Field | Type | Purpose |
|-------|------|---------|
| `recorderTutorialShown` | boolean | One-time tutorial popup guard |

### Layer 2b (Player File Store): No changes

Recorder data lives on the item itself (modData) and in the event log.
No new player file store sections needed.

### Layer 3 (Event Logs): Extended

New event types in the `recon` subsystem:

| Event Type | Fields | Purpose |
|------------|--------|---------|
| `recorder_chunk` | chunkType, sourceDevice, region, signalQuality, mediaFidelity | Raw chunk recorded |
| `recorder_process` | chunkType, outputType, confidence, artifactCount | Chunk decoded at terminal |
| `media_insert` | mediaFamily, mediaId, capacity | Media inserted into recorder |
| `media_eject` | mediaFamily, mediaId, usedEntries | Media removed from recorder |

### Hybrid Pattern

Exactly as the PDF recommended:
- **Active buffer** → item modData (small, bounded by `RecorderInternalBufferSize`)
- **Full chunk data** → event log files (append-only, disposable)
- **Processed output** → existing systems (market database, building cache)

---

## 15. Icon Pipeline

### 15.1 New Icons Required

| Icon | Item | Style Notes |
|------|------|-------------|
| `Item_POS_DataRecorder.png` | Data-Recorder | Ruggedized box with LCD counter, belt clip, antenna stub. Muted olive/grey palette. Small red LED indicator. |
| `Item_POS_Microcassette.png` | Microcassette (blank) | Tiny cassette, clear window showing tape reels. Warm grey. |
| `Item_POS_RecordedMicrocassette.png` | Recorded Microcassette | Same as blank but with visible tape used (dark window). Small label sticker. |
| `Item_POS_RewoundMicrocassette.png` | Rewound Microcassette | Same form factor, slightly worn edges, pencil mark on label. |
| `Item_POS_SpentMicrocassette.png` | Spent Microcassette | Cracked shell, visible tape crinkle through window. |
| `Item_POS_BlankFloppyDisk.png` | Blank Floppy Disk | 3.5" floppy, blue/black, metal slider, white label area. |
| `Item_POS_RecordedFloppyDisk.png` | Recorded Floppy Disk | Same but with handwritten label (scribbled text). |
| `Item_POS_WornFloppyDisk.png` | Worn Floppy Disk | Bent corner, scratched surface, faded label. |
| `Item_POS_CorruptFloppyDisk.png` | Corrupt Floppy Disk | Cracked shell, exposed magnetic disk visible. |

### 15.2 Specifications

Consistent with existing POSnet icon pipeline (`docs/passive-recon-design.md`
Section 10):

- **Dimensions**: 128x128 pixels, RGBA PNG
- **Style**: Muted post-apocalyptic palette, slight wear/grime aesthetic
- **Background**: Transparent
- **Naming**: `Item_POS_<ItemName>.png`
- **Generator**: gpt-image-1 (~$0.18 per icon)
- **Estimated cost**: 9 icons x $0.18 = ~$1.62

---

## 16. Translation Keys

### 16.1 Item Names (ItemName.json)

```
"ItemName_DataRecorder": "Data-Recorder",
"ItemName_Microcassette": "Microcassette",
"ItemName_RecordedMicrocassette": "Recorded Microcassette",
"ItemName_RewoundMicrocassette": "Rewound Microcassette",
"ItemName_SpentMicrocassette": "Spent Microcassette",
"ItemName_BlankFloppyDisk": "Blank Floppy Disk",
"ItemName_RecordedFloppyDisk": "Recorded Floppy Disk",
"ItemName_WornFloppyDisk": "Worn Floppy Disk",
"ItemName_CorruptFloppyDisk": "Corrupt Floppy Disk"
```

### 16.2 Recipe Names (Recipes.json)

```
"Recipe_RewindMicrocassette": "Rewind Microcassette",
"Recipe_RecycleMicrocassette": "Recycle Microcassette",
"Recipe_ReviewMicrocassette": "Review Microcassette",
"Recipe_ReviewFloppyDisk": "Review Floppy Disk",
"Recipe_SalvageCorruptFloppy": "Salvage Corrupt Floppy Disk",
"Recipe_RepairDataRecorder": "Repair Data-Recorder"
```

### 16.3 UI Strings (UI.json)

```
"UI_POS_DataManagement_Header": "Data Management",
"UI_POS_DataManagement_ProcessAll": "Process All Data",
"UI_POS_DataManagement_ProcessSelected": "Process Selected",
"UI_POS_DataManagement_ViewBuffer": "View Raw Buffer",
"UI_POS_DataManagement_EjectMedia": "Eject Media",
"UI_POS_DataManagement_FlushBuffer": "Flush Buffer to Media",
"UI_POS_DataManagement_MediaHistory": "Media History",
"UI_POS_DataManagement_NoRecorder": "No Data-Recorder connected",
"UI_POS_DataManagement_BufferEmpty": "Buffer empty",
"UI_POS_DataManagement_MediaFull": "Media full — eject and insert new media",
"UI_POS_DataManagement_Processing": "Processing data...",
"UI_POS_DataManagement_ChunkDecoded": "Decoded: %1",
"UI_POS_DataManagement_NoPaper": "Paper and writing implement required",
"UI_POS_Recorder_Status": "Status",
"UI_POS_Recorder_Buffer": "Buffer: %1/%2",
"UI_POS_Recorder_Media": "Media: %1 (%2/%3)",
"UI_POS_Recorder_NoMedia": "No media inserted",
"UI_POS_Recorder_Powered": "Active",
"UI_POS_Recorder_Unpowered": "No power",
"UI_POS_Recorder_InsertMedia": "Insert Media",
"UI_POS_Recorder_EjectMedia": "Eject Media",
"UI_POS_Recorder_ViewStatus": "View Status",
"UI_POS_Media_VHS": "VHS-C Tape",
"UI_POS_Media_Microcassette": "Microcassette",
"UI_POS_Media_Floppy": "Floppy Disk",
"UI_POS_Chunk_BuildingScan": "Building Scan",
"UI_POS_Chunk_RadioIntercept": "Radio Intercept",
"UI_POS_Chunk_MarketObservation": "Market Observation",
"UI_POS_Chunk_SignalProbe": "Signal Probe",
"UI_POS_Chunk_Environmental": "Environmental"
```

### 16.4 Sandbox Strings (Sandbox.json)

Standard pattern: `POS_<OptionName>` for label, `POS_<OptionName>_tooltip`
for tooltip. 8 new options = 16 new translation keys.

### 16.5 Tooltip Strings (Tooltip.json)

Dynamic tooltips for the recorder and all new media types, following the
existing `POS_NoteTooltip` provider pattern via
`PhobosLib.registerTooltipProvider()`.

---

## 17. Migration & Backward Compatibility

### 17.1 No Breaking Changes

The recorder is **purely additive**. Players who never find a Data-Recorder
continue using the existing camcorder → VHS tape → TV review pipeline
exactly as before. No existing items, recipes, or behaviors are removed
or modified.

### 17.2 VHS ModData Key Migration

When `POS_MediaManager` first encounters a VHS tape with old-style
`POS_Tape*` keys, it transparently reads them and writes the new
`POS_Media*` equivalents. The old keys are preserved (not deleted) for
one version cycle to allow rollback. A modData flag
`POS_MediaMigrated = true` prevents re-processing.

### 17.3 Existing Recordings

VHS tapes recorded before the Data-Recorder update continue to work at
TV stations exactly as before. Their `POS_TapeId` event log entries
remain valid and accessible.

---

## 18. Cross-Mod Integration

### 18.1 PhobosLib Dependencies

New PhobosLib functions needed (to be added before recorder implementation):

| Function | Purpose |
|----------|---------|
| `PhobosLib.generateUUID()` | Unique recorder/media IDs (may already exist or use timestamp) |

All other PhobosLib functions used are already available (v1.40.0+):
`isDangerNearby()`, `debug()`, `iterateItems()`, `damageItemCondition()`,
`registerTooltipProvider()`, `createReadableDocument()`, `formatPrice()`.

### 18.2 PhobosNotifications

Watchlist alerts can reference recorder-sourced data. No integration
changes needed — the alerts trigger from `POS_MarketDatabase` records
regardless of source.

### 18.3 PCP / PIP Cross-Mod

If PhobosChemistryPathways or PhobosIndustrialPathology are active, their
registered market categories receive recorder-sourced data through the
existing `POS_ItemPool.registerItem()` pathway. No changes needed.

---

## 19. Implementation Phases

### Phase 1 — Core Recorder (Minimum Viable)

- `POS_DataRecorderService.lua` — buffer management, append, flush
- `POS_MediaManager.lua` — unified media abstraction (VHS only initially)
- `DataRecorder` item definition + icon
- `POS_PassiveRecon` recorder routing (with fallback to existing behavior)
- `POS_RecorderContextMenu.lua` — insert/eject/status
- Basic `POS_Screen_DataManagement.lua` — process all, view buffer
- Sandbox options: `EnableDataRecorder`, `RecorderInternalBufferSize`
- Loot tables for DataRecorder
- Translation keys

### Phase 2 — New Media Types

- Microcassette items (4 lifecycle stages) + icons
- Floppy disk items (4 lifecycle stages) + icons
- `POS_MediaManager` extended for microcassette + floppy families
- New crafting recipes (rewind, recycle, review, salvage, repair)
- Loot tables for microcassettes and floppy disks
- Foraging entries
- `FloppyCorruptionChance` and `MicrocassetteMaxRewinds` sandbox options

### Phase 3 — Advanced Processing

- `POS_ChunkProcessor.lua` — full decode pipeline with confidence chain
- `POS_Screen_DataManagement` enhanced — process selected, media history
- Signal probe and environmental chunk types
- Recorder condition degradation + repair recipe
- Dynamic tooltip for recorder (buffer/media status)
- VHS modData key migration

### Phase 4 — Polish & Integration

- Tutorial popup (one-time, PhobosLib notice system)
- ContextPanel integration (`getContextData()` for Data Management screen)
- NavPanel recorder status indicator (optional)
- Steam Workshop description + changelog updates
- Documentation updates to `design-guidelines.md` and `passive-recon-design.md`

---

## 20. What This Design Does NOT Include

These items build ON TOP of this system and are explicitly deferred:

- **Encrypted data chunks** — military-band intercepts that require a
  decryption skill check or item (future espionage expansion)
- **Networked recorders** — multiplayer data sharing between players
  (requires server-authoritative recorder state, deferred to MP-focused
  update)
- **Recorder upgrades** — craftable modules that increase buffer size,
  reduce power drain, or add scan capability (future progression system)
- **Audio playback** — playing back microcassette/VHS content as ambient
  audio (PZ audio API limitations)
- **Digital media crafting** — manufacturing blank floppy disks (too
  advanced for post-apocalyptic setting; they remain loot-only)

---

## 21. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| ModData growth from recorder metadata | Low | Bounded buffer (8 default), full data in event logs |
| Performance from unified scan routing | Low | Same EveryOneMinute hook, same stagger rules |
| Complexity of 3 media families | Medium | Phase 2 separation — VHS-only in Phase 1 |
| Player confusion about media compatibility | Low | Tooltip system + tutorial popup |
| Save migration for VHS modData keys | Low | Transparent migration with guard flag, old keys preserved |
| Backward compatibility if recorder not found | None | Fallback to existing direct-write behavior |

---

## 22. Success Criteria

The Data-Recorder implementation is successful when:

1. A player can equip the recorder, insert a VHS tape, and walk around for
   30 in-game minutes with a camcorder equipped — then review 10+ market
   notes at a terminal without any manual "Gather Intel" actions
2. All three media families are distinguishable in gameplay value (VHS =
   workhorse, microcassette = quality, floppy = jackpot)
3. Players who never find a recorder experience zero regression in existing
   camcorder/logger/radio functionality
4. The Data Management terminal screen feels native to the existing CRT
   terminal aesthetic (1990s BBS, not modern GUI)
5. No save bloat — recorder modData stays under 200 bytes per item
