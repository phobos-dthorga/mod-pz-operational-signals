# POSnet Camera Workstation — Design & Styling Guide

**Branch**: `dev/data-recorder` (future)
**Date**: 2026-03-20
**Status**: Design phase — implementation not started
**Prerequisites**: v0.11.0 (Market Exchange Framework) merged to main, Data-Recorder
system implemented (see `data-recorder-design.md`)

---

## Executive Summary

The Camera Workstation is a **stationary, high-tier compilation and verification
station** that transforms raw field intelligence into structured, broadcast-ready
POSnet intelligence packages. It uses the vanilla TV-station camera furniture
object as a CraftBench entity, giving it a fixed location in the world and making
TV stations, media offices, and broadcast facilities strategically valuable
territory.

This is not a new data acquisition system. It is the **missing compilation layer**
in an existing pipeline that already looks like this:

```
FIELD (notes, tapes, recorder) → TERMINAL (upload, ingest) → MARKET (sell, trade)
```

The Camera Workstation adds a high-fidelity compilation step between field and
terminal:

```
FIELD → CAMERA WORKSTATION → TERMINAL → MARKET
       (compile, verify)   (transmit)  (trade)
```

The workstation does NOT replace field recon, the Data-Recorder, or the terminal.
It occupies a distinct niche: converting chaotic raw materials into premium-grade
intelligence packages. Players who invest the time and logistics to reach and
operate a camera workstation are rewarded with higher-confidence data, better sell
prices, larger reputation gains, and the ability to merge multiple raw inputs into
a single finished artifact.

```
                    INFORMATION SOPHISTICATION LADDER
                    ═════════════════════════════════

  LOW ────────────────────────────────────────────── HIGH
   │                                                   │
   │  Handwritten     Field Tape     Studio-Compiled   │
   │  Notes           Recordings     Packages          │
   │  ─────────       ──────────     ────────────────  │
   │  Pen + Paper     Recorder +     Camera Workstation│
   │  In the field    VHS/Media      At TV station     │
   │  Low confidence  Med confidence High confidence   │
   │  Personal use    Terminal-grade  Broadcast-ready   │
   │                                                   │
   └───────────────────────────────────────────────────┘
```

The diegetic fantasy: *"I am not merely scribbling random notes. I am producing
usable intelligence through real post-collapse media infrastructure."*

---

## 1. What the Camera Workstation Is

A **stationary, world-placed furniture object** (the vanilla TV-station camera)
that functions as a CraftBench entity for compiling raw intelligence materials
into high-grade POSnet packages. Think of it as a 1990s broadcast studio editing
desk — a tripod-mounted studio camera with a red tally light, positioned in a TV
station or media office.

It is:
- A fixed-location infrastructure object (not portable, not craftable)
- A CraftBench entity with right-click context menu interactions
- The highest-tier data compilation path in POSnet
- A destination that gives TV stations and media buildings strategic value
- An optional premium path for players who invest in logistics

It is NOT:
- A replacement for field recon (it improves field work, not erases it)
- A passive auto-scanner (it requires deliberate player action and materials)
- A replacement for the terminal (transmission still happens at the POSnet terminal)
- A generic crafting bench (it has a bespoke identity and specific input/output types)
- A requirement for basic reporting (pen-and-paper field notes remain fully functional)

---

## 2. Why It Must Exist

### 2.1 Current Gap

The existing POSnet pipeline has a sophistication ceiling:

1. **All intelligence is equal once ingested.** A scribbled field note and a
   carefully recorded VHS tape both produce the same `RawMarketNote` with
   confidence determined solely by source tier and reputation. There is no
   path to produce higher-tier intelligence through additional player effort
   after the initial field collection.

2. **No merge/compilation path.** If a player gathers 5 notes about the same
   market category from different locations, they cannot combine them. Each
   note is atomistic — no synthesis step exists.

3. **TV stations are flavour only.** The TV station CraftBench entity currently
   exists for VHS tape review, but the building itself has no unique strategic
   value beyond housing a specific piece of furniture. Players have no reason
   to secure or defend media facilities.

4. **Information tiers are implicit.** The confidence system (low/medium/high)
   exists but has no physical manifestation beyond a tooltip number. There is
   no artifact-level distinction between a rumour and a verified intelligence
   report.

### 2.2 What the Camera Workstation Solves

| Problem | Solution |
|---------|----------|
| Flat intelligence quality | Camera-compiled packages have higher confidence ceiling |
| No merge/synthesis path | Workstation merges multiple raw inputs into one premium artifact |
| TV stations lack strategic value | Camera workstation makes media buildings valuable territory |
| Implicit information tiers | Output artifacts are physically distinct items (not just notes) |
| Manual recon hits a ceiling | Premium compilation rewards further investment beyond pen-and-paper |
| No verification mechanic | Workstation authenticates and formalises raw field data |

---

## 3. Conceptual Architecture

### 3.1 The Four-Tier Intelligence Hierarchy

The Camera Workstation sits at **Tier III** of POSnet's complete intelligence
hierarchy. For the full four-tier system, see `satellite-uplink-design.md`
Section 3.

