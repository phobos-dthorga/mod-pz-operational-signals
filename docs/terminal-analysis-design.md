# POSnet Terminal Analysis — Design & Styling Guide

**Branch**: `dev/data-recorder` (future)
**Date**: 2026-03-20
**Status**: Service scaffolded (`POS_TerminalAnalysisService.lua` + `POS_Screen_Analysis.lua` exist). Tier II pipeline integration with camera workstation (Tier III) and satellite broadcast (Tier IV) not yet connected.
**Prerequisites**: Data-Recorder system implemented (see `data-recorder-design.md`),
SIGINT skill registered (see `sigint-skill-design.md`)

---

## Executive Summary

Terminal Analysis is the **cognitive processing layer** that transforms raw field
data into structured, intermediate intelligence artifacts. It occupies the space
between raw capture (field) and formal compilation (camera workstation) — the
moment where the player sits down and *thinks*.

This is not compilation (camera). This is not transmission (satellite). This is:

```
         Turning information into understanding.
```

The existing POSnet pipeline has a binary knowledge model: data is either
"gathered" or "not gathered". Terminal Analysis adds **depth, uncertainty, and
progression** by introducing intermediate artifacts — Intel Fragments, Insights,
Patterns, and Leads — that represent partial knowledge evolving toward verified
intelligence.

```
                    THE FOUR-LAYER INTELLIGENCE PIPELINE
                    ════════════════════════════════════

  🜁 CAPTURE (Field)     →  messy, incomplete, noisy
                              "I saw something"

  🜂 ANALYSIS (Terminal)  →  consumes raw inputs, produces structured insights
                              "I understand something"       ← THIS DOCUMENT

  🜄 COMPILATION (Camera) →  formalises into reports, verifies and packages
                              "This is something"

  🜃 BROADCAST (Satellite)→  spreads influence, affects the world
                              "Everyone knows something"
```

The diegetic fantasy: *"This is where everything starts to make sense."*

When the player sits at the terminal, it should feel like: **slow, intentional,
almost meditative — "I am sitting down and thinking."**

---

## 1. What Terminal Analysis Is

A **timed action** performed at a POSnet terminal (radio + computer) where the
player reviews raw intelligence materials and extracts structured intermediate
artifacts. Think of it as a survivor hunched over a desk, cross-referencing
notes, reviewing tapes, and annotating observations.

It is:
- A deliberate player action requiring time, focus, and raw materials
- The primary XP source for the SIGINT skill
- The bridge between chaotic field data and structured camera compilation
- A system that rewards input diversity and analytical investment
- The place where SIGINT skill has its strongest mechanical effect

It is NOT:
- A replacement for field recon (raw inputs must be gathered first)
- A replacement for camera compilation (outputs are intermediate, not final)
- An auto-processing system (requires deliberate player action)
- A simple "convert A to B" recipe (SIGINT level, input diversity, and
  satellite connectivity all affect output quality and quantity)

---

## 2. Why It Must Exist

### 2.1 Current Gap

Without Terminal Analysis, the POSnet pipeline has a structural problem:

1. **Binary knowledge.** Data is either "gathered" or "not gathered". There is
   no gradient of understanding between raw observation and compiled report.

2. **No intermediate artifacts.** A player who gathers 5 notes has 5 discrete
   notes — they cannot synthesise partial understanding from them until they
   reach a camera workstation.

3. **Terminal is underutilised.** The POSnet terminal is currently a menu
   system (BBS, missions, deliveries). It has no *analytical work* the player
   performs there, making the terminal feel like a vending machine rather than
   a command centre.

4. **SIGINT has no primary domain.** Without Terminal Analysis, the SIGINT
   skill would only modify existing actions marginally. It needs a system
   where its effects are central and meaningful.

### 2.2 What Terminal Analysis Solves

