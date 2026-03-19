# POSnet Passive Recon System

Design document for the passive reconnaissance subsystem in PhobosOperationalSignals.

---

## 1. Overview

Passive recon replaces manual note-taking with automated device-based reconnaissance.
When a player equips a compatible device **and a Data-Recorder**, the system silently
catalogues nearby buildings, resources, and points of interest without requiring any
player interaction beyond carrying and equipping the hardware.

The result is a stream of raw data chunks stored in the recorder's buffer or inserted
media, which can later be processed at the POSnet terminal to produce market notes,
field reports, and building cache entries.

**IMPORTANT: The Data-Recorder is mandatory.** All passive sensor data routes through
the recorder via `POS_DataRecorderService.appendChunk()`. Without an equipped,
powered recorder, passive scanning does not occur. This is a breaking change from
the original design where devices wrote directly to VHS tapes.

Key design goals:

- **Zero-click operation** -- equip recorder + device, keep moving, data accumulates
- **Hardware matters** -- different devices have different ranges, quality, and trade-offs
- **Consumable media** -- VHS tapes, microcassettes, and floppy disks degrade over time
- **Performance-safe** -- chunk-based scanning on EveryOneMinute, not EveryTick
- **Unified pipeline** -- all sensor data flows through one ingestion point (recorder)

---

## 2. Devices

Four device types serve different reconnaissance roles.

### 2.1 Recon Camcorder

| Property | Value |
|----------|-------|
| Equip slot | Secondary hand |
| Scan radius | 40 tiles |
| Data quality | High |
| Storage | VHS tape required (no internal memory) |
| Noise | Generates noise (mechanical whir) -- attracts zombies at close range |
| Weight | ~2.5 kg |

The camcorder produces the highest-confidence recon entries but occupies the
secondary hand slot, leaving the player unable to hold a flashlight or off-hand
weapon. The noise mechanic adds a risk/reward trade-off: better data at the cost
of zombie attention.

### 2.2 Field Survey Logger

| Property | Value |
|----------|-------|
| Equip slot | Belt / holster |
| Scan radius | 25 tiles |
| Data quality | Medium |
| Storage | VHS tape optional (10-entry internal buffer) |
| Noise | Silent |
| Weight | ~1.5 kg |

The logger is the everyday workhorse. Belt-slot equip means the player retains
full use of both hands. The internal buffer stores up to 10 entries without a
tape, but inserting a tape allows continuous recording beyond that limit. When
the buffer is full and no tape is present, scanning pauses until a tape is
inserted or the buffer is uploaded.

### 2.3 Scanner Radio

| Property | Value |
|----------|-------|
| Equip slot | N/A (vanilla radio, must be powered on) |
| Scan radius | Derived from TransmitRange at runtime (see formula below) |
| Data quality | Tier-dependent (Tier 1 = broadcast only, Tier 4 = high) |
| Storage | Tape optional -- records to tape if available, otherwise building cache only |
| Noise | N/A |
| Power | Battery > 0 OR grid electricity on parent square |

This is NOT a new item. Any vanilla (or modded) radio gains passive scanning
capability when powered on. No hardcoded item names are used -- detection is
fully dynamic via `getDeviceData()`, so radios from any mod work automatically.

#### 2.3.1 Tier Classification

Tiers are derived from the radio's `TransmitRange` at runtime using thresholds
defined in `POS_Constants`:

| Tier | TransmitRange | Classification | Confidence Modifier (BPS) | Broadcast Quality |
|------|---------------|----------------|---------------------------|-------------------|
| 1 | 0 (receive-only) | FM Receiver | -5000 | 30 |
| 2 | 1 -- 2000 | Basic Two-Way | -3000 | 50 |
| 3 | 2001 -- 10000 | Advanced Scanner | -1000 | 70 |
| 4 | > 10000 | Military-Grade | 0 | 90 |

**Tier 1 radios (FM receivers) can only receive market broadcasts -- they do NOT
perform active building scans.** This reflects their receive-only hardware.

#### 2.3.2 Vanilla Radio Reference

All 12 vanilla PZ Build 42 radios and their tier assignments:

