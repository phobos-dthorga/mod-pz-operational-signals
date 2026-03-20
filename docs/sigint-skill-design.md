# POSnet SIGINT Skill System — Design & Styling Guide

**Branch**: `dev/data-recorder` (future)
**Date**: 2026-03-20
**Status**: Design phase — implementation not started
**Prerequisites**: Terminal Analysis system implemented (see `terminal-analysis-design.md`),
Camera Workstation operational (see `camera-workstation-design.md`)

---

## Executive Summary

SIGINT (Signal Intelligence) is a **custom PZ perk** that governs the player's
ability to extract meaning from incomplete, noisy, fragmented information. It is
the intellectual backbone of the entire POSnet intelligence pipeline — not a
generic "radio skill" or "tech skill", but a formalised discipline of analysis
that determines how effectively the player can interpret the world through
POSnet's systems.

```
                        SIGINT SKILL DOMAIN
                        ════════════════════

  FIELD          TERMINAL         CAMERA          SATELLITE
  (capture)      (analysis)       (compilation)   (broadcast)
  ─────────      ──────────       ────────────    ───────────
  Minimal        PRIMARY          Secondary       Tertiary
  effect         domain           influence       influence

  Chaos is       Clarity          Quality         Credibility
  chaos          improves         scales          amplifies
```

SIGINT does not increase power directly. It increases **clarity, efficiency,
confidence, and depth of interpretation**. A high-SIGINT player extracts more
insights from the same raw inputs, produces cleaner analysis, compiles stronger
reports, and broadcasts with greater authority.

The diegetic fantasy: *"I don't just observe the system — I understand it."*

Applied Chemistry transforms **materials**. SIGINT transforms **information**.
Together they form: **Matter + Knowledge = Power**.

---

## 1. What SIGINT Is

A **custom PZ perk** registered via the standard `Perks` API that represents the
player's ability to process, correlate, and interpret signal-based intelligence.
It is earned through analytical work at POSnet infrastructure, not through
grinding or combat.

It is:
- A 0-10 skill with qualitative progression tiers (not flat scaling)
- The primary modifier for Terminal Analysis output quality and yield
- A secondary modifier for Camera Workstation compilation confidence
- A tertiary modifier for Satellite Uplink broadcast credibility
- Integrated with ZScienceSkill for cross-mod XP mirroring (optional)
- Expressible through character traits at creation time

It is NOT:
- A radio operation skill (radios work regardless of SIGINT level)
- A combat or crafting skill (SIGINT affects information, not physical objects)
- A gate on basic functionality (all POSnet features work at SIGINT 0)
- A passive background grinder (XP comes from deliberate analytical actions)

---

## 2. Why It Must Exist

### 2.1 Current Gap

The existing POSnet pipeline treats all players identically:

1. **No skill expression.** A brand-new character and a 90-day veteran produce
   identical market notes from the same location. There is no mechanical reward
   for analytical investment.

2. **Binary knowledge model.** Data is either "gathered" or "not gathered". There
   is no gradient of understanding, no partial knowledge, no evolving
   interpretation.

3. **No character differentiation.** POSnet builds cannot specialise. An
   "intelligence analyst" character has no mechanical advantage over a
   "construction worker" character in information processing.

4. **Flat quality ceiling.** Confidence modifiers come from equipment and location
   only. The player's own growing expertise is never represented.

### 2.2 What SIGINT Solves

| Problem | Solution |
|---------|----------|
| No skill expression | SIGINT perk scales analysis output quality and yield |
| Binary knowledge | Intermediate artifacts with confidence gradients |
| No character differentiation | Traits + skill books enable intel-focused builds |
| Flat quality ceiling | SIGINT multiplier stacks with equipment and location bonuses |
| Grinding feels generic | XP earned through thinking (analysis), not repetition |

---

## 3. Skill Progression

SIGINT uses **qualitative evolution**, not flat percentage scaling. Each tier
represents a fundamentally different relationship with information.

### 3.1 Tier Definitions

| Level | Tier Name | Description |
|-------|-----------|-------------|
| 0-2 | Noise Drowner | Lots of junk outputs, low confidence insights, frequent contradictions, slow processing |
| 3-5 | Pattern Seeker | Fewer junk results, basic pattern recognition, occasional higher-tier insights, faster processing |
| 6-8 | Analyst | Consistent high-quality insights, multi-source correlation, better report outputs, reduced randomness |
| 9-10 | Intelligence Operator | Near-perfect signal clarity, rare/high-value insight generation, strong broadcast effects, resistance to false data |