| Tier | Node | Artifact | Confidence Range | Market Value |
|------|------|----------|------------------|--------------|
| **I — Capture** | Field (pen + paper, recorders) | Raw Market Note | 20-65 | Base |
| **II — Analysis** | Terminal (Process Intelligence) | Intel Fragments | 30-95 | 1.5x |
| **III — Compilation** | Camera Workstation | Compiled reports, bulletins | 70-95 | 2.5x |
| **IV — Broadcast** | Satellite Uplink | Regional market effects | N/A | Reputation |

Each tier maps to a distinct artifact type with its own tooltip, icon, and
market pricing modifier. Higher tiers require more player investment (travel,
materials, time, infrastructure).

**Key change**: The Terminal Analysis layer (Tier II, see
`terminal-analysis-design.md`) now sits between field capture and camera
compilation. Intel Fragments produced by Terminal Analysis are **premium inputs**
for camera compilation, tagged with `POS_CameraInput`.

### 3.2 Pipeline Position

```
    ┌──────────────────────────────────────────────────────────┐
    │                    FIELD COLLECTION (Tier I)              │
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
    │            TERMINAL ANALYSIS (Tier II) [OPTIONAL]        │
    │        (see terminal-analysis-design.md)                 │
    │  Input: 1-5 raw intel items                              │
    │  Output: Intel Fragments (POS_CameraInput tagged)        │
    │  SIGINT skill: PRIMARY effect zone                       │
    └──────────────────────────┬───────────────────────────────┘
                               │
           ┌───────────────────┤  (raw artifacts also accepted)
           │                   │
           ▼                   ▼
    ┌──────────────────────────────────────────────────────────┐
    │            CAMERA WORKSTATION (Tier III)                  │
    │           (TV station CraftBench entity)                 │
    │                                                          │
    │  Input: 1-5 artifacts (raw OR fragments) + paper + tape  │
    │  Action: Timed compilation (ISBaseTimedAction)            │
    │  Output: Compiled Intelligence Package                   │
    │                                                          │
    │  Bonuses: location, diversity, equipment, SIGINT skill   │
    └──────────────────────────┬───────────────────────────────┘
                               │
                               ▼
    ┌──────────────────────────────────────────────────────────┐
    │              COMPILED INTELLIGENCE PACKAGE                │
    │  High-confidence, sellable, broadcast-transmittable      │
    │  Feeds: market database, mission completion, BBS upload  │
    │  → SATELLITE UPLINK (Tier IV) for regional broadcast     │
    └──────────────────────────────────────────────────────────┘
```

### 3.3 What the Camera Workstation Is NOT

The workstation is **not** part of the passive recon pipeline. It does not scan,
detect, or capture data. It compiles, verifies, and formalises data that was
already collected through other means.

This is a critical design constraint: the Camera Workstation should never feel
like a magic box that generates intelligence from nothing. The player must always
bring raw materials that represent real field work.

---

## 4. Furniture Object

### 4.1 Sprite Identification

The Camera Workstation uses the vanilla PZ Build 42 TV-station camera furniture
sprites. These are studio-grade broadcast cameras on tripods, found in TV station
buildings.

**IMPORTANT: Sprite names are subject to B42 beta changes.** The sprite name
whitelist must be verified against the current B42 build before implementation.
The same detection pattern as desktop computers (`POS_ConnectionManager.lua`) and
mailboxes (`POS_MailboxScanner.lua`) applies — sprite name matching via
`obj:getSprite():getName()`.

| Sprite Family | Description | Location |
|---------------|-------------|----------|
| TV station camera sprites | Studio camera on tripod with tally light | TV stations, media offices, university AV departments |

**Research note**: No confirmed vanilla B42 sprite name for TV-station cameras
was identified during design. Implementation must begin with a sprite audit of
TV station buildings in-game to capture the exact sprite names. The entity
definition below uses a placeholder (`location_tv_studio_camera_01_0`) that
must be replaced with the actual sprite name.

### 4.2 CraftBench Entity Definition

```
module Base
{
    entity POS_CameraWorkstation
    {
        component UiConfig
        {
            xuiSkin = default,
            entityStyle = ES_POS_CameraWorkstation,
            uiEnabled = true,
        }
        component CraftBench
        {
            Recipes = POS_CameraWorkstation,
        }
        component SpriteConfig
        {
            face S
            {
                layer
                {
                    /* PLACEHOLDER — replace with actual sprite row */
                    row = location_tv_studio_camera_01_0,
                }
            }
            face E
            {
                layer
                {
                    row = location_tv_studio_camera_01_4,
                }
            }
        }
    }
}
```

### 4.3 Detection Pattern

The Camera Workstation uses the same detection pattern as existing POSnet
furniture objects:

```lua
--- Whitelist of camera workstation sprite names.
--- MUST be verified against current B42 build.
POS_Constants.CAMERA_WORKSTATION_SPRITES = {
    -- Placeholder: replace with verified sprite names
    -- ["location_tv_studio_camera_01_0"] = true,
    -- ["location_tv_studio_camera_01_1"] = true,
}
```

Right-click detection follows the established `POS_DeliveryContextMenu` pattern:
iterate `worldObjects`, check `getSprite():getName()` against the whitelist, and
add context menu options if a match is found.

---

## 5. Compilation Actions

The Camera Workstation offers three compilation actions, each producing a distinct
output artifact. All three are available from first interaction — no unlock gates.

### 5.1 Compile Site Survey