| Radio | TransmitRange | Tier | Scan Radius | Notes |
|-------|---------------|------|-------------|-------|
| ValuTech Radio | 0 | 1 | -- | FM receiver, broadcast only |
| Premium Technologies Radio | 0 | 1 | -- | FM receiver, broadcast only |
| Radio (generic) | 0 | 1 | -- | FM receiver, broadcast only |
| Walkie Talkie | 1800 | 2 | 3 | Basic two-way |
| Ham Radio (Type 1) | 5000 | 3 | 10 | Advanced scanner |
| Ham Radio (Type 2) | 7500 | 3 | 15 | Advanced scanner |
| Ham Radio (Type 3) | 10000 | 3 | 20 | Advanced scanner |
| Military Radio (Handheld) | 12000 | 4 | 24 | Military-grade |
| Military Radio (Backpack) | 15000 | 4 | 30 | Military-grade |
| Military Radio (Vehicle) | 20000 | 4 | 40 | Military-grade (max radius) |
| Police Radio | 3000 | 3 | 6 | Advanced scanner |
| Emergency Radio | 2500 | 3 | 5 | Advanced scanner |

#### 2.3.3 Scan Radius Formula

```
radius = floor(TransmitRange / RADIO_RANGE_DIVISOR)
radius = clamp(1, RADIO_MAX_SCAN_RADIUS, radius)
```

Where `RADIO_RANGE_DIVISOR = 500` and `RADIO_MAX_SCAN_RADIUS = 40`.

This means a Walkie Talkie (1800) scans 3 tiles, while a Military Vehicle Radio
(20000) scans the full 40 tiles. FM receivers (TransmitRange=0) do not scan.

#### 2.3.4 Confidence Modifiers

Confidence modifiers are expressed in basis points (BPS) and converted to a
percentage adjustment on the base confidence of 50:

```
effective = max(10, 50 + floor(confidenceMod / 100))
```

| Tier | BPS Modifier | Effective Confidence |
|------|-------------|---------------------|
| 1 | -5000 | -- (no scan) |
| 2 | -3000 | 20 |
| 3 | -1000 | 40 |
| 4 | 0 | 50 |

#### 2.3.5 Power Requirements

A radio must be **powered on** to function as a scanner:

1. **Battery-powered**: `getIsBatteryPowered() == true` and `getPower() > 0`
2. **Grid-powered**: Parent square has electricity (`sq:haveElectricity()`)

If neither condition is met, the radio is skipped. World-placed radios on grid
power work without battery.

#### 2.3.6 Dynamic Detection

The scanner radio system uses **no hardcoded item type names**. Detection works
by iterating the player's inventory and calling `getDeviceData()` on each item.
If the item has valid device data, is turned on, and has power, it qualifies.

This means:
- All vanilla radios work automatically
- Modded radios work automatically if they use standard PZ radio device data
- Future vanilla radios added by TIS will work without code changes

Only one radio scans per minute cycle (first valid radio found), following the
same stagger rule as other passive recon devices.

### 2.4 Data Calculator

| Property | Value |
|----------|-------|
| Equip slot | N/A (inventory item, not equipped) |
| Passive scan | No |
| Function | Compile and analyze recon data |
| Carry bonus | +5% confidence to all manual note-taking |
| Weight | ~0.8 kg |

The Data Calculator does not perform passive scanning. Its purpose is data
analysis: the player right-clicks the calculator in inventory to compile,
cross-reference, and score accumulated recon entries. It also provides a passive
+5% confidence bonus to any manual note-taking actions while carried.

VHS tapes CANNOT be used with the Data Calculator.

---

## 3. Media System

VHS tapes are the primary storage medium for passive recon data. Two
additional media families — **microcassettes** and **floppy disks** — are
available as higher-fidelity alternatives. All media types are managed by
`POS_MediaManager.lua` (which replaced the original `POS_TapeManager.lua`).

See `data-recorder-design.md` Section 4 for the full media comparison table,
microcassette/floppy lifecycle details, and media modData schema.

### VHS Tapes

VHS tapes remain the workhorse medium for passive recon data from the
Camcorder and Field Survey Logger.

### 3.1 Quality Tiers

| Tier | Entry Capacity | Confidence Modifier | Source |
|------|---------------|---------------------|--------|
| Factory | 20 | -0% (baseline) | World loot (rare) |
| Refurbished | 15 | -10% | Crafting (repair recipe) |
| Spliced | 8 | -25% | Crafting (splice 2 worn tapes) |
| Improvised | 4 | -50% | Crafting (improvise from scrap) |

Higher-tier tapes store more entries and produce higher-confidence data.
Confidence modifiers apply multiplicatively to the base quality of the
recording device.

### 3.2 Tape Lifecycle