### 3.2 Per-Level Modifiers

| Level | Analysis Yield | Noise Filter | Time Modifier | Confidence Bonus |
|-------|---------------|-------------|---------------|-----------------|
| 0 | 1 output | 0% filtered | +0% (base) | +0 |
| 1 | 1 output | 5% filtered | -3% | +2 |
| 2 | 1 output | 10% filtered | -6% | +4 |
| 3 | 1-2 outputs | 20% filtered | -10% | +6 |
| 4 | 1-2 outputs | 25% filtered | -14% | +8 |
| 5 | 1-2 outputs | 35% filtered | -18% | +10 |
| 6 | 2-3 outputs | 45% filtered | -24% | +13 |
| 7 | 2-3 outputs | 55% filtered | -28% | +16 |
| 8 | 2-3 outputs | 65% filtered | -32% | +19 |
| 9 | 2-4 outputs | 80% filtered | -38% | +22 |
| 10 | 2-4 outputs | 90% filtered | -44% | +25 |

**Analysis Yield**: Number of Intel Fragments produced per Terminal Analysis
action (see `terminal-analysis-design.md`).

**Noise Filter**: Percentage chance that a junk/misleading output is suppressed
and replaced with a valid insight.

**Time Modifier**: Reduction to Terminal Analysis action duration (stacks with
sandbox option).

**Confidence Bonus**: Flat additive bonus to all intelligence artifact confidence
scores (applied after equipment and location bonuses, before cap).

---

## 4. Mechanical Effects Per Layer

SIGINT's influence is **strongest at the terminal** and **diminishes outward**
toward field and broadcast. This is intentional: the terminal is where the
player *thinks*, and thinking is what SIGINT represents.

### 4.1 Field (Capture) — Minimal Effect

SIGINT has negligible effect on raw field data collection. Chaos is chaos.

| Mechanic | SIGINT Effect |
|----------|--------------|
| Manual note-taking (Gather Intel) | +1 confidence per 3 SIGINT levels (max +3) |
| Passive recon device scanning | No effect (hardware-determined) |
| Data-Recorder buffer capture | No effect (hardware-determined) |

**Design rationale**: Field data is raw observation. A trained analyst and a
novice see the same fuel depot — the difference emerges when they sit down
to *interpret* what they saw.

### 4.2 Terminal (Analysis) — Primary Domain

This is where SIGINT shines. Every aspect of Terminal Analysis scales with
the perk level.

| Mechanic | SIGINT Effect |
|----------|--------------|
| Intel Fragment yield | Level-dependent (1 at L0, up to 2-4 at L10) |
| Fragment quality tier | Higher SIGINT = higher chance of Correlated/Confirmed tier |
| Noise filtering | Junk outputs suppressed (0% at L0, 90% at L10) |
| Processing time | Reduced (up to -44% at L10) |
| Cross-correlation | Unlocked at L6+: multiple unrelated inputs combine into new insights |
| False data detection | Unlocked at L8+: chance to flag contradictory/misleading inputs |

### 4.3 Camera (Compilation) — Secondary Influence

SIGINT improves the Camera Workstation's compilation process, but the
workstation's own multipliers and location bonuses remain dominant.

| Mechanic | SIGINT Effect |
|----------|--------------|
| Compilation confidence | +`confidenceBonus` from SIGINT table (Section 3.2) |
| Contradiction reduction | Higher SIGINT reduces variance in merged note confidence |
| Verification strength | +1% per SIGINT level to final confidence multiplier (max +10%) |

### 4.4 Satellite (Broadcast) — Tertiary Influence

SIGINT affects how the broadcast is received by the world, not the physical
transmission itself.

| Mechanic | SIGINT Effect |
|----------|--------------|
| Broadcast credibility weight | Higher SIGINT = stronger market impact per broadcast |
| Propagation persistence | Broadcast effects decay slower with higher SIGINT |
| Misinformation resistance | At L8+, satellite can flag and suppress false incoming data |

---

## 5. XP Sources

SIGINT XP is earned through **analytical work**, not passive accumulation. The
player must deliberately engage with POSnet intelligence systems.

### 5.1 Primary Sources