| Problem | Solution |
|---------|----------|
| Binary knowledge model | Intermediate artifacts with confidence gradients |
| No synthesis step | Analysis merges and interprets multiple raw inputs |
| Terminal underutilised | "Process Intelligence" is a core terminal action |
| SIGINT needs a domain | Terminal Analysis is the primary SIGINT expression point |
| Camera inputs are raw | Analysis outputs are higher-quality camera inputs |
| No partial knowledge | Intel Fragments represent evolving understanding |

---

## 3. Pipeline Position

Terminal Analysis sits between field capture and camera compilation, adding
a processing step that converts raw chaos into structured understanding:

```
    ┌──────────────────────────────────────────────────────────┐
    │                    FIELD COLLECTION                       │
    │  Pen+Paper  │  Recorder+VHS  │  Recorder+Floppy/Micro   │
    └──────┬──────┴───────┬────────┴───────────┬───────────────┘
           │              │                    │
           ▼              ▼                    ▼
    ┌──────────────────────────────────────────────────────────┐
    │                   RAW ARTIFACTS                           │
    │  Raw Market Note  │  Recorded Tape  │  Recorder Buffer   │
    └──────┬────────────┴────────┬────────┴────────┬───────────┘
           │                     │                  │
           ▼                     ▼                  ▼
    ┌──────────────────────────────────────────────────────────┐
    │              TERMINAL ANALYSIS ← THIS DOCUMENT           │
    │         (POSnet terminal — radio + computer)             │
    │                                                          │
    │  Input: 1-5 raw intel items (notes, tapes, fragments)    │
    │  Action: Timed processing (ISBaseTimedAction)            │
    │  Output: 1-4 Intel Fragments (SIGINT-dependent yield)   │
    │                                                          │
    │  SIGINT skill: PRIMARY effect zone                       │
    │  Satellite link: enhances output quality                 │
    └──────────────────────────┬───────────────────────────────┘
                               │
                               ▼
    ┌──────────────────────────────────────────────────────────┐
    │              INTERMEDIATE ARTIFACTS                       │
    │  Intel Fragments  │  Patterns  │  Leads  │  Insights    │
    │  (feed into Camera Workstation OR direct terminal use)   │
    └──────────────────────────────────────────────────────────┘
```

**Critical design constraint**: Terminal Analysis should never feel like a
mandatory bottleneck. Raw Market Notes can still be uploaded directly to the
terminal's market database (existing flow). Analysis is an *optional premium
path* that produces higher-quality intermediate artifacts.

---

## 4. The "Process Intelligence" Action

### 4.1 Action Overview

| Property | Value |
|----------|-------|
| Action Name | Process Intelligence |
| Location | POSnet terminal (radio + computer, same as existing terminal) |
| Input | 1-5 raw intel tagged items (any mix) |
| Output | 1-4 Intel Fragments (yield depends on SIGINT level + input count) |
| Time | 180 seconds base (3 min, modified by SIGINT level and sandbox) |
| Animation | `Write` |
| Power | Required (same as existing terminal) |
| Danger gate | Yes (same as existing terminal actions) |

### 4.2 Action Flow

1. Player opens POSnet terminal (existing right-click → terminal flow)
2. New screen: **Intelligence Analysis** (registered via `POS_API.registerScreen()`)
3. Screen shows available raw intel items in inventory
4. Player selects 1-5 items to process
5. Confirmation dialog shows estimated output quality and processing time
6. Player confirms → ISBaseTimedAction begins
7. On completion: raw inputs consumed, Intel Fragments created in inventory
8. SIGINT XP awarded (15-25 XP based on input count)
9. Notification via `PhobosLib.notifyOrSay()`

### 4.3 Terminal Screen

The Intelligence Analysis screen is registered via `POS_API.registerScreen()`
with a menu path under the BBS hub:

```
Main Menu → BBS Hub → Intelligence Analysis
```

Screen ID: `pos.bbs.analysis`

The screen displays:
- Available raw intel items (with confidence and category)
- Selected items for processing
- Estimated output quality (based on SIGINT level + selection)
- Estimated processing time
- Satellite link status (if satellite uplink is active)
- "Process" button (starts timed action)