| Property | Value |
|----------|-------|
| Input | 1-3 Raw Market Notes (same category) + 1 Paper |
| Output | 1 Compiled Site Survey |
| Time | 300 seconds (5 min, sandbox-configurable) |
| Animation | `Write` |
| Confidence | Average of input notes × 1.4, capped at 90 |
| Market value | 1.8x base note value |

Merges multiple notes from the same market category into a single higher-quality
document. The more notes consumed, the higher the output confidence (diversity
bonus). Notes from different locations within the same category grant an
additional +5 confidence per unique location.

**Mechanical rationale**: This is the bread-and-butter action. A player who
gathers 3 fuel-market notes from different gas stations can compile them into
one authoritative fuel survey worth significantly more than any individual note.

### 5.2 Review Recorded Tape

| Property | Value |
|----------|-------|
| Input | 1 Recorded VHS tape (or Recorded Microcassette) + 1 Paper + 1 Pen (keep) |
| Output | 1 Verified Intelligence Report |
| Time | 200 seconds (~3.3 min, sandbox-configurable) |
| Animation | `Write` |
| Confidence | Tape base confidence × 1.5, capped at 95 |
| Market value | 2.0x base note value |

Consumes a recorded tape and extracts verified intelligence from the footage.
The studio camera provides proper playback and image analysis that a portable
review cannot match. VHS-C and microcassette media are both accepted (but NOT
floppy disks — digital media routes through the terminal, not the camera).

**Mechanical rationale**: This gives VHS-heavy players a reason to bring tapes
to a TV station rather than processing everything at a terminal. The confidence
multiplier is significantly higher than terminal-only review.

### 5.3 Produce Market Bulletin

| Property | Value |
|----------|-------|
| Input | 2-5 Raw Market Notes (any mix of categories) + 1 VHS tape (blank, consumed) + 1 Paper |
| Output | 1 Market Bulletin |
| Time | 450 seconds (7.5 min, sandbox-configurable) |
| Animation | `Write` |
| Confidence | Weighted average × 1.6, capped at 95 |
| Market value | 2.5x base note value |
| Bonus | +0.5 reputation per bulletin produced |

The premium compilation action. Converts a diverse set of market observations
into a broadcast-ready bulletin package. The blank VHS tape is consumed as the
recording medium for the compiled bulletin. Diversity of input categories
grants a bonus: each unique category beyond the first adds +3 confidence.

**Mechanical rationale**: This is the highest-investment, highest-reward path.
It requires multiple categories of raw intel, a blank tape, paper, and 7.5
minutes of uninterrupted work at a TV station. The reputation bonus makes it
the primary path for players building POSnet standing.

### 5.4 Action Availability States

All three actions use the same 6-state availability system as the existing
"Gather Market Intel" context menu (`POS_MarketContextMenu.lua`):

| State | Condition | Menu Behaviour |
|-------|-----------|----------------|
| `READY` | All requirements met | Clickable, starts timed action |
| `NO_POWER` | Building has no electricity | Greyed out, tooltip explains |
| `MISSING_INPUTS` | Insufficient raw materials | Greyed out, tooltip lists missing |
| `DANGER_NEARBY` | Zombies within danger radius | Greyed out, tooltip warns |
| `ON_COOLDOWN` | Recently compiled at this station | Greyed out, shows remaining time |
| `WRONG_LOCATION` | Not at a camera workstation | Never shown (context menu only appears at workstation) |

### 5.5 Cooldown

Each compilation action has a per-station cooldown scoped to the building
(using the same `BuildingDef.getX()/getY()` composite key pattern as
`POS_MarketReconAction.getVisitKey()`). This prevents rapid exploitation
of a single workstation.

| Action | Default Cooldown | Sandbox Option |
|--------|-----------------|----------------|
| Compile Site Survey | 6 hours (in-game) | `CameraCompileCooldownHours` |
| Review Recorded Tape | 4 hours (in-game) | `CameraTapeReviewCooldownHours` |
| Produce Market Bulletin | 12 hours (in-game) | `CameraBulletinCooldownHours` |

Cooldown is stored in player modData using the key pattern:
`POS_CameraVisit_<buildingDefX>_<buildingDefY>_<actionType>`

---

## 6. Output Artifacts

### 6.1 New Item Definitions

```
item CompiledSiteSurvey {
    DisplayCategory = Information,
    DisplayName = Compiled Site Survey,
    ItemType = base:normal,
    Weight = 0.1,
    Icon = Item_POS_CompiledSiteSurvey,
    Tooltip = Tooltip_POS_CompiledSiteSurvey,
    Tags = POS_Intelligence,
}

item VerifiedIntelReport {
    DisplayCategory = Information,
    DisplayName = Verified Intelligence Report,
    ItemType = base:normal,
    Weight = 0.1,
    Icon = Item_POS_VerifiedIntelReport,
    Tooltip = Tooltip_POS_VerifiedIntelReport,
    Tags = POS_Intelligence,
}

item MarketBulletin {
    DisplayCategory = Information,
    DisplayName = Market Bulletin,
    ItemType = base:normal,
    Weight = 0.15,
    Icon = Item_POS_MarketBulletin,
    Tooltip = Tooltip_POS_MarketBulletin,
    Tags = POS_Intelligence,
}
```

### 6.2 Output ModData Schema

All output artifacts carry modData extending the existing Raw Market Note
pattern:

| Key | Type | Purpose |
|-----|------|---------|
| `POS_ArtifactType` | string | `"site_survey"`, `"intel_report"`, `"market_bulletin"` |
| `POS_ArtifactConfidence` | integer | Final confidence score (0-100) |
| `POS_ArtifactSourceCount` | integer | Number of raw inputs consumed |
| `POS_ArtifactCategories` | string | Pipe-delimited list of input category IDs |
| `POS_ArtifactDay` | integer | Game day when compiled |
| `POS_ArtifactLocation` | string | Address/location of compilation station |
| `POS_ArtifactValueMod` | number | Market value multiplier |

These artifacts feed directly into `POS_MarketDatabase.addRecord()` with the
`sourceTier` set to `POS_Constants.SOURCE_TIER_STUDIO`, producing records
with inherently higher confidence than field-sourced entries.

### 6.3 Downstream Integration

Compiled artifacts integrate with existing systems without modification:

| System | Integration | Changes Needed |
|--------|-------------|----------------|
| `POS_MarketDatabase` | `addRecord()` with `sourceTier = "studio"` | Add `SOURCE_TIER_STUDIO` constant |
| `POS_NoteTooltip` | Dynamic tooltip via `applyToNote()` | Extend with artifact-type display |
| Terminal ingestion | Standard note ingestion path | No changes |
| BBS Markets screen | Records appear with higher confidence | No changes |
| Mission completion | Artifacts satisfy "submit report" objectives | Check `POS_ArtifactType` in objective validation |
| Reputation | Bonus applied at compilation time | No changes to reputation system |

---

## 7. Quality Modifiers

Output confidence is not a flat multiplier. It is composed from multiple factors
that reward player investment in equipment, location, source diversity, and
analytical skill.

### 7.1 Confidence Formula

```
baseConfidence = weightedAverage(inputConfidences)

bonuses = 0
bonuses += locationBonus       -- +10 if inside a real TV/media building
bonuses += diversityBonus      -- +3 per unique source location (cap +15)
bonuses += categoryBonus       -- +3 per unique category (bulletins only, cap +15)
bonuses += equipmentBonus      -- +5 if recorder condition > 80%
bonuses += sigintBonus         -- SIGINT confidence bonus (see sigint-skill-design.md §3.2)
bonuses += fragmentBonus       -- +5 per Intel Fragment input (vs raw note)

multiplier = actionMultiplier  -- 1.4 (survey), 1.5 (tape), 1.6 (bulletin)
multiplier += sigintVerification -- +1% per SIGINT level (max +10%)

finalConfidence = min(cap, floor((baseConfidence + bonuses) * multiplier))
```

Where `cap` is 90 for surveys, 95 for reports and bulletins.

### 7.1a SIGINT Skill Influence

The SIGINT perk (see `sigint-skill-design.md`) provides two modifiers to camera
compilation:

1. **Confidence bonus**: Flat additive bonus from the SIGINT confidence table
   (0 at L0, +25 at L10). Applied alongside equipment and location bonuses.
2. **Verification strength**: +1% per SIGINT level added to the action
   multiplier (max +10% at L10). This represents the analyst's ability to
   verify and strengthen compiled intelligence.

Intel Fragments tagged with `POS_CameraInput` (produced by Terminal Analysis
at SIGINT L6+) provide an additional +5 confidence per fragment input,
representing the value of pre-processed analytical work.

### 7.2 Location Bonus

Using the Camera Workstation inside a building whose room type matches a
recognised media facility grants a +10 confidence bonus. Recognised room types:

| Room Name | Building Type |
|-----------|---------------|
| `tvstudio` | TV station |
| `office` | Media office (when building contains `tvstudio`) |
| `broadcast` | Emergency broadcast room |
| `avroom` | University AV department |

Using the camera in any other building (e.g., a player base where the furniture
has been moved) still works but does not receive the location bonus. This
rewards players who trek to actual media facilities rather than relocating the
furniture.

### 7.3 Source Diversity Bonus

When multiple raw inputs come from different world locations (different
`POS_NoteLocation` values in their modData), each unique location beyond the
first adds +3 confidence, capped at +15 (6+ locations).

This incentivises wide-area field recon over farming a single location
repeatedly.

### 7.4 Equipment Condition

If the player has a Data-Recorder in inventory with condition > 80%, a +5
bonus applies. This represents the recorder providing supplementary digital
metadata that enhances the compilation.

---

## 8. Power Requirements

The Camera Workstation requires electricity to function. This is consistent
with the fiction — studio cameras need power for lighting, monitors, and
recording equipment.

| Condition | Behaviour |
|-----------|-----------|
| Building has grid power | Workstation available |
| Generator powering the building | Workstation available |
| No power | Context menu shows greyed-out option with "No power" tooltip |

Power check uses the standard `sq:haveElectricity()` call on the furniture
object's square, identical to the existing POSnet terminal power check.

---

## 9. Context Menu Structure

Right-clicking a Camera Workstation furniture object presents a **sub-menu**
(per the retroactive rule in `feedback_context_menu_submenus.md`):

```
Right-click camera furniture:
  └─ POSnet Camera Workstation ─┐
                                ├─ Compile Site Survey
                                ├─ Review Recorded Tape
                                └─ Produce Market Bulletin
```