| Action | XP Award | Notes |
|--------|----------|-------|
| Terminal Analysis: Process Intelligence | 15-25 XP | Main XP source; scales with input count |
| Terminal Analysis: Cross-correlation discovery | +10 XP bonus | When multiple inputs produce emergent insight |
| Resolving contradictions | +8 XP bonus | When analysis identifies and corrects conflicting data |

### 5.2 Secondary Sources

| Action | XP Award | Notes |
|--------|----------|-------|
| Camera Workstation: Compile Site Survey | 8 XP | Minor XP for compilation work |
| Camera Workstation: Review Recorded Tape | 6 XP | |
| Camera Workstation: Produce Market Bulletin | 12 XP | Highest camera XP (most complex action) |
| Satellite: Broadcast Compiled Report | 10 XP | Broadcasting is execution, not analysis |

### 5.3 Tertiary Sources

| Action | XP Award | Notes |
|--------|----------|-------|
| Manual note-taking (Gather Intel) | 3 XP | Field work grants minimal SIGINT XP |
| VHS tape review at TV station | 5 XP | Watching footage has minor analytical value |
| Successful mission report submission | 5 XP | Completing the intelligence cycle |

### 5.4 XP Scaling

XP awards are **not** modified by SIGINT level. A Level 0 player and a Level 10
player earn the same base XP for the same action. This prevents runaway
progression and keeps the skill honest — you advance by *doing work*, not by
*being high level*.

Skill books (Section 6) provide XP rate multipliers during their active reading
period, following the standard PZ skill book pattern.

---

## 6. Skill Books

Five SIGINT skill books span the full 0-10 progression, following the standard
PZ skill book pattern (each covers 2 levels and provides an XP multiplier during
the active reading period).

| Book | Covers Levels | XP Multiplier | Loot Locations |
|------|--------------|---------------|----------------|
| Amateur Radio Monitoring | 0-2 | 2x | Electronics stores, ham radio shacks, garages |
| Signal Interpretation Basics | 2-4 | 3x | Libraries, university offices, bookstores |
| Cold War Intelligence Techniques | 4-6 | 4x | Military bases, government buildings, rare bookstores |
| Field Analysis & Recon Doctrine | 6-8 | 6x | Military bases, police HQ evidence rooms |
| Advanced Signal Correlation | 8-10 | 8x | Military intelligence offices, secure government facilities |

### 6.1 Book Item Definitions

```
item SIGINTBook1 {
    DisplayCategory = Literature,
    DisplayName = Amateur Radio Monitoring,
    ItemType = base:literature,
    Weight = 0.5,
    Icon = Item_POS_SIGINTBook1,
    Tags = POS_SkillBook,
    SkillTrained = SIGINT,
    LvlSkillTrained = 1,
    NumLevelsTrained = 2,
    MaxLevelTrained = 2,
}
```

(Pattern repeats for books 2-5 with appropriate level ranges.)

### 6.2 Recipe Books

No recipe books are needed for SIGINT. The skill does not unlock crafting
recipes — it modifies the quality and yield of analytical actions. All POSnet
actions are available from Level 0.

---

## 7. Traits

SIGINT traits allow character-creation-time specialisation. They follow the
standard PZ trait pattern with point costs/grants.

### 7.1 Positive Traits

| Trait | Cost | Effect |
|-------|------|--------|
| Analytical Mind | -4 pts | +1 SIGINT starting level, +25% SIGINT XP rate |
| Radio Hobbyist | -2 pts | +1 SIGINT starting level, radio scan radius +20% |
| Systems Thinker | -3 pts | Cross-correlation unlocked at L4 (normally L6) |

### 7.2 Negative Traits

| Trait | Grant | Effect |
|-------|-------|--------|
| Impatient | +2 pts | Terminal Analysis actions take +30% longer |
| Disorganised Thinker | +3 pts | -25% SIGINT XP rate, +20% noise in outputs |
| Signal Blindness | +4 pts | Cannot gain SIGINT above Level 5 (hard cap) |

### 7.3 Trait Registration

Traits are registered in `POS_Registries.lua` via `CharacterTrait.register()`
following the PhobosLib pattern. Translation keys use `Trait_POS_<TraitId>` and
`Trait_POS_<TraitId>_desc` format.

---

## 8. Cross-Mod Integration

### 8.1 ZScienceSkill