---

## 5. Input Types

Any item tagged with `POS_RawIntel` is valid input for Terminal Analysis. This
tag-based approach allows future expansion without modifying the analysis system.

### 5.1 Valid Input Items

| Item | Tag | Confidence Range | Source |
|------|-----|-----------------|--------|
| Raw Market Note | `POS_RawIntel` | 20-65 | Manual note-taking (Gather Intel) |
| Recorded VHS Tape | `POS_RawIntel` | 30-80 | Passive recon / camcorder |
| Recorded Microcassette | `POS_RawIntel` | 35-85 | Data-Recorder output |
| Recorded Floppy Disk | `POS_RawIntel` | 40-90 | Data-Recorder output |
| Signal Fragment | `POS_RawIntel` | 15-50 | Radio intercept (future) |

### 5.2 Input Diversity Bonus

When inputs come from different source types (e.g., one note + one tape + one
floppy), each unique source type beyond the first adds +3 confidence to the
output, capped at +12 (4+ source types).

When inputs span different market categories, each unique category beyond the
first adds +2 confidence, capped at +8 (5+ categories).

### 5.3 Input Volume Scaling

| Input Count | Base Yield Modifier | XP Award |
|-------------|-------------------|----------|
| 1 | x1.0 | 15 XP |
| 2 | x1.1 | 17 XP |
| 3 | x1.2 | 19 XP |
| 4 | x1.3 | 22 XP |
| 5 | x1.5 | 25 XP |

More inputs provide diminishing but real returns, incentivising batch processing
over one-at-a-time.

---

## 6. Output Artifacts