```
Blank ──► Recording ──► Recorded ──► Upload ──► Degrade ──► Worn ──► Recycle
  │                                     │          │                    │
  │         (device writes entries)     │   (condition loss per cycle) │
  │                                     │          │                    │
  │                                     ▼          ▼                    ▼
  │                              (terminal)  (still usable)     (splice/scrap)
  └─────────────────────────────────────────────────────────────────────┘
                            (new blank from recycling)
```

1. **Blank** -- fresh tape, no data, full condition
2. **Recording** -- device is actively writing entries to the tape
3. **Recorded** -- tape is full or manually ejected; data is on tape
4. **Upload** -- player uploads tape contents to POSnet terminal
5. **Degrade** -- each upload-and-erase cycle reduces tape condition
   (sandbox-configurable degradation rate)
6. **Worn** -- condition reaches 0%; tape can no longer record
7. **Recycle** -- worn tapes are broken down for parts or spliced together

### 3.3 Minimum Continuous Operation

Each tape requires a minimum of **3 in-game days** of continuous operation
before its data is considered valid for upload. This prevents exploit patterns
where players rapidly swap tapes for maximum throughput.

The minimum duration is sandbox-configurable via `ReconMinTapeDuration`
(default: 3 days, range: 1-7).

### 3.4 Crafting Recipes

| Recipe | Inputs | Output | Skill |
|--------|--------|--------|-------|
| Repair VHS Tape | 1 Worn Tape + 1 Adhesive Tape + 1 Screwdriver | 1 Refurbished Tape | Electrical 2 |
| Splice VHS Tape | 2 Worn Tapes + 1 Scissors + 1 Adhesive Tape | 1 Spliced Tape | Electrical 3 |
| Improvise VHS Tape | 1 Scrap Electronics + 1 Empty Tape Cassette + 1 Screwdriver | 1 Improvised Tape | Electrical 4 |
| Recycle VHS Tape | 1 Worn Tape + 1 Screwdriver | Scrap Electronics | Electrical 1 |

---

## 4. Scanning Engine

### 4.1 Tick Hook

Passive scanning runs on the **EveryOneMinute** event hook. This provides
adequate temporal resolution for building discovery while avoiding the
performance cost of per-tick processing.

**Recorder gate**: The scan cycle begins with a check for an equipped,
powered Data-Recorder. If absent, the entire scan cycle is skipped. See
`data-recorder-design.md` Section 6.3 for details.

### 4.2 Chunk-Based Detection

The scanner does not iterate over individual tiles within its radius. Instead:

1. Determine which map chunks fall within the device's scan radius
2. For each chunk, query the building definitions present
3. Compare against entries already on the current tape (deduplication)
4. If a new building is found, create a recon entry with timestamp, location,
   building type, and confidence score

This chunk-based approach keeps the per-cycle cost constant regardless of
building density.

### 4.3 Staggered Multi-Device

If a player has multiple scanning devices equipped simultaneously, only **one
device scans per minute cycle**. Devices are processed in round-robin order.
This prevents performance spikes and avoids duplicate entries from overlapping
scan radii.

### 4.4 Stationary Player Optimization

If the player has not moved since the last scan cycle (same chunk), the scanner
skips re-scanning that chunk. This prevents redundant work when the player is
idle at a base.

---

## 5. Equipment Requirements

### 5.1 Equip-to-Scan Rule

Passive scanning **only activates** when a device is equipped in the appropriate
slot:

| Device | Required Slot | Scan Active |
|--------|--------------|-------------|
| Recon Camcorder | Secondary hand | When equipped |
| Field Survey Logger | Belt / holster | When equipped |
| Scanner Radio | N/A | When powered on |
| Data Calculator | N/A | Never (analysis only) |

Merely carrying a device in inventory does NOT trigger passive scanning.

### 5.2 Carry Bonuses

Devices that are in inventory (but not necessarily equipped) provide a passive
confidence bonus to manual note-taking actions:

| Device | Carry Bonus |
|--------|-------------|
| Recon Camcorder | +15% confidence |
| Field Survey Logger | +10% confidence |
| Data Calculator | +5% confidence |

Carry bonuses stack if multiple devices are present.

---

## 6. Market Intelligence Integration

Recon entries feed two systems within POSnet:

### 6.1 Building Cache Enrichment

Uploaded recon data adds buildings to the `POS_BuildingCache` that the player
has not physically entered. These buildings become eligible as mission targets,
delivery destinations, and points of interest on the terminal map.