If ZScienceSkill is active, SIGINT XP mirrors to the ZScience system via
`POS_ZScienceIntegration.lua`. The mirror ratio is sandbox-configurable
(default: 0.5x — SIGINT XP is halved when mirrored to ZScience).

This follows the exact pattern established by PCP's Applied Chemistry
integration.

### 8.2 ZScienceSkill Specimens

Terminal Analysis can produce ZScience specimens as bonus outputs at higher
SIGINT levels:

| Specimen | SIGINT Level | Chance | Source Action |
|----------|-------------|--------|---------------|
| Signal Pattern Fragment | 3+ | 15% | Terminal Analysis |
| Correlated Data Matrix | 6+ | 10% | Cross-correlation |
| Verified Intelligence Schema | 9+ | 5% | Any high-confidence output |

### 8.3 EHR (Epidemic Health Response)

No direct integration. SIGINT is an information skill, not a biological one.

### 8.4 Dynamic Trading

High-SIGINT players (L6+) receive a passive discount on information-category
trades via `POS_TradingIntegration.lua` (if Dynamic Trading is active). This
represents their reputation as skilled analysts making their intelligence more
valuable in barter.

---

## 9. Sandbox Options

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `EnableSIGINTSkill` | boolean | true | — | Master toggle for the SIGINT perk |
| `SIGINTXPMultiplier` | integer | 100 | 25-400 | Global XP rate modifier (percentage) |
| `SIGINTNoiseReduction` | enum | Standard | None/Low/Standard/High | How aggressively noise filtering scales with level |
| `SIGINTTimeReduction` | boolean | true | — | Whether SIGINT reduces Terminal Analysis action time |
| `SIGINTCrossCorrelationLevel` | integer | 6 | 3-10 | Minimum SIGINT level for cross-correlation (0 disables) |
| `SIGINTConfidenceBonus` | enum | Standard | None/Low/Standard/High | Confidence bonus scaling per SIGINT level |
| `SIGINTTraitsEnabled` | boolean | true | — | Whether SIGINT-related traits appear at character creation |
| `SIGINTBookSpawns` | boolean | true | — | Whether SIGINT skill books appear in world loot |

---

## 10. Constants

New constants in `POS_Constants.lua`:

```lua
-- SIGINT Skill
POS_Constants.SIGINT_PERK_ID                   = "SIGINT"
POS_Constants.SIGINT_PERK_PARENT               = "Passiv"  -- PZ passive skills category
POS_Constants.SIGINT_MAX_LEVEL                 = 10

-- SIGINT tier thresholds
POS_Constants.SIGINT_TIER_NOISE_DROWNER        = 0   -- L0-2
POS_Constants.SIGINT_TIER_PATTERN_SEEKER       = 3   -- L3-5
POS_Constants.SIGINT_TIER_ANALYST              = 6   -- L6-8
POS_Constants.SIGINT_TIER_INTEL_OPERATOR       = 9   -- L9-10

-- SIGINT cross-correlation unlock
POS_Constants.SIGINT_CROSS_CORRELATION_LEVEL   = 6
POS_Constants.SIGINT_FALSE_DATA_DETECTION_LEVEL = 8

-- SIGINT XP awards
POS_Constants.SIGINT_XP_TERMINAL_ANALYSIS      = 20  -- base, varies 15-25
POS_Constants.SIGINT_XP_CROSS_CORRELATION      = 10
POS_Constants.SIGINT_XP_RESOLVE_CONTRADICTION  = 8
POS_Constants.SIGINT_XP_CAMERA_SURVEY          = 8
POS_Constants.SIGINT_XP_CAMERA_TAPE_REVIEW     = 6
POS_Constants.SIGINT_XP_CAMERA_BULLETIN        = 12
POS_Constants.SIGINT_XP_SATELLITE_BROADCAST    = 10
POS_Constants.SIGINT_XP_MANUAL_NOTE            = 3
POS_Constants.SIGINT_XP_VHS_REVIEW             = 5
POS_Constants.SIGINT_XP_MISSION_REPORT         = 5

-- SIGINT confidence bonus per level (flat additive)
POS_Constants.SIGINT_CONFIDENCE_PER_LEVEL      = {0,2,4,6,8,10,13,16,19,22,25}

-- SIGINT noise filter percentage per level
POS_Constants.SIGINT_NOISE_FILTER_PER_LEVEL    = {0,5,10,20,25,35,45,55,65,80,90}

-- SIGINT time reduction percentage per level
POS_Constants.SIGINT_TIME_REDUCTION_PER_LEVEL  = {0,3,6,10,14,18,24,28,32,38,44}

-- SIGINT analysis yield ranges per level {min, max}
POS_Constants.SIGINT_YIELD_PER_LEVEL           = {
    {1,1},{1,1},{1,1},  -- L0-2: 1 output
    {1,2},{1,2},{1,2},  -- L3-5: 1-2 outputs
    {2,3},{2,3},{2,3},  -- L6-8: 2-3 outputs
    {2,4},{2,4},        -- L9-10: 2-4 outputs
}

-- SIGINT trait IDs
POS_Constants.TRAIT_ANALYTICAL_MIND            = "POS_AnalyticalMind"
POS_Constants.TRAIT_RADIO_HOBBYIST             = "POS_RadioHobbyist"
POS_Constants.TRAIT_SYSTEMS_THINKER            = "POS_SystemsThinker"
POS_Constants.TRAIT_IMPATIENT                  = "POS_Impatient"
POS_Constants.TRAIT_DISORGANISED_THINKER       = "POS_DisorganisedThinker"
POS_Constants.TRAIT_SIGNAL_BLINDNESS           = "POS_SignalBlindness"

-- SIGINT item prefixes
POS_Constants.ITEM_SIGINT_BOOK_PREFIX          = "PhobosOperationalSignals.SIGINTBook"

-- ZScience mirror ratio (default)
POS_Constants.SIGINT_ZSCIENCE_MIRROR_RATIO     = 0.5
```