Terminal Analysis produces **Intel Fragments** — intermediate artifacts that
represent structured understanding extracted from raw data. These are NOT
finished reports (that is the camera's role).

### 6.1 Fragment Quality Tiers

| Tier | Name | Confidence Range | Description | SIGINT Level |
|------|------|-----------------|-------------|-------------|
| Fragmentary | Fragmentary Signal | 15-35 | Noisy, incomplete, low-value | Any (common at L0-2) |
| Unverified | Unverified Lead | 30-55 | Plausible but unconfirmed | Any (common at L3-5) |
| Correlated | Correlated Pattern | 50-75 | Cross-referenced, likely accurate | L3+ (common at L6-8) |
| Confirmed | Confirmed Insight | 70-95 | High-confidence, verified by analysis | L6+ (common at L9-10) |

The tier distribution is determined by SIGINT level via a weighted random roll.
Higher SIGINT shifts the probability curve toward higher tiers.

### 6.2 Fragment Item Definitions

```
item IntelFragmentary {
    DisplayCategory = Information,
    DisplayName = Fragmentary Signal,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_IntelFragmentary,
    Tooltip = Tooltip_POS_IntelFragment,
    Tags = POS_IntelFragment;POS_RawIntel,
}

item IntelUnverified {
    DisplayCategory = Information,
    DisplayName = Unverified Lead,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_IntelUnverified,
    Tooltip = Tooltip_POS_IntelFragment,
    Tags = POS_IntelFragment;POS_RawIntel,
}

item IntelCorrelated {
    DisplayCategory = Information,
    DisplayName = Correlated Pattern,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_IntelCorrelated,
    Tooltip = Tooltip_POS_IntelFragment,
    Tags = POS_IntelFragment;POS_CameraInput,
}

item IntelConfirmed {
    DisplayCategory = Information,
    DisplayName = Confirmed Insight,
    ItemType = base:normal,
    Weight = 0.05,
    Icon = Item_POS_IntelConfirmed,
    Tooltip = Tooltip_POS_IntelFragment,
    Tags = POS_IntelFragment;POS_CameraInput,
}
```

**Tag design**: All fragments have `POS_IntelFragment`. Lower tiers also have
`POS_RawIntel` (can be re-processed for better results). Higher tiers have
`POS_CameraInput` (preferred camera workstation inputs). This creates a natural
progression: *analyse raw data → produce fragments → compile fragments at camera*.

### 6.3 Fragment ModData Schema

| Key | Type | Purpose |
|-----|------|---------|
| `POS_FragmentTier` | string | `"fragmentary"`, `"unverified"`, `"correlated"`, `"confirmed"` |
| `POS_FragmentConfidence` | integer | Confidence score (0-100) |
| `POS_FragmentCategory` | string | Market category ID (if category-specific) |
| `POS_FragmentSourceCount` | integer | Number of raw inputs consumed to produce this |
| `POS_FragmentDay` | integer | Game day when analysed |
| `POS_FragmentSIGINT` | integer | Player's SIGINT level at time of analysis |

### 6.4 Cross-Correlation Outputs (SIGINT 6+)

At SIGINT Level 6+, when multiple unrelated inputs are processed together,
the analysis may produce a **Cross-Correlated Insight** — a special high-value
fragment that represents emergent understanding from combining disparate data:

```
tape + note + market data → "Regional Fuel Crisis Pattern"
```

Cross-correlated outputs:
- Always produce `Correlated` or `Confirmed` tier
- Carry a `POS_FragmentCrossRef = true` flag
- Grant +10 bonus SIGINT XP
- Are prime inputs for Camera Workstation Market Bulletins

### 6.5 Downstream Consumption

| Consumer | Fragment Tier Required | Effect |
|----------|----------------------|--------|
| Camera Workstation: Compile Site Survey | Any `POS_IntelFragment` | Higher-quality survey than raw notes |
| Camera Workstation: Produce Market Bulletin | `POS_CameraInput` tagged | Premium bulletin inputs |
| Terminal: Direct market database upload | Any `POS_IntelFragment` | Higher-confidence market records |
| Mission completion | Any `POS_IntelFragment` | Satisfies "submit intelligence" objectives |
| BBS: Sale to contacts | Any `POS_IntelFragment` | Sell price scales with tier |

---

## 7. SIGINT Skill Influence

Terminal Analysis is the **primary domain** of the SIGINT skill. Every aspect
of the action scales with the player's SIGINT level:

### 7.1 Effect Summary

| Mechanic | L0 | L5 | L10 |
|----------|----|----|-----|
| Output yield | 1 fragment | 1-2 fragments | 2-4 fragments |
| Noise filter | 0% | 35% | 90% |
| Time modifier | Base (180s) | -18% (148s) | -44% (101s) |
| Confidence bonus | +0 | +10 | +25 |
| Tier distribution | Mostly Fragmentary | Mixed | Mostly Confirmed |
| Cross-correlation | Not available | Not available | Available |
| False data detection | Not available | Not available | Available (L8+) |

See `sigint-skill-design.md` Section 4.2 for the full mechanical specification.

### 7.2 Noise Filter Mechanic

At low SIGINT levels, some analysis outputs are "junk" — misleading or useless
fragments that waste the player's time and materials. The noise filter, scaling
with SIGINT level, suppresses these junk outputs and replaces them with valid
insights.

| SIGINT Level | Junk Chance | Experience |
|-------------|------------|------------|
| 0-2 | 40% | "I have data... but I don't understand it." |
| 3-5 | 20% | "Something is going on here..." |
| 6-8 | 8% | "I can see the system forming." |
| 9-10 | 2% | "I don't just observe the system — I understand it." |

Junk fragments are visually distinct (lower tier, "Fragmentary Signal" name)
but not obviously flagged as junk — the player must learn to distinguish
good intel from noise through experience, reinforcing the SIGINT progression
fantasy.

---

## 8. Satellite Enhancement

When the player's POSnet infrastructure includes an active Satellite Uplink
(see `satellite-uplink-design.md`), Terminal Analysis gains enhancements:

### 8.1 Signal Enrichment

With satellite active, the terminal gains access to external data feeds that
improve analysis quality:

| Enhancement | Effect |
|-------------|--------|
| Confidence bonus | +8 to all fragment confidence scores |
| Tier upgrade chance | 15% chance to upgrade fragment tier by one step |
| Cross-correlation threshold | Reduced by 1 SIGINT level (L5 instead of L6) |
| Ambient data accumulation | Terminal slowly accumulates background intel (passive) |

### 8.2 Data Amplification

Satellite-linked analysis can:
- Combine terminal inputs with distant satellite-received data
- Cross-reference against broadcast market data from other regions
- Resolve ambiguity in fragmentary inputs using external context

Mechanically: higher-quality outputs, more tags per analysis cycle, reduced
randomness.

### 8.3 Background Passive Feed

If a satellite uplink is powered and linked to the terminal's building, the
terminal slowly accumulates ambient data over time. This creates a "data
reservoir" that enhances the next Terminal Analysis action:

| Accumulation Time | Bonus |
|-------------------|-------|
| < 1 game day | No bonus |
| 1-3 game days | +3 confidence to next analysis |
| 3-7 game days | +6 confidence, +1 yield |
| 7+ game days | +10 confidence, +1 yield, tier upgrade +10% |

The reservoir resets after each Terminal Analysis action, encouraging periodic
analytical sessions rather than constant terminal camping.

---

## 9. Sandbox Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `EnableTerminalAnalysis` | boolean | true | — | Master toggle for the Process Intelligence action |
| `AnalysisBaseTime` | integer | 180 | 60-600 | Base processing time in seconds |
| `AnalysisMaxInputs` | integer | 5 | 1-10 | Maximum raw intel items per analysis action |
| `AnalysisJunkChance` | integer | 40 | 0-80 | Base junk output chance at SIGINT 0 (percentage) |
| `AnalysisSatelliteBonus` | boolean | true | — | Whether satellite uplink enhances terminal analysis |
| `AnalysisCooldownMinutes` | integer | 30 | 0-120 | Cooldown between analysis actions at the same terminal (0 disables) |
| `AnalysisDiversityBonus` | boolean | true | — | Whether input source diversity grants confidence bonus |

---

## 10. Constants

New constants in `POS_Constants.lua`:

```lua
-- Terminal Analysis
POS_Constants.SCREEN_ID_ANALYSIS               = "pos.bbs.analysis"
POS_Constants.ANALYSIS_BASE_TIME               = 180  -- seconds
POS_Constants.ANALYSIS_MAX_INPUTS              = 5
POS_Constants.ANALYSIS_BASE_JUNK_CHANCE        = 40   -- percentage at SIGINT 0
POS_Constants.ANALYSIS_COOLDOWN_MINUTES        = 30

-- Input diversity bonuses
POS_Constants.ANALYSIS_SOURCE_DIVERSITY_BONUS  = 3    -- per unique source type
POS_Constants.ANALYSIS_SOURCE_DIVERSITY_CAP    = 12   -- max bonus from source types
POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_BONUS = 2   -- per unique market category
POS_Constants.ANALYSIS_CATEGORY_DIVERSITY_CAP  = 8    -- max bonus from categories

-- Input volume XP scaling
POS_Constants.ANALYSIS_XP_PER_INPUT            = {15, 17, 19, 22, 25}

-- Satellite enhancement
POS_Constants.ANALYSIS_SATELLITE_CONFIDENCE    = 8
POS_Constants.ANALYSIS_SATELLITE_TIER_UPGRADE  = 15   -- percentage chance
POS_Constants.ANALYSIS_SATELLITE_CROSSCOR_REDUCTION = 1  -- SIGINT levels

-- Satellite passive accumulation thresholds (game days)
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T1 = 1
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T2 = 3
POS_Constants.ANALYSIS_SATELLITE_ACCUMULATE_T3 = 7

-- Fragment tier IDs
POS_Constants.FRAGMENT_TIER_FRAGMENTARY        = "fragmentary"
POS_Constants.FRAGMENT_TIER_UNVERIFIED         = "unverified"
POS_Constants.FRAGMENT_TIER_CORRELATED         = "correlated"
POS_Constants.FRAGMENT_TIER_CONFIRMED          = "confirmed"

-- Fragment item IDs
POS_Constants.ITEM_INTEL_FRAGMENTARY           = "PhobosOperationalSignals.IntelFragmentary"
POS_Constants.ITEM_INTEL_UNVERIFIED            = "PhobosOperationalSignals.IntelUnverified"
POS_Constants.ITEM_INTEL_CORRELATED            = "PhobosOperationalSignals.IntelCorrelated"
POS_Constants.ITEM_INTEL_CONFIRMED             = "PhobosOperationalSignals.IntelConfirmed"

-- Tags
POS_Constants.TAG_RAW_INTEL                    = "POS_RawIntel"
POS_Constants.TAG_INTEL_FRAGMENT               = "POS_IntelFragment"
POS_Constants.TAG_CAMERA_INPUT                 = "POS_CameraInput"

-- Analysis action cooldown key prefix
POS_Constants.ANALYSIS_VISIT_KEY_PREFIX        = "POS_AnalysisVisit_"
```

---

## 11. Module Architecture

### 11.1 New Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_TerminalAnalysisService.lua` | Shared | Core business logic: validate inputs, calculate outputs, produce fragments |
| `POS_TerminalAnalysisAction.lua` | Client | ISBaseTimedAction for the Process Intelligence action |
| `POS_TerminalAnalysisScreen.lua` | Client | Terminal screen UI for Intelligence Analysis |

### 11.2 Modified Modules

| Module | Change |
|--------|--------|
| `POS_Constants.lua` | ~30 new constants (see Section 10) |
| `POS_API.lua` | Register `pos.bbs.analysis` screen and `pos.bbs` category entry |
| `POS_SandboxIntegration.lua` | 7 new getter functions for analysis sandbox options |
| `POS_NoteTooltip.lua` | Extend tooltip for Intel Fragment item types |
| `.luacheckrc` | Add new module globals |

### 11.3 Separation of Concerns

- `POS_TerminalAnalysisScreen.lua` — **presentation only**. Displays available
  inputs, selection UI, estimated output. Delegates to service for calculations.
  Button callback is a one-liner to start the timed action.
- `POS_TerminalAnalysisAction.lua` — **timed action only**. Handles animation,
  timing, interruption. Delegates to `POS_TerminalAnalysisService.process()` in
  `perform()`.
- `POS_TerminalAnalysisService.lua` — **all business logic**. Input validation,
  SIGINT modifier lookup, yield calculation, noise filtering, fragment generation,
  diversity bonus, satellite enhancement, XP award, cooldown management.

---

## 12. Context Menu Integration

Terminal Analysis is accessed through the **existing POSnet terminal**, not
through a separate right-click context menu. It appears as a new screen in the
terminal's BBS hub navigation:

```
Main Menu → BBS Hub → Intelligence Analysis
```

The screen is registered with:
- `menuPath = "pos.bbs"`
- `sortOrder = 40` (after Operations, Courier, Investments)
- `shouldShow = function() return POS_Sandbox.isTerminalAnalysisEnabled() end`
- `canOpen = function() return hasRawIntelInInventory(player) end`

---

## 13. Translation Keys

### 13.1 Item Names (ItemName.json)

```
"ItemName_IntelFragmentary": "Fragmentary Signal",
"ItemName_IntelUnverified": "Unverified Lead",
"ItemName_IntelCorrelated": "Correlated Pattern",
"ItemName_IntelConfirmed": "Confirmed Insight"
```

### 13.2 UI Strings (UI.json)

```
"UI_POS_Analysis_ScreenTitle": "Intelligence Analysis",
"UI_POS_Analysis_SelectInputs": "Select raw intelligence to process:",
"UI_POS_Analysis_EstimatedQuality": "Estimated output quality: %1",
"UI_POS_Analysis_EstimatedTime": "Processing time: %1 seconds",
"UI_POS_Analysis_SatelliteLinked": "Satellite uplink active — enhanced analysis",
"UI_POS_Analysis_SatelliteNotLinked": "No satellite uplink — standard analysis",
"UI_POS_Analysis_Process": "Process Intelligence",
"UI_POS_Analysis_Processing": "*cross-referencing observations*",
"UI_POS_Analysis_Complete": "Analysis complete.",
"UI_POS_Analysis_NoInputs": "No raw intelligence available.",
"UI_POS_Analysis_OnCooldown": "Recently analysed here. Available in %1 minute(s).",
"UI_POS_Analysis_NoPower": "Terminal requires electricity.",
"UI_POS_Analysis_DangerNearby": "Too dangerous to concentrate here.",
"UI_POS_Analysis_CrossCorrelation": "Cross-correlation detected — emergent insight!",
"UI_POS_Analysis_FalseData": "Contradictory data flagged and suppressed."
```

### 13.3 Fragment Descriptions (UI.json)

```
"UI_POS_Fragment_Fragmentary": "Fragmentary — noisy, incomplete signal data.",
"UI_POS_Fragment_Unverified": "Unverified — plausible lead requiring further analysis.",
"UI_POS_Fragment_Correlated": "Correlated — cross-referenced pattern, likely accurate.",
"UI_POS_Fragment_Confirmed": "Confirmed — verified insight, high confidence."
```

### 13.4 Sandbox Strings (Sandbox.json)

Standard pattern: 7 new options = 14 new translation keys.

---

## 14. Icon Pipeline

### 14.1 New Icons Required

| Icon | Item | Style Notes |
|------|------|-------------|
| `Item_POS_IntelFragmentary.png` | Fragmentary Signal | Torn paper scrap with partial waveform, static noise, faded |
| `Item_POS_IntelUnverified.png` | Unverified Lead | Index card with handwritten notes, question mark, yellow tint |
| `Item_POS_IntelCorrelated.png` | Correlated Pattern | Chart paper with connected data points, blue tint, clean |
| `Item_POS_IntelConfirmed.png` | Confirmed Insight | Typed document with green checkmark stamp, official feel |

### 14.2 Specifications

- **Dimensions**: 128x128 pixels, RGBA PNG
- **Style**: Muted post-apocalyptic palette; each tier has a distinct colour
  temperature (fragmentary=grey, unverified=yellow, correlated=blue,
  confirmed=green) for at-a-glance visual distinction
- **Background**: Transparent
- **Naming**: `Item_POS_<ItemName>.png`
- **Generator**: gpt-image-1 (~$0.18 per icon)
- **Estimated cost**: 4 icons x $0.18 = ~$0.72

---

## 15. Implementation Phases

### Phase 1 — Core Analysis Action (Minimum Viable)

- `POS_TerminalAnalysisService.lua` — input validation, basic yield (always 1),
  fragment generation, XP award
- `POS_TerminalAnalysisAction.lua` — ISBaseTimedAction
- `POS_TerminalAnalysisScreen.lua` — minimal input selection UI
- Register `pos.bbs.analysis` screen in `POS_API`
- 4 Intel Fragment item definitions
- Constants in `POS_Constants.lua`
- Sandbox options: `EnableTerminalAnalysis`, `AnalysisBaseTime`
- Tag `POS_RawIntel` on Raw Market Note
- Translation keys
- Icons for 4 fragment tiers

### Phase 2 — SIGINT Integration

- Wire SIGINT yield range, noise filter, time modifier
- Tier distribution weighted by SIGINT level
- Input diversity bonus (source type + category)
- Input volume scaling
- Remaining sandbox options
- Cooldown system

### Phase 3 — Satellite Enhancement

- Satellite link detection
- Confidence bonus, tier upgrade chance
- Cross-correlation threshold reduction
- Background passive data accumulation
- `AnalysisSatelliteBonus` sandbox option

### Phase 4 — Advanced Features

- Cross-correlation discovery (SIGINT 6+)
- False data detection (SIGINT 8+)
- Cross-correlated output items
- ZScienceSkill specimen outputs
- Tooltip extensions for all fragment types

### Phase 5 — Polish

- Tutorial tooltip (one-time, PhobosLib notice system)
- Notification feedback for all analysis outcomes
- Balance pass on tier distributions and confidence ranges
- Documentation updates to `design-guidelines.md`

---

## 16. Anti-Patterns — What Terminal Analysis Must Never Become

1. **Not a mandatory bottleneck.** Raw Market Notes can still be uploaded
   directly to the market database. Analysis is a premium optional path.

2. **Not instant conversion.** The action must always take meaningful time.
   Even at SIGINT 10 with maximum time reduction, the action takes ~100
   seconds. This preserves the "sitting down to think" fantasy.

3. **Not a loot generator.** Analysis consumes raw intel and produces
   structured intel. It never creates items from nothing. Input materials
   represent real field work.

4. **Not auto-processing.** No `EveryOneMinute` hooks, no background
   processing, no "queue up and walk away". The player must be present
   at the terminal for the full duration.

5. **Not a camera replacement.** Analysis outputs are intermediate — they
   are better camera inputs, not finished reports. The camera workstation
   remains the final compilation step.

---

## 17. Relationship to Other Design Documents

| Document | Relationship |
|----------|-------------|
| `sigint-skill-design.md` | SIGINT skill is the **primary modifier** — yield, noise, time, tier distribution all scale with SIGINT level |
| `camera-workstation-design.md` | Camera Workstation **consumes** analysis outputs — `POS_CameraInput` tagged fragments are premium inputs |
| `satellite-uplink-design.md` | Satellite Uplink **enhances** terminal analysis — confidence bonus, tier upgrades, passive accumulation |
| `data-recorder-design.md` | Data-Recorder produces raw artifacts that **feed into** terminal analysis |
| `passive-recon-design.md` | Passive recon devices produce raw artifacts (VHS, floppy, microcassette) that feed analysis |
| `design-guidelines.md` | Terminal Analysis follows all existing guidelines; new section for analysis-specific rules |

```
data-recorder    passive-recon          camera-workstation
     │                │                        ▲
     └────────┬───────┘                        │
              │                                │
              ▼                                │
     ┌─────────────────┐              ┌────────┴────────┐
     │  RAW ARTIFACTS  │──────────────│  INTEL FRAGMENTS │
     │  (field data)   │   Terminal   │  (structured)    │
     └─────────────────┘   Analysis   └─────────────────┘
                              │
                         SIGINT SKILL
                       (primary domain)
                              │
                       satellite-uplink
                       (enhancement)
```

---

## 18. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Terminal feels like a menu click, not "thinking" | Medium | Action time + animation + SIGINT progression create weight |
| Analysis outputs too similar to raw notes | Medium | Distinct item names, icons, tier colours, and modData schema |
| Players skip analysis (go straight to camera) | Low | Camera accepts raw notes too — analysis is premium, not required |
| Junk outputs frustrate low-SIGINT players | Medium | Junk fragments still have value (re-processable); skill books available early |
| Too many item types in inventory | Low | Fragments are lightweight (0.05 weight); can be consumed at camera quickly |

---

## 19. Success Criteria

The Terminal Analysis implementation is successful when:

1. A player sitting at a terminal with 3 raw notes and pressing "Process
   Intelligence" feels like they are *doing analytical work*, not clicking
   a button
2. The difference between SIGINT 0 and SIGINT 5 analysis outputs is
   noticeable and satisfying
3. Intel Fragments feel like a distinct artifact class — not just "another
   note" but structured understanding
4. Players who invest in the analysis path produce measurably better camera
   workstation outputs than players who feed raw notes directly
5. The satellite enhancement feels like a genuine upgrade to the analytical
   process, not an arbitrary bonus
6. Cross-correlation discoveries (SIGINT 6+) produce a genuine "aha" moment