Recon-discovered buildings are flagged as `source = "recon"` (vs `"explored"`)
and may have lower location accuracy depending on the recording device's quality
tier.

### 6.2 Market Observations

When a recon scan detects a commercial building (shop, warehouse, pharmacy,
etc.), the system generates a market observation entry with:

- Estimated inventory category (based on building type)
- Confidence score (device quality x tape quality x signal strength)
- Timestamp (for staleness calculations)

These observations appear in the BBS market screens alongside broadcast data,
giving players who invest in recon hardware a richer picture of available trade
opportunities.

---

## 7. Loot Distribution

### 7.1 Device Spawn Locations

| Device | Spawn Locations | Rarity |
|--------|----------------|--------|
| Recon Camcorder | TV studios, journalism offices, police stations | Rare |
| Field Survey Logger | Ranger stations, research labs, military checkpoints | Uncommon |
| Data Calculator | Office buildings, university labs, tech stores | Uncommon |

### 7.2 VHS Tape Spawn Locations

| Tier | Spawn Locations | Rarity |
|------|----------------|--------|
| Factory (blank) | Electronics stores, TV studios, warehouses | Uncommon |
| Refurbished | N/A (crafting only) | -- |
| Spliced | N/A (crafting only) | -- |
| Improvised | N/A (crafting only) | -- |

Recorded (non-blank) factory tapes can spawn in TV studios and journalism
offices, containing pre-apocalypse recon data of limited value (low confidence,
outdated timestamps).

---

## 8. Foraging

Damaged VHS tapes can be discovered through the foraging system in **urban and
suburban zones**. Foraging yields:

- **Worn VHS Tape** (common) -- condition 0%, suitable for splicing or recycling
- **Damaged VHS Tape** (uncommon) -- condition 10-30%, may be repairable

Foraging tapes have the `Tape` tag and appear in the Electronics foraging
category. Discovery chance scales with Electrical skill.

---

## 9. Sandbox Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `EnablePassiveRecon` | boolean | true | Master toggle for the passive recon system |
| `ReconScanInterval` | integer | 1 | Minutes between scan cycles (1-5) |
| `ReconMinTapeDuration` | integer | 3 | Minimum days of continuous recording before upload is allowed (1-7) |
| `ReconTapeDegradeRate` | integer | 10 | Condition loss per upload-and-erase cycle as percentage (0-50; 0 disables degradation) |
| `ReconCamcorderRadius` | integer | 40 | Camcorder scan radius in tiles (20-60) |
| `ReconLoggerRadius` | integer | 25 | Field Survey Logger scan radius in tiles (10-40) |
| `ReconCamcorderNoise` | boolean | true | Whether the camcorder generates zombie-attracting noise |
| `ReconCarryBonusStack` | boolean | true | Whether carry bonuses from multiple devices stack |
| `ReconMaxEntriesPerCycle` | integer | 3 | Maximum new entries per scan cycle (1-10; performance safety valve) |
| `ReconForagingEnabled` | boolean | true | Whether damaged tapes appear in urban/suburban foraging |

All sandbox options use the `POS_` prefix in translation keys and follow the
existing POSnet sandbox conventions.

---

## 10. Icon Pipeline

Device and tape icons are generated using **gpt-image-1** at approximately
**$0.18 per icon**.

Specifications:

- **Dimensions**: 128x128 pixels, RGBA PNG
- **Style**: Consistent with existing POSnet icon set (muted post-apocalyptic
  palette, slight wear/grime aesthetic)
- **Background**: Transparent
- **Naming**: `POS_<ItemName>.png` (e.g., `POS_ReconCamcorder.png`,
  `POS_VHSTapeFactory.png`)

Icons required:

| Icon | Item |
|------|------|
| `POS_ReconCamcorder.png` | Recon Camcorder |
| `POS_FieldSurveyLogger.png` | Field Survey Logger |
| `POS_DataCalculator.png` | Data Calculator |
| `POS_VHSTapeFactory.png` | Factory VHS Tape (blank) |
| `POS_VHSTapeRefurbished.png` | Refurbished VHS Tape |
| `POS_VHSTapeSpliced.png` | Spliced VHS Tape |
| `POS_VHSTapeImprovised.png` | Improvised VHS Tape |
| `POS_VHSTapeWorn.png` | Worn VHS Tape |
| `POS_VHSTapeRecorded.png` | Recorded VHS Tape (generic) |

Total: 9 icons, estimated cost ~$1.62.