Each sub-menu option shows a tooltip with:
- Current state (ready / greyed reason)
- Required inputs
- Expected output quality
- Cooldown status (if applicable)

### 9.1 Module

New file: `common/media/lua/client/POS_CameraContextMenu.lua`

Follows the established pattern from `POS_MarketContextMenu.lua`:
- Registered via `Events.OnFillWorldObjectContextMenu.Add()`
- Checks sandbox toggle (`POS_Sandbox.isCameraWorkstationEnabled()`)
- Detects camera furniture via sprite whitelist
- Builds sub-menu with all three actions
- Each action evaluates its own availability state independently
- Timed actions use `ISTimedActionQueue.add()` with `ISBaseTimedAction:derive()`

---

## 10. Gameplay Loops

### Loop 1 — Field-to-Studio Pipeline (Primary)

The core gameplay loop the Camera Workstation enables:

1. **Scout in the field** — gather raw market notes via pen-and-paper recon
   (existing system, unchanged)
2. **Accumulate materials** — collect 2-5 notes, preferably from different
   locations and categories
3. **Travel to TV station** — locate and secure a media building (risk/reward:
   travel time + zombie exposure)
4. **Compile at workstation** — choose appropriate action, wait through timed
   action, consume inputs
5. **Receive premium artifact** — Compiled Site Survey / Verified Intel Report /
   Market Bulletin
6. **Transmit at terminal** — upload to POSnet for market impact, mission
   completion, or sale

This loop adds approximately 15-30 minutes of gameplay per compilation cycle
(travel + action time), rewarding patient, methodical players.

### Loop 2 — VHS Tape Review Pipeline (Secondary)

For players invested in the passive recon / Data-Recorder pipeline:

1. **Record passively** — equip recorder with VHS tape, explore as normal
2. **Fill tape** — tape reaches capacity after several game-days of exploration
3. **Travel to TV station** — bring recorded tape to camera workstation
4. **Review at workstation** — produces Verified Intelligence Report (higher
   confidence than terminal-only review)
5. **Ingest at terminal** — feed report into market database

This gives VHS-heavy players a reason to visit TV stations beyond the existing
basic tape review recipe.

### Loop 3 — Bulletin Broadcast Pipeline (Late-Game)

For established players with POSnet reputation:

1. **Gather diverse intel** — collect notes across 3+ market categories
2. **Stockpile blank VHS** — secure recording media
3. **Compile Market Bulletin** — the highest-tier compilation action
4. **Earn reputation** — +0.5 rep per bulletin, the fastest non-mission rep path
5. **Broadcast via terminal** — bulletin enters market database with premium
   confidence, shifting aggregate prices

This loop incentivises broad-spectrum intelligence gathering and positions
the Camera Workstation as late-game infrastructure.

---

## 11. Loot Distribution

The Camera Workstation is a **world-placed furniture object**, not an
inventory item. It does not spawn in loot tables. Players must find it
in situ at media facilities.

### 11.1 Natural Spawn Locations

| Building Type | Expected Count | Notes |
|---------------|---------------|-------|
| TV stations | 1-3 | Primary location; multiple cameras in large studios |
| University AV departments | 0-1 | Academic media lab |
| Government PR offices | 0-1 | Press conference room |
| Emergency broadcast facilities | 0-1 | Civil defence media room |

Camera Workstations cannot be crafted, picked up, or moved by the player.
They are permanent world fixtures. This is intentional: it preserves the
strategic value of controlling media facilities and prevents the workstation
from collapsing into "just another bench at my base."

### 11.2 World Density Estimate

Based on standard PZ map layouts, a typical Muldraugh-area playthrough should
encounter 2-4 camera workstations within a 30-minute drive radius. Louisville
likely has 6-10+. This density ensures the feature is accessible without being
trivial.

---

## 12. Sandbox Options

### 12.1 New Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `EnableCameraWorkstation` | boolean | true | — | Master toggle for camera workstation interactions |
| `CameraCompileTime` | integer | 300 | 120-600 | Compile Site Survey action time (seconds) |
| `CameraTapeReviewTime` | integer | 200 | 60-400 | Review Recorded Tape action time (seconds) |
| `CameraBulletinTime` | integer | 450 | 180-900 | Produce Market Bulletin action time (seconds) |
| `CameraCompileCooldownHours` | integer | 6 | 0-48 | Cooldown between compilations at the same station (0 disables) |
| `CameraTapeReviewCooldownHours` | integer | 4 | 0-48 | Cooldown between tape reviews at the same station |
| `CameraBulletinCooldownHours` | integer | 12 | 0-48 | Cooldown between bulletin productions at the same station |
| `CameraConfidenceMultiplier` | integer | 100 | 50-200 | Percentage modifier on all workstation confidence bonuses |
| `CameraLocationBonusEnabled` | boolean | true | — | Whether the TV-station building location bonus applies |
| `CameraBulletinRepBonus` | integer | 50 | 0-200 | Reputation gained per bulletin (hundredths; 50 = +0.50) |

### 12.2 Existing Options — No Changes

The Camera Workstation respects existing sandbox options where relevant:
- `DangerCheckRadius` (danger proximity check)
- `EnableMarkets` (master market toggle — if markets are disabled, camera
  compilation is also disabled since it produces market intelligence)
- `IntelCooldownDays` (does NOT apply to camera cooldowns — those are
  separately configurable)