---

## 11. Module Architecture

### 11.1 New Modules

| Module | Layer | Purpose |
|--------|-------|---------|
| `POS_SIGINTSkill.lua` | Shared | Perk registration, level queries, modifier calculations |
| `POS_SIGINTService.lua` | Shared | Core business logic: XP awards, yield calculations, noise filtering |
| `POS_SIGINTTraits.lua` | Shared | Trait registration and effect application |
| `POS_SIGINTBooks.lua` | Shared | Skill book item definitions and loot integration |

### 11.2 Modified Modules

| Module | Change |
|--------|--------|
| `POS_Constants.lua` | ~50 new constants (see Section 10) |
| `POS_Registries.lua` | Trait registration calls |
| `POS_SandboxIntegration.lua` | 8 new getter functions for SIGINT sandbox options |
| `POS_ZScienceIntegration.lua` | SIGINT XP mirror + 3 new specimen types |
| `.luacheckrc` | Add new module globals |

### 11.3 Consumed By (Not Modified)

| Module | How It Uses SIGINT |
|--------|-------------------|
| `POS_TerminalAnalysisService.lua` | Calls `POS_SIGINTService.getYieldRange()`, `getNoiseFilter()`, `getTimeModifier()` |
| `POS_CameraService.lua` | Calls `POS_SIGINTService.getConfidenceBonus()` |
| `POS_SatelliteService.lua` | Calls `POS_SIGINTService.getBroadcastCredibility()` |
| `POS_MarketReconAction.lua` | Calls `POS_SIGINTService.getFieldConfidenceBonus()` |

### 11.4 Separation of Concerns

- `POS_SIGINTSkill.lua` — **registration only**. Registers the perk with PZ,
  provides `getLevel(player)` and `addXP(player, amount)` wrappers.
- `POS_SIGINTService.lua` — **all calculations**. Every modifier lookup, yield
  range, noise filter probability, and time reduction. No direct game state
  mutation — returns values for callers to apply.
- `POS_SIGINTTraits.lua` — **trait effects only**. Applies starting level
  bonuses, XP rate modifiers, and hard caps from traits.

---

## 12. Persistence Strategy

### Player ModData

| Field | Type | Purpose |
|-------|------|---------|
| `POS_SIGINT_TotalXP` | integer | Accumulated SIGINT XP (for ZScience mirror tracking) |
| `POS_SIGINT_CrossCorrelations` | integer | Lifetime cross-correlation count (stat tracking) |

SIGINT level itself is stored in the standard PZ perk system (`player:getPerkLevel()`),
not in ModData.

### World ModData

No world-level SIGINT state. The skill is entirely per-player.

---

## 13. Translation Keys

### 13.1 Perk Names (UI.json)