---

## 13. Constants

New constants in `POS_Constants.lua`:

```lua
-- Camera Workstation
POS_Constants.SOURCE_TIER_STUDIO              = "studio"
POS_Constants.ITEM_COMPILED_SITE_SURVEY       = "PhobosOperationalSignals.CompiledSiteSurvey"
POS_Constants.ITEM_VERIFIED_INTEL_REPORT      = "PhobosOperationalSignals.VerifiedIntelReport"
POS_Constants.ITEM_MARKET_BULLETIN            = "PhobosOperationalSignals.MarketBulletin"
POS_Constants.CAMERA_VISIT_KEY_PREFIX         = "POS_CameraVisit_"
POS_Constants.CAMERA_COMPILE_ACTION           = "compile"
POS_Constants.CAMERA_TAPE_REVIEW_ACTION       = "tape_review"
POS_Constants.CAMERA_BULLETIN_ACTION          = "bulletin"
POS_Constants.CAMERA_LOCATION_BONUS           = 10
POS_Constants.CAMERA_DIVERSITY_BONUS_PER_LOC  = 3
POS_Constants.CAMERA_DIVERSITY_BONUS_CAP      = 15
POS_Constants.CAMERA_CATEGORY_BONUS_PER_CAT   = 3
POS_Constants.CAMERA_CATEGORY_BONUS_CAP       = 15
POS_Constants.CAMERA_EQUIPMENT_BONUS          = 5
POS_Constants.CAMERA_EQUIPMENT_CONDITION_MIN  = 80
POS_Constants.CAMERA_SURVEY_CONFIDENCE_CAP    = 90
POS_Constants.CAMERA_REPORT_CONFIDENCE_CAP    = 95
POS_Constants.CAMERA_BULLETIN_CONFIDENCE_CAP  = 95
POS_Constants.CAMERA_SURVEY_MULTIPLIER        = 1.4
POS_Constants.CAMERA_REPORT_MULTIPLIER        = 1.5
POS_Constants.CAMERA_BULLETIN_MULTIPLIER      = 1.6
POS_Constants.CAMERA_BULLETIN_REP_DEFAULT     = 50   -- hundredths of rep point
POS_Constants.CAMERA_COMPILE_TIME_DEFAULT     = 300
POS_Constants.CAMERA_TAPE_REVIEW_TIME_DEFAULT = 200
POS_Constants.CAMERA_BULLETIN_TIME_DEFAULT    = 450
POS_Constants.CAMERA_COMPILE_COOLDOWN_DEFAULT = 6    -- hours
POS_Constants.CAMERA_TAPE_COOLDOWN_DEFAULT    = 4    -- hours
POS_Constants.CAMERA_BULLETIN_COOLDOWN_DEFAULT = 12  -- hours

-- Camera workstation sprites (MUST be verified against current B42 build)
POS_Constants.CAMERA_WORKSTATION_SPRITES      = {}   -- populated after sprite audit

-- Media building room types for location bonus
POS_Constants.CAMERA_MEDIA_ROOM_TYPES         = {
    "tvstudio", "broadcast", "avroom",
}
```

---

## 14. Module Architecture

### 14.1 New Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_CameraContextMenu.lua` | Client | Right-click context menu on camera furniture |
| `POS_CameraCompileAction.lua` | Client | ISBaseTimedAction for all three compilation actions |
| `POS_CameraService.lua` | Shared | Core business logic: validate inputs, calculate confidence, produce output |

### 14.2 Modified Modules

| Module | Change |
|--------|--------|
| `POS_Constants.lua` | ~30 new constants (see Section 13) |
| `POS_NoteTooltip.lua` | Extend tooltip provider for 3 new artifact types |
| `POS_Reputation.lua` | No changes needed — `addReputation()` already exists |
| `POS_SandboxIntegration.lua` | 10 new getter functions for camera sandbox options |
| `.luacheckrc` | Add new module globals |

### 14.3 Unchanged Modules

The following are explicitly NOT modified:

- `POS_MarketDatabase.lua` — records arrive via existing `addRecord()` path
- `POS_MarketNoteGenerator.lua` — camera outputs use their own generation path
- `POS_ScreenManager.lua` — no new terminal screens
- `POS_BroadcastSystem.lua` — no new broadcast types
- `POS_EconomyTick.lua` — camera records are standard observations
- `POS_DataRecorderService.lua` — recorder is an input provider, not modified

### 14.4 Separation of Concerns

Following the established POSnet architecture rule (UI / business logic
separation):

- `POS_CameraContextMenu.lua` — **presentation only**. Detects furniture,
  builds menu, delegates to `POS_CameraService` for validation, delegates
  to `POS_CameraCompileAction` for execution.
- `POS_CameraCompileAction.lua` — **timed action only**. Handles animation,
  timing, interruption. Delegates to `POS_CameraService.compile()` in
  `perform()`.
- `POS_CameraService.lua` — **all business logic**. Input validation,
  confidence calculation, artifact generation, cooldown management,
  reputation grants, market record creation.

---

## 15. Persistence Strategy

### Layer 1 (World ModData): No changes

The Camera Workstation does not introduce new world state. Camera furniture
objects are vanilla world-placed items — no registration or tracking needed.

### Layer 2 (Player ModData): Cooldown keys