```
"UI_POS_Perk_SIGINT": "Signal Intelligence",
"UI_POS_Perk_SIGINT_desc": "The ability to extract meaning from incomplete, noisy, fragmented information. Improves analysis yield, confidence, and processing speed at POSnet terminals and workstations."
```

### 13.2 Trait Strings (UI.json)

```
"Trait_POS_AnalyticalMind": "Analytical Mind",
"Trait_POS_AnalyticalMind_desc": "Natural aptitude for pattern recognition. +1 SIGINT, +25% SIGINT XP.",
"Trait_POS_RadioHobbyist": "Radio Hobbyist",
"Trait_POS_RadioHobbyist_desc": "Pre-apocalypse radio enthusiast. +1 SIGINT, +20% radio scan radius.",
"Trait_POS_SystemsThinker": "Systems Thinker",
"Trait_POS_SystemsThinker_desc": "Sees connections others miss. Cross-correlation unlocks earlier (SIGINT 4).",
"Trait_POS_Impatient": "Impatient",
"Trait_POS_Impatient_desc": "Can't sit still. Terminal analysis takes 30% longer.",
"Trait_POS_DisorganisedThinker": "Disorganised Thinker",
"Trait_POS_DisorganisedThinker_desc": "Struggles to focus. -25% SIGINT XP, +20% noise in analysis.",
"Trait_POS_SignalBlindness": "Signal Blindness",
"Trait_POS_SignalBlindness_desc": "Cannot grasp complex signal patterns. SIGINT capped at Level 5."
```

### 13.3 Skill Book Names (ItemName.json)

```
"ItemName_SIGINTBook1": "Amateur Radio Monitoring",
"ItemName_SIGINTBook2": "Signal Interpretation Basics",
"ItemName_SIGINTBook3": "Cold War Intelligence Techniques",
"ItemName_SIGINTBook4": "Field Analysis & Recon Doctrine",
"ItemName_SIGINTBook5": "Advanced Signal Correlation"
```

### 13.4 Sandbox Strings (Sandbox.json)

Standard pattern: `POS_<OptionName>` for label, `POS_<OptionName>_tooltip` for
tooltip. 8 new options = 16 new translation keys.

---

## 14. Icon Pipeline

### 14.1 New Icons Required

| Icon | Item | Style Notes |
|------|------|-------------|
| `Item_POS_SIGINTBook1.png` | Amateur Radio Monitoring | Paperback with radio tower cover art, worn |
| `Item_POS_SIGINTBook2.png` | Signal Interpretation Basics | Technical manual, spiral bound, annotated |
| `Item_POS_SIGINTBook3.png` | Cold War Intelligence Techniques | Hardcover, declassified stamp, Cold War era aesthetic |
| `Item_POS_SIGINTBook4.png` | Field Analysis & Recon Doctrine | Military field manual, olive drab, dog-eared |
| `Item_POS_SIGINTBook5.png` | Advanced Signal Correlation | Thick academic text, worn spine, post-its sticking out |

### 14.2 Specifications

- **Dimensions**: 128x128 pixels, RGBA PNG
- **Style**: Muted post-apocalyptic palette, slight wear/grime aesthetic
- **Background**: Transparent
- **Naming**: `Item_POS_<ItemName>.png`
- **Generator**: gpt-image-1 (~$0.18 per icon)
- **Estimated cost**: 5 icons x $0.18 = ~$0.90

---

## 15. Implementation Phases

### Phase 1 — Perk Registration (Minimum Viable)

- Register `SIGINT` perk via `Perks` API
- `POS_SIGINTSkill.lua` — `getLevel()`, `addXP()`
- `POS_SIGINTService.lua` — confidence bonus calculation only
- Wire confidence bonus into `POS_MarketReconAction` (manual note-taking)
- Constants in `POS_Constants.lua`
- Sandbox options: `EnableSIGINTSkill`, `SIGINTXPMultiplier`
- XP award for manual note-taking (3 XP)
- Translation keys for perk name and description

### Phase 2 — Terminal Integration

- Wire yield range, noise filter, and time modifier into Terminal Analysis
- XP awards for Terminal Analysis actions (15-25 XP)
- Cross-correlation unlock at L6 (sandbox-configurable)
- False data detection at L8+
- Remaining sandbox options

### Phase 3 — Camera & Satellite Integration

- Wire confidence bonus into Camera Workstation compilation
- Wire broadcast credibility into Satellite Uplink
- XP awards for camera and satellite actions
- Verification strength modifier for camera