| Field | Type | Purpose |
|-------|------|---------|
| `POS_CameraVisit_<bx>_<by>_compile` | integer | Game hour of last compilation at building |
| `POS_CameraVisit_<bx>_<by>_tape_review` | integer | Game hour of last tape review at building |
| `POS_CameraVisit_<bx>_<by>_bulletin` | integer | Game hour of last bulletin production at building |

Uses the same `BuildingDef.getX()/getY()` composite key pattern as the
intel cooldown system (Section 14.2a of `design-guidelines.md`).

### Layer 2b (Player File Store): No changes

### Layer 3 (Event Logs): No changes

Output artifacts carry all data in item modData. No event log entries needed
for the Camera Workstation itself.

---

## 16. Icon Pipeline

### 16.1 New Icons Required

| Icon | Item | Style Notes |
|------|------|-------------|
| `Item_POS_CompiledSiteSurvey.png` | Compiled Site Survey | Clipboard with typed document, official stamp or seal. Clean, professional. |
| `Item_POS_VerifiedIntelReport.png` | Verified Intelligence Report | Manila folder with "VERIFIED" stamp, paper edge visible. Authoritative. |
| `Item_POS_MarketBulletin.png` | Market Bulletin | VHS tape with attached typed summary, broadcast-ready label. Professional. |

### 16.2 Specifications

Consistent with existing POSnet icon pipeline:

- **Dimensions**: 128x128 pixels, RGBA PNG
- **Style**: Muted post-apocalyptic palette, slight wear/grime aesthetic
- **Background**: Transparent
- **Naming**: `Item_POS_<ItemName>.png`
- **Generator**: gpt-image-1 (~$0.18 per icon)
- **Estimated cost**: 3 icons x $0.18 = ~$0.54

---

## 17. Translation Keys

### 17.1 Item Names (ItemName.json)

```
"ItemName_CompiledSiteSurvey": "Compiled Site Survey",
"ItemName_VerifiedIntelReport": "Verified Intelligence Report",
"ItemName_MarketBulletin": "Market Bulletin"
```

### 17.2 UI Strings (UI.json)

```
"UI_POS_Camera_SubMenu": "POSnet Camera Workstation",
"UI_POS_Camera_CompileSurvey": "Compile Site Survey",
"UI_POS_Camera_ReviewTape": "Review Recorded Tape",
"UI_POS_Camera_ProduceBulletin": "Produce Market Bulletin",
"UI_POS_Camera_NoPower": "This equipment requires electricity.",
"UI_POS_Camera_MissingNotes": "Requires %1 Raw Market Notes (same category).",
"UI_POS_Camera_MissingTape": "Requires a recorded VHS tape or microcassette.",
"UI_POS_Camera_MissingBlankTape": "Requires a blank VHS tape for recording.",
"UI_POS_Camera_MissingPaper": "Paper required for report transcription.",
"UI_POS_Camera_OnCooldown": "Station recently used. Available in %1 hour(s).",
"UI_POS_Camera_DangerNearby": "Too dangerous to compile reports here.",
"UI_POS_Camera_Ready": "Ready to compile.",
"UI_POS_Camera_Compiling": "Compiling report...",
"UI_POS_Camera_ReviewingTape": "Reviewing footage...",
"UI_POS_Camera_ProducingBulletin": "Producing bulletin...",
"UI_POS_Camera_Complete": "Compilation complete.",
"UI_POS_Camera_Mumble": "*adjusts the camera lens*"
```

### 17.3 Sandbox Strings (Sandbox.json)

Standard pattern: `POS_<OptionName>` for label, `POS_<OptionName>_tooltip` for
tooltip. 10 new options = 20 new translation keys.

### 17.4 Tooltip Strings (Tooltip.json)

Dynamic tooltips for the 3 new artifact types, following the existing
`POS_NoteTooltip` provider pattern via `PhobosLib.registerTooltipProvider()`.

Each tooltip displays:
- Artifact type (survey / report / bulletin)
- Confidence rating with visual bar
- Source count and categories
- Compilation location
- Game day compiled
- Market value modifier

---

## 18. Anti-Patterns — What the Camera Workstation Must Never Become

These constraints are design-level invariants, not just implementation notes:

1. **Not a passive auto-scanner.** The camera never generates data on its own.
   It only processes materials the player brings to it. No `EveryOneMinute`
   hooks, no background scanning, no proximity detection.

2. **Not a replacement for field recon.** Basic pen-and-paper note-taking
   remains fully functional and completely independent of the camera. A player
   who never finds a TV station experiences zero regression.

3. **Not a generic crafting bench.** The camera does not make food, weapons,
   tools, or any non-intelligence items. It has a bespoke identity.

4. **Not a bottleneck for basic reporting.** Raw Market Notes remain the
   primary market intelligence pathway. Camera-compiled artifacts are a
   premium optional upgrade, never a requirement.

5. **Not moveable furniture.** Players cannot pick up, deconstruct, or
   relocate camera furniture. TV stations are strategic territory, not
   portable workshops.

---

## 19. Implementation Phases

### Phase 1 — Core Compilation (Minimum Viable)