### Phase 4 — Character Creation

- Trait registration (3 positive, 3 negative)
- Skill book item definitions (5 books)
- Loot table integration for books
- Icons for books
- ZScienceSkill mirror integration + specimens

### Phase 5 — Polish

- Tutorial tooltip (one-time, PhobosLib notice system)
- Level-up notification via `PhobosLib.notifyOrSay()`
- Skill progression feels test (balance pass)
- Documentation updates to `design-guidelines.md`

---

## 16. Anti-Patterns — What SIGINT Must Never Become

These constraints are design-level invariants:

1. **Not "numbers go up = things get stronger."** SIGINT must feel like
   *understanding deepens*, not *power increases*. The output descriptions
   should evolve qualitatively, not just numerically.

2. **Not a gate on basic functionality.** A Level 0 player can gather notes,
   use the terminal, compile at the camera, and broadcast via satellite.
   SIGINT improves these actions — it never blocks them.

3. **Not a passive grinder.** XP comes from deliberate analytical actions
   at POSnet infrastructure. Carrying a radio while running around does
   NOT award SIGINT XP.

4. **Not a combat skill.** SIGINT has zero effect on fighting, building,
   cooking, or any non-information activity.

5. **Not a radio operation prerequisite.** Radios work identically at
   SIGINT 0 and SIGINT 10. The skill affects *interpretation*, not
   *operation*.

6. **Not exponential.** The confidence bonus table (Section 3.2) is
   deliberately sub-linear at high levels. The jump from L0 to L5
   (+10 confidence) is similar to the jump from L5 to L10 (+15
   confidence). Diminishing returns prevent SIGINT from dominating
   the confidence formula.

---

## 17. Relationship to Other Design Documents

| Document | Relationship |
|----------|-------------|
| `terminal-analysis-design.md` | Terminal Analysis is the **primary domain** where SIGINT applies — yield, noise, time, cross-correlation |
| `camera-workstation-design.md` | Camera compilation receives SIGINT confidence bonus and verification strength modifier |
| `satellite-uplink-design.md` | Satellite broadcast credibility and persistence scale with SIGINT |
| `data-recorder-design.md` | Recorder hardware is SIGINT-independent — captures raw data regardless of skill level |
| `passive-recon-design.md` | Passive recon devices are hardware-determined — SIGINT does not affect scan radius or detection |
| `design-guidelines.md` | SIGINT follows all existing guidelines; new section added for skill-specific rules |

The SIGINT skill is the **analytical throughline** connecting all POSnet systems:

```
passive-recon    data-recorder    camera-workstation    satellite-uplink
  (hardware)      (hardware)        (infrastructure)     (infrastructure)
       │               │                  │                    │
       └───────────────┴──────────────────┴────────────────────┘
                                │
                          SIGINT SKILL
                     (player progression)
                                │
                    ┌───────────┴───────────┐
                    │  terminal-analysis    │
                    │  (primary domain)     │
                    └───────────────────────┘
```

Hardware determines *what data is captured*. Infrastructure determines *where
processing occurs*. SIGINT determines *how well the player interprets it all*.

---

## 18. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| PZ B42 custom perk API changes | Medium | Wrap in pcall; fallback to modData-based level tracking |
| SIGINT feels irrelevant at low levels | Medium | Ensure L0 experience is functional; skill books common enough to start progressing early |
| SIGINT dominates confidence formula | Low | Sub-linear scaling; confidence bonus is additive, not multiplicative |
| Trait balance disrupts character creation | Low | Conservative point costs; traits tested against vanilla trait economy |
| ZScienceSkill not installed | None | All SIGINT code is self-contained; ZScience integration is optional |

---

## 19. Success Criteria

The SIGINT skill implementation is successful when:

1. A Level 0 player can perform all POSnet actions with reasonable (not
   crippled) output quality
2. A Level 5 player noticeably extracts more and better insights from the
   same raw inputs than a Level 0 player
3. A Level 10 player feels like a genuine intelligence analyst — insights
   are clean, cross-correlations emerge, and broadcasts carry weight
4. Players who invest in SIGINT skill books and analytical actions progress
   at a satisfying rate without feeling grindy
5. The "Analytical Mind" trait feels like a meaningful character build choice,
   not a mandatory pick
6. SIGINT XP sources feel earned — the player knows *why* they are gaining
   skill, not just that a number went up