- Sprite audit: identify and verify camera furniture sprite names in B42
- `POS_CameraService.lua` — validation, confidence calculation, output generation
- `POS_CameraCompileAction.lua` — timed action (ISBaseTimedAction)
- `POS_CameraContextMenu.lua` — right-click detection + sub-menu
- `POS_CameraWorkstation` entity definition (CraftBench)
- `CompiledSiteSurvey` item definition + icon
- Constants in `POS_Constants.lua`
- Sandbox options: `EnableCameraWorkstation`, `CameraCompileTime`,
  `CameraCompileCooldownHours`
- Translation keys
- Cooldown system (player modData)
- Power requirement check

### Phase 2 — Full Action Set

- `VerifiedIntelReport` item definition + icon
- `MarketBulletin` item definition + icon
- Review Recorded Tape action (VHS + microcassette support)
- Produce Market Bulletin action (multi-category merge)
- Reputation bonus for bulletins
- Remaining sandbox options
- Location bonus (media building detection)
- Source diversity bonus
- Equipment condition bonus
- `POS_NoteTooltip` extensions for all 3 artifact types

### Phase 3 — Mission Integration

- Mission objectives that require camera-compiled artifacts
- "Submit compiled report" mission type (travel → recon → compile → submit)
- Higher-tier missions (Tier III-IV) that mandate camera compilation
- Faction preference system (future): different contacts prefer different
  artifact tiers

### Phase 4 — Polish

- Tutorial tooltip (one-time, PhobosLib notice system)
- Steam Workshop description update
- Documentation updates to `design-guidelines.md`
- Integration testing with Data-Recorder pipeline

---

## 20. What This Design Does NOT Include

These items build ON TOP of this system and are explicitly deferred:

- **Live broadcasting** — using a powered camera + radio to broadcast real-time
  market events to all POSnet clients (Phase 2/3, requires server-side event
  system)
- **Faction-specific compilations** — different factions accepting/preferring
  different artifact formats (future faction system)
- **Propaganda broadcasts** — settlement morale/recruitment broadcasts via
  camera infrastructure (future settlement system)
- **Video playback** — playing back VHS content as ambient visual/audio (PZ
  API limitations)
- **Camera network** — linking multiple cameras across buildings for area-wide
  intelligence coverage (future multiplayer expansion)
- **Authentication chain** — multi-step verification pipeline where unverified →
  reviewed → certified transitions require different workstation types (too
  complex for first implementation; single-step compilation is sufficient)

---

## 21. Relationship to Other Design Documents

| Document | Relationship |
|----------|-------------|
| `terminal-analysis-design.md` | Terminal Analysis produces **Intel Fragments** that are premium camera inputs (`POS_CameraInput` tag) |
| `sigint-skill-design.md` | SIGINT skill provides **confidence bonus** and **verification strength** modifier to camera compilation |
| `satellite-uplink-design.md` | Satellite Uplink **broadcasts** compiled artifacts for regional market effects |
| `data-recorder-design.md` | Recorder is the **input provider** — recorded media is a primary input to camera compilation |
| `passive-recon-design.md` | Passive recon devices fill tapes/media that feed the camera workstation |
| `design-guidelines.md` | Camera follows all existing guidelines (Section 12.5: paper is final medium; Section 14.2a: building-scoped cooldowns) |

The Camera Workstation is the **compilation step** (Tier III) in the full
four-tier intelligence pipeline:

```
passive-recon    data-recorder    terminal-analysis    CAMERA WORKSTATION    satellite-uplink
  (capture)       (buffering)      (understanding)      (compilation)         (projection)
  Tier I          Tier I           Tier II              Tier III              Tier IV
      │               │                │                    │                     │
      └───────────────┴────────────────┴────────────────────┴─────────────────────┘
                                       │
                                 SIGINT SKILL
                            (analytical throughline)
```

All systems are independently useful. The camera adds value on top of raw
field-gathered notes even without terminal analysis or a recorder. Terminal
Analysis adds value even without a camera (fragments sell directly). The
satellite adds value even with simple compiled surveys. No tier is a hard
dependency on another — they are complementary layers in a sophistication
ladder that rewards progressive investment.

---

## 22. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| No confirmed B42 camera furniture sprite | **High** | Phase 1 begins with sprite audit; design is sprite-agnostic |
| TV stations too rare on some maps | Medium | Sandbox toggle allows disabling; university AV rooms as fallback |
| Players relocate furniture to base | Low | Furniture is non-moveable by design; location bonus incentivises in-situ use |
| Compilation too powerful (market manipulation) | Medium | Confidence caps (90-95), cooldowns, input requirements balance output |
| Complexity creep from 3 action types | Low | Phase 1 ships with only Compile Site Survey; others added in Phase 2 |
| Interaction with Data-Recorder not yet implemented | None | Camera accepts raw notes (existing items) independently of recorder |

---

## 23. Success Criteria

The Camera Workstation implementation is successful when:

1. A player can gather 3 Raw Market Notes from different gas stations, travel
   to a TV station, and compile them into a Compiled Site Survey that has
   measurably higher confidence than any individual input note
2. TV stations feel like strategically valuable locations that players
   actively seek out and defend
3. The compilation process feels deliberate and rewarding — not tedious,
   not trivial
4. Players who never use the camera experience zero regression in existing
   note-taking, terminal, and market systems
5. The 3-tier information system (unverified / reviewed / certified) is
   clearly communicated through item names, tooltips, and market price
   differences
6. All output artifacts produce valid `POS_MarketDatabase` records and
   display correctly in BBS market screens
