# POSnet Mission System Design

> **Status**: Design document. Not yet implemented.
> **Prerequisite reading**: `design-guidelines.md` Sections 1 (Mission Design),
> 26 (Data-Pack Architecture); `living-market-design.md` (zone/archetype context).
> **Depends on**: PhobosLib v1.59.0 (text compositor API).

This document defines the architecture for POSnet's schema-driven mission
content system with randomised briefings. It replaces the current hardcoded
16-target recon catalogue (`POS_ReconGenerator.TARGETS`) with a data-pack
approach where missions are declarative data, not code.

---

## 1. Overview

Missions in POSnet are **compositional**: each briefing is assembled at
generation time from independent text pools, resolved against world context,
and persisted as final text. The schema defines *what* a mission is (category,
difficulty, location rules, reward range). Text pools define *how* it reads
(situation, tasking, constraints). Voice packs give each sponsor archetype a
distinct tone.

**Core invariant**: briefing text is generated once and stored. It is never
regenerated from schema. If the schema changes after a mission is created, the
existing mission retains its original text. This aligns with the existing
operation lifecycle convention (design-guidelines.md Section 25.6).

The text compositor pipeline uses four PhobosLib v1.59.0 functions:

| Function | Purpose |
|----------|---------|
| `resolveTokens(text, tokenTable)` | Replace `{token}` placeholders with runtime values |
| `pickWeighted(entries, weightField)` | Select one entry from a weighted pool |
| `conditionsPass(entry, context)` | Evaluate optional condition predicates |
| `avoidRecent(entries, history, maxSize)` | Suppress recently-used entries |

---

## 2. Architecture Layers

```
+-------------------------------+
|     Mission Definition        |  Definitions/Missions/*.lua
|  (schema-validated data)      |  category, difficulty, location rules,
|                               |  reward range, briefing pool references
+---------------+---------------+
                |
                v
+---------------+---------------+
|        Text Pools             |  Definitions/TextPools/*.lua
|  (weighted text fragments     |  {token} placeholders, conditions,
|   per section per category)   |  voice pack overrides
+---------------+---------------+
                |
                v
+---------------+---------------+
|     Context Tokens            |  Runtime world values:
|  {zoneName}, {targetName},    |  zone, building, sponsor, reward,
|  {rewardCash}, {deadlineDay}  |  player location, risk level
+---------------+---------------+
                |
                v
+---------------+---------------+
|   Briefing Resolver           |  POS_MissionBriefingResolver.lua
|  For each section:            |  pickWeighted + conditionsPass +
|    pool -> pick -> resolve    |  avoidRecent + resolveTokens
+---------------+---------------+
                |
                v
+---------------+---------------+
|   Persisted Operation         |  Operation table with final briefing
|  (player modData via          |  text stored as section array.
|   POS_OperationLog)           |  Never regenerated.
+-------------------------------+
```

### 2.1 Mission Definitions (Definitions/Missions/*.lua)

Schema-validated data files following the data-pack conventions from
design-guidelines.md Section 26. Each file returns a single table defining one
mission template. Fields include: id, name, category, difficulty range,
location rules, briefing pool references, objective template, reward range,
and expiry range.

Mission definitions are loaded at init time via `PhobosLib.loadDefinitions()`
and stored in a typed registry created by `PhobosLib.createRegistry()`.

### 2.2 Text Pools (Definitions/TextPools/*.lua)

Shared text fragments organised by pool ID. Each pool file returns a table
with a unique `id` and an `entries` array. Entries contain text with `{token}`
placeholders, a numeric weight, and optional conditions.

Pool IDs follow a dot-separated naming convention:
`{category}.{context}.{section}` -- for example, `recon.common.situation`,
`recovery.medical.tasking`, `survey.common.submission`.

### 2.3 Voice Packs

Per-archetype text overrides. When a mission is sponsored by a specific agent
archetype, the briefing resolver substitutes specific section pools with
voice-pack pools. Voice packs only override the `situation` and `submission`
sections -- the factual sections (`title`, `tasking`, `constraints`) remain
neutral to preserve clarity.

Voice pack pools are stored alongside regular text pools in
`Definitions/TextPools/` with the naming convention `voice_{archetype}.lua`.

### 2.4 Context Tokens

Runtime values injected into text via `resolveTokens()`. The full token table
is built once per generation from world state:

| Token | Source | Example |
|-------|--------|---------|
| `{zoneName}` | Target zone display name | "Muldraugh" |
| `{targetName}` | Target building/room description | "the pharmacy on Knox Ave" |
| `{targetType}` | Room type human label | "pharmacy" |
| `{distanceBand}` | Approximate distance category | "nearby" / "moderate" / "distant" |
| `{rewardCash}` | Formatted reward amount | "$3,400" |
| `{deadlineDay}` | Expiry day number | "Day 14" |
| `{riskLevel}` | Difficulty label | "moderate" |
| `{sponsorName}` | Sponsor archetype display name | "Backroad Scavenger" |
| `{categoryLabel}` | Mission category label | "Recon" |
| `{playerLocation}` | Player's current zone name | "West Point" |
| `{itemName}` | Recovery target item display name | "first aid kit" |
| `{visitCount}` | Survey location count | "3" |

### 2.5 Briefing Sections

Briefings are composed from 5 ordered sections. Each section resolves
independently from its designated pool. The resolver iterates the section list
in order and assembles the final briefing as a keyed table of strings.

| Order | Section | Purpose | Required |
|-------|---------|---------|----------|
| 1 | `title` | One-line mission name for the operations list | Yes |
| 2 | `situation` | Context and background (voice-pack overridable) | Yes |
| 3 | `tasking` | What the player must do | Yes |
| 4 | `constraints` | Special conditions, hazards, time pressure | No (omitted for difficulty 1) |
| 5 | `submission` | How/where to turn in results (voice-pack overridable) | Yes |

Optional sections are omitted entirely (not rendered as empty) when conditions
are not met. The `constraints` section is suppressed for Tier I (easy) missions
to keep low-difficulty briefings concise.

---

## 3. Mission Schema (POS_MissionSchema.lua)

Full schema definition following the `PhobosLib_Schema` pattern established
by `POS_ArchetypeSchema.lua`, `POS_ZoneSchema.lua`, and `POS_EventSchema.lua`.

```lua
POS_MissionSchema = {
    schemaVersion = { type = "number", required = true },
    id            = { type = "string", required = true },
    name          = { type = "string", required = true },
    displayNameKey = { type = "string" },                -- i18n key override
    category      = { type = "string", required = true,
                      enum = { "recon", "recovery", "survey" } },
    enabled       = { type = "boolean", default = true },

    -- Difficulty and tier
    difficultyRange = {
        type = "table", required = true,
        fields = {
            min = { type = "number", min = 1, max = 4 },
            max = { type = "number", min = 1, max = 4 },
        },
    },

    -- Location targeting
    locationRules = {
        type = "table", required = true,
        fields = {
            roomTypes    = { type = "array", items = "string" },
            buildingTags = { type = "array", items = "string" },
            zones        = { type = "array", items = "string" },  -- zone IDs
        },
    },

    -- Briefing pool references (section name -> pool ID)
    briefing = {
        type = "table", required = true,
        fields = {
            title       = { type = "string", required = true },
            situation   = { type = "string", required = true },
            tasking     = { type = "string", required = true },
            constraints = { type = "string" },                    -- optional
            submission  = { type = "string", required = true },
        },
    },

    -- Text style hint (future: affects terminal rendering)
    textStyle = { type = "string", default = "standard",
                  enum = { "standard", "urgent", "classified" } },

    -- Objectives template
    objectives = {
        type = "array", required = true,
        items = {
            type = "table",
            fields = {
                type        = { type = "string", required = true },
                target      = { type = "string" },     -- item type or room
                count       = { type = "number" },      -- for multi-target
                description = { type = "string" },
            },
        },
    },

    -- Reward and reputation
    rewardRange = {
        type = "table", required = true,
        fields = {
            min = { type = "number", min = 0 },
            max = { type = "number", min = 0 },
        },
    },
    reputationRange = {
        type = "table",
        fields = {
            min = { type = "number", min = 0 },
            max = { type = "number", min = 0 },
        },
    },

    -- Expiry (game days)
    expiryRange = {
        type = "table",
        fields = {
            min = { type = "number", min = 1 },
            max = { type = "number", min = 1 },
        },
    },
}
```

**Nesting depth**: Maximum 2 levels (e.g. `locationRules.roomTypes`,
`rewardRange.min`), consistent with Section 26.2 of design-guidelines.md.

---

## 4. Text Pool Schema (POS_TextPoolSchema.lua)

```lua
POS_TextPoolSchema = {
    schemaVersion = { type = "number", required = true },
    id            = { type = "string", required = true },
    entries = {
        type = "array", required = true,
        items = {
            type = "table",
            fields = {
                id         = { type = "string", required = true },
                text       = { type = "string", required = true },
                weight     = { type = "number", min = 0.01, default = 1.0 },
                conditions = { type = "table" },  -- optional predicate table
            },
        },
    },
}
```

### 4.1 Condition Predicates

Conditions are flat tables evaluated by `PhobosLib.conditionsPass()`. They
gate entry selection based on runtime context without embedding logic in data.

Supported condition keys:

| Key | Type | Meaning |
|-----|------|---------|
| `minDifficulty` | number | Entry only eligible at this difficulty or above |
| `maxDifficulty` | number | Entry only eligible at this difficulty or below |
| `category` | string | Entry only eligible for this mission category |
| `zone` | string | Entry only eligible for this zone ID |
| `hasItem` | string | Player must have this item type in inventory |

Example:
```lua
{
    id = "situation_medical_urgent",
    text = "Medical supplies at {targetName} are critically low. {sponsorName} needs eyes on the ground before committing resources.",
    weight = 1.5,
    conditions = { minDifficulty = 3, category = "recon" },
}
```

---

## 5. Mission Archetypes

### 5.1 Recon

Scout a target location, verify conditions, photograph the site, write a
field report. This is a direct data-driven replacement of the current
`POS_ReconGenerator.TARGETS` hardcoded catalogue.

**Objective sequence**: travel to target building -> enter the target room ->
take a recon photograph -> write field notes -> submit report at terminal.

**Location**: Any cached building matching `roomTypes` or `buildingTags`
via `POS_BuildingCache.findByAnyRoom()`.

**Difficulty**: 1-4, tier-gated by player reputation (unchanged from current
recon system). Tier determines which definitions are eligible.

**Reward**: $1,500-$7,500, scaled by `POS_RewardCalculator.scaleReward()`.
Existing signal-strength scaling applies.

**Completion**: Multi-step via `POS_CompletionDetector` recon checker (enter
room -> photograph -> notes -> manual turn-in at terminal). The existing
recon completion flow is unchanged.

**Migration path**: The 16 hardcoded entries in `POS_ReconGenerator.TARGETS`
become 16 definition files in `Definitions/Missions/`. Each preserves its
original `id`, `tier`, `roomDefs`, `baseReward`, and `baseReputation`. The
generator reads from the registry instead of the hardcoded array.

### 5.2 Recovery

Locate and retrieve specific items from a target building. The player must
physically find and collect the item from world containers -- items are not
spawned or teleported.

**Objective sequence**: travel to target building -> enter the building ->
find and collect the target item(s) -> return to terminal with item in
inventory.

**Location**: Buildings with containers likely to hold the target item type.
Location rules use `roomTypes` and `buildingTags` to match appropriate
buildings (e.g. `pharmacy` for medical supplies, `warehouse` for electronics).

**Difficulty**: 1-3. Recovery missions cap at difficulty 3 because the
challenge is item scarcity, not combat exposure.

**Item categories**:
- Medical supplies: `Base.Bandage`, `Base.Pills`, `Base.FirstAidKit`
- Electronic components: `Base.ElectronicsScrap`, `Radio.ElectricWire`
- Documents: `Base.Book`, `Base.Newspaper`, `Base.Magazine`
- Radio parts: `Radio.RadioReceiver`, `Radio.RadioTransmitter`

**Reward**: $2,000-$5,000 + bonus scaled by item rarity. The reward range in
the definition provides the base; the bonus is calculated at generation time
from the target item's base value.

**Completion**: Via `POS_CompletionDetector` using the existing `item_acquire`
checker. The detector confirms the player has the target item type and count
in inventory, then the player submits at the terminal.

**Anti-pattern**: Recovery missions never spawn items. If the target item
does not exist in the world, the mission is legitimately harder. The player
may need to search multiple locations. This is intentional difficulty, not
a design flaw.

### 5.3 Survey

Investigate multiple rooms or buildings within a zone to assess overall
conditions. Broader scope than recon -- requires visiting several locations
and compiling a composite report.

**Objective sequence**: visit N locations (2-4) within the target zone ->
compile a composite field report at the final location -> submit at terminal.

**Location**: Zone-wide. The generator selects 2-4 buildings across the
target zone using `POS_BuildingCache`. Buildings are spread across different
`roomTypes` to ensure variety.

**Difficulty**: 2-4. Surveys are inherently more demanding than single-target
recon due to travel requirements and multi-location exposure.

**Reward**: $3,000-$8,000. Higher than single-target missions due to the
multiple-objective scope and increased travel risk.

**Unique trait**: Survey missions generate observation data that feeds into
the Living Market system (via `POS_MarketSimulation`). Each surveyed location
produces a supply/demand data point for its zone, enriching the autonomous
economic simulation. This creates a meaningful gameplay loop: surveys are
paid work that also improves the player's market intelligence.

**Completion**: A new `survey_visit` objective type registered with
`POS_CompletionDetector`. Each sub-location is tracked independently. The
detector checks player proximity to each target building. All locations
must be visited before the report can be compiled and submitted.

---

## 6. Generation Pipeline

Step-by-step process for creating a new mission from a definition:

### Step 1: Select Mission Definition

Filter the mission registry by:
- Player reputation tier (definition `difficultyRange` must overlap player's
  unlocked tiers)
- Zone availability (at least one building matching `locationRules` exists
  in `POS_BuildingCache`)
- Recently-used blacklist (definitions used in the last N generations are
  deprioritised via `avoidRecent`)
- Category filter (if a specific category is requested by the broadcast
  system or sandbox options disable a category)

### Step 2: Resolve World Context

- Select a target building from the cache matching `locationRules`
- Determine the zone from building coordinates
- Select a sponsor archetype (weighted random from active agents, or
  specific archetype if the mission is archetype-sponsored)
- Roll difficulty within the definition's `difficultyRange`
- Roll reward within `rewardRange`, then apply `POS_RewardCalculator.scaleReward()`
- Calculate expiry day from `expiryRange` + current game day

### Step 3: Build Context Token Table

Assemble all `{token}` values from the resolved world state into a flat
key-value table. See Section 2.4 for the full token list.

### Step 4: Resolve Briefing Sections

For each section in `MISSION_BRIEFING_SECTIONS`:

1. Look up the pool ID from the definition's `briefing` table
2. If the sponsor archetype has a voice pack that overrides this section,
   use the voice pack pool ID instead
3. Load the pool from the text pool registry
4. Filter entries by `conditionsPass(entry, context)`
5. Filter entries by `avoidRecent(eligibleEntries, history, maxSize)`
6. Select one entry via `pickWeighted(eligibleEntries, "weight")`
7. Resolve tokens via `resolveTokens(entry.text, tokenTable)`
8. Store the resolved text and the entry ID (for history tracking)

If a section's pool yields no eligible entries after filtering, fall back
to the category's common pool for that section. If that also fails, omit
the section (only valid for optional sections like `constraints`).

### Step 5: Apply Voice Pack Overrides

Voice pack substitution happens at Step 4.2 above, not as a separate pass.
The override is transparent to the rest of the pipeline -- the resolver
simply reads from a different pool ID.

### Step 6: Assemble Final Briefing

Build the briefing table:
```lua
briefing = {
    title       = "Pharmacy Assessment: Knox Avenue",
    situation   = "Word is the pharmacy on Knox Ave hasn't been touched...",
    tasking     = "Get inside, document remaining stock levels...",
    constraints = nil,  -- omitted for Tier I
    submission  = "File your report through the terminal when you're back.",
}
```

### Step 7: Store Text Metadata

Record which entry IDs were used in each section:
```lua
textMeta = {
    title       = "recon_pharmacy_title_01",
    situation   = "voice_trader_situation_03",
    tasking     = "recon_common_tasking_02",
    submission  = "voice_trader_submission_01",
}
```

This metadata serves two purposes:
- **Anti-repetition**: entry IDs feed the rolling history
- **Debug/save compatibility**: if a player reports an issue, the exact
  text selections are traceable

### Step 8: Create Operation Table

Build the final operation table with the persisted briefing:
```lua
local operation = {
    id          = "POS_RECON_" .. tostring(getTimestampMs()),
    templateId  = definition.id,
    category    = definition.category,
    tier        = rolledDifficulty,
    difficulty  = POS_Constants.DIFFICULTY_LEVELS[rolledDifficulty],
    status      = POS_Constants.STATUS_AVAILABLE,
    nameKey     = definition.displayNameKey,
    briefing    = briefing,     -- persisted section table
    textMeta    = textMeta,     -- entry IDs used
    objectives  = resolvedObjectives,
    baseReward  = rolledReward,
    scaledReward = scaledReward,
    baseReputation = rolledReputation,
    createdDay  = currentDay,
    expiryDay   = currentDay + rolledExpiry,
    sponsorArchetype = archetypeId,
}
```

The operation is then registered via `POS_OperationLog.addOperation(op)`.
From this point, the existing `POS_OperationService` lifecycle manages it
with no changes.

---

## 7. Anti-Repetition System

### 7.1 Rolling History

Each briefing section maintains a rolling history of the last N entry IDs
used. Before selecting an entry from a pool, the resolver calls
`PhobosLib.avoidRecent()` to filter out recently-used entries.

### 7.2 Storage

History is stored in player modData under a single key:
```lua
modData[POS_Constants.MISSION_TEXT_HISTORY_KEY] = {
    title       = { "entry_id_1", "entry_id_2", ... },
    situation   = { "entry_id_5", "entry_id_6", ... },
    tasking     = { ... },
    constraints = { ... },
    submission  = { ... },
}
```

### 7.3 Configuration

- Maximum history size per section: `MISSION_TEXT_HISTORY_MAX_SIZE` (10)
- History is trimmed to `maxSize` on each generation (oldest entries removed
  first)
- If filtering by history leaves zero eligible entries, history is ignored
  for that pick (graceful degradation, not failure)

### 7.4 Definition-Level Avoidance

In addition to text-level anti-repetition, the generator maintains a
separate rolling list of recently-used mission definition IDs. This prevents
the same mission template from appearing in consecutive generations even if
the text varies. This list is stored under a separate modData key
(`POS_MissionDefHistory`) with a maximum size of 5.

---

## 8. Voice Pack System

### 8.1 Structure

Voice packs are keyed by archetype ID. Each pack specifies override pool IDs
for the sections it customises:

```lua
-- Definitions/TextPools/voice_smuggler.lua
return {
    schemaVersion = 1,
    id = "voice_smuggler",
    entries = {
        {
            id = "smuggler_situation_01",
            text = "Got a line on something at {targetName}. Can't say more over the air. You interested or not?",
            weight = 1.0,
        },
        {
            id = "smuggler_situation_02",
            text = "There's a place -- {targetName} -- nobody's touched it yet. At least that's what I hear. Go take a look, quiet-like.",
            weight = 1.0,
        },
        -- ...
    },
}
```

### 8.2 Override Mapping

The `POS_VoicePackRegistry` maintains a mapping from archetype ID to section
overrides:

```lua
voicePacks = {
    smuggler = {
        situation  = "voice_smuggler",       -- pool ID
        submission = "voice_smuggler_close",  -- pool ID
    },
    military_logistician = {
        situation  = "voice_military",
        submission = "voice_military_close",
    },
    -- ...
}
```

Only sections listed in `MISSION_VOICE_PACK_SECTIONS` (`situation`,
`submission`) are eligible for voice pack override. The `title`, `tasking`,
and `constraints` sections always use the mission definition's default pools
to ensure factual clarity is never compromised by flavour text.

### 8.3 Tone Guide

Each archetype has a defined textual personality. Voice pack entries must
adhere to these tone guidelines:

| Archetype | Tone | Vocabulary | Example phrasing |
|-----------|------|------------|-------------------|
| `scavenger_trader` | Informal, opportunistic, street-level | Slang, casual contractions, deal-making language | "Got a tip on..." / "Easy money if you move fast" |
| `wholesaler` | Businesslike, measured, transactional | Commerce terms, cost-benefit framing | "Our assessment indicates..." / "Standard terms apply" |
| `military_logistician` | Formal, precise, procedural | Military jargon, acronyms, structured briefing format | "Tasking follows..." / "Report to terminal on completion" |
| `smuggler` | Cagey, indirect, coded language | Euphemisms, vague references, plausible deniability | "A friend of a friend..." / "Keep this between us" |
| `speculator` | Analytical, risk-aware, numbers-focused | Financial terminology, probability language | "Risk/reward ratio favours..." / "Market data suggests..." |
| `specialist_crafter` | Technical, detail-oriented, craft-focused | Material names, process descriptions, quality language | "The target site should contain..." / "Quality matters here" |
| `quartermaster` | Bureaucratic, by-the-book, supply-chain jargon | Forms, requisition numbers, procedure references | "Per standing order..." / "File under category..." |

---

## 9. Integration Points

The mission system connects to existing POSnet modules. All integration is
additive -- no existing module APIs change.

| Module | Integration | Direction |
|--------|-------------|-----------|
| `POS_BroadcastSystem` | Triggers mission generation on broadcast interval tick | Calls into generator |
| `POS_OperationService` | Lifecycle management (activate, complete, cancel, expire) | Unchanged -- missions are operations |
| `POS_NegotiationService` | Haggle mechanics for reward/deadline adjustment | Unchanged |
| `POS_RewardCalculator` | Reward scaling, signal-strength modifier, penalty calculation | Unchanged |
| `POS_CompletionDetector` | Extended with `recovery_retrieve` and `survey_visit` objective checkers | New checkers registered |
| `POS_MarketSimulation` | Survey missions produce zone observation data | Generator calls into simulation |
| `POS_BuildingCache` | Location source for all mission types | Read-only queries |
| `POS_MailboxScanner` | Delivery pickup/dropoff (deliveries remain a separate system) | No change |
| `POS_MapMarkers` | Place/remove markers for active mission targets | Unchanged |
| `POS_Reputation` | Tier gating for mission eligibility | Read-only queries |
| `POS_TutorialService` | New milestones for first recovery/survey missions | Milestone awards |
| `POS_ReconScanner` | Room-entry detection for recon objectives | Unchanged |

### 9.1 POS_ReconGenerator Migration

`POS_ReconGenerator` will be refactored in two stages:

1. **Phase 2**: The `TARGETS` array is replaced by registry lookups. The
   `generate()` function reads from the mission registry filtered by
   `category = "recon"`. The operation table structure is unchanged.

2. **Deprecation**: Once all recon definitions are migrated and tested, the
   hardcoded `TARGETS` array is removed. The `POS_ReconGenerator` module is
   retained as a thin wrapper that delegates to `POS_MissionBriefingResolver`
   for backwards compatibility with any addon mods referencing it.

---

## 10. File Structure

```
common/media/lua/shared/
    POS_MissionSchema.lua               -- Mission definition schema
    POS_TextPoolSchema.lua              -- Text pool schema
    POS_MissionBriefingResolver.lua     -- Text resolution engine
    POS_VoicePackRegistry.lua           -- Voice pack loader + mapping
    Definitions/
        Missions/
            _template.lua               -- Commented reference template
            recon_bathroom.lua
            recon_kitchen.lua
            recon_office.lua
            recon_livingroom.lua
            recon_pharmacy.lua
            recon_clinic.lua
            recon_grocery.lua
            recon_classroom.lua
            recon_police_station.lua
            recon_fire_station.lua
            recon_warehouse.lua
            recon_factory.lua
            recon_hospital.lua
            recon_prison.lua
            recon_mall.lua
            recon_military.lua
            recovery_medical.lua
            recovery_electronics.lua
            recovery_documents.lua
            recovery_radio_parts.lua
            survey_muldraugh.lua
            survey_west_point.lua
            survey_riverside.lua
        TextPools/
            _template.lua               -- Commented reference template
            recon_common.lua            -- Shared recon text (all sections)
            recon_medical.lua           -- Medical-context recon text
            recon_industrial.lua        -- Industrial-context recon text
            recon_security.lua          -- Security/military-context text
            recovery_common.lua         -- Shared recovery text
            recovery_medical.lua        -- Medical recovery specifics
            survey_common.lua           -- Shared survey text
            voice_military.lua          -- Military logistician voice
            voice_smuggler.lua          -- Smuggler voice
            voice_trader.lua            -- Scavenger trader voice
            voice_quartermaster.lua     -- Quartermaster voice
            voice_speculator.lua        -- Speculator voice
            voice_crafter.lua           -- Specialist crafter voice
            voice_wholesaler.lua        -- Wholesaler voice
```

All definition files follow the data-only Lua format: `return { ... }` with
no functions, no globals, and `schemaVersion = 1`. Templates include
`enabled = false` and full field documentation as per Section 26.6.

---

## 11. Constants

New constants in `POS_Constants.lua` (or `POS_Constants_Missions.lua` if
file size warrants a split):

```lua
---------------------------------------------------------------
-- Mission categories
---------------------------------------------------------------
POS_Constants.MISSION_CATEGORY_RECON    = "recon"
POS_Constants.MISSION_CATEGORY_RECOVERY = "recovery"
POS_Constants.MISSION_CATEGORY_SURVEY   = "survey"

---------------------------------------------------------------
-- Briefing section ordering
---------------------------------------------------------------
POS_Constants.MISSION_BRIEFING_SECTIONS = {
    "title", "situation", "tasking", "constraints", "submission",
}

---------------------------------------------------------------
-- Voice pack overridable sections
---------------------------------------------------------------
POS_Constants.MISSION_VOICE_PACK_SECTIONS = {
    "situation", "submission",
}

---------------------------------------------------------------
-- Anti-repetition (player modData keys)
---------------------------------------------------------------
POS_Constants.MISSION_TEXT_HISTORY_KEY     = "POS_MissionTextHistory"
POS_Constants.MISSION_TEXT_HISTORY_MAX_SIZE = 10
POS_Constants.MISSION_DEF_HISTORY_KEY      = "POS_MissionDefHistory"
POS_Constants.MISSION_DEF_HISTORY_MAX_SIZE = 5

---------------------------------------------------------------
-- New objective types
---------------------------------------------------------------
POS_Constants.OBJECTIVE_TYPE_RECOVER      = "recovery_retrieve"
POS_Constants.OBJECTIVE_TYPE_SURVEY_VISIT = "survey_visit"

---------------------------------------------------------------
-- Survey objective constants
---------------------------------------------------------------
POS_Constants.SURVEY_MIN_LOCATIONS = 2
POS_Constants.SURVEY_MAX_LOCATIONS = 4
POS_Constants.SURVEY_VISIT_RADIUS  = 80  -- tiles
```

---

## 12. Anti-Patterns

These are hard architectural constraints. Violating any of them is a design
error, not a deferral.

### 12.1 No NPC Dependencies

All missions must be completable via world-object interaction only: buildings,
containers, mailboxes, terminals, cameras, radios. No mission may require
interacting with an NPC character, NPC dialogue, or NPC-driven events.

**Rationale**: PZ Build 42 does not provide a stable NPC API. Designing
missions around NPCs would create a hard dependency on an unstable system
that could break with any PZ update. NPC support is excluded until the PZ
engine provides a stable, documented NPC interaction API. This is a hard
constraint, not a "nice to have later" deferral.

### 12.2 No Functions in Definitions

Text pools and mission definitions are declarative data. All logic stays in
the resolver (`POS_MissionBriefingResolver`) and the engine modules. Definition
files contain only `return { ... }` tables. Conditions are evaluated by the
engine from flat predicate tables, not by player-authored functions.

### 12.3 No Regeneration from Schema

Briefing text is persisted on generation. If the schema or text pools change
after a mission is created, the existing mission retains its original text.
This prevents mid-mission text changes, broken token references, and
save-game incompatibility.

### 12.4 No Monolithic Briefings

Briefings are always stored as section tables (keyed by section name), never
as a single concatenated string. This enables:
- Section-level rendering in the terminal UI
- Voice pack overrides on individual sections
- Per-section anti-repetition tracking
- Future section-level formatting (e.g. `textStyle = "classified"`)

### 12.5 No Infinite Item Sources

Recovery missions require items to physically exist in the world. The mission
system never spawns, duplicates, or teleports items. If a target item does not
exist in any reachable container, the mission is legitimately difficult. This
preserves PZ's scarcity-driven gameplay.

### 12.6 No Magic Teleportation

The player must physically travel to all objective locations. No mission
mechanic may bypass travel (e.g. "remote scan" or "drone recon"). Travel is
the core gameplay cost that makes missions meaningful.

---

## 13. Sandbox Options

All new sandbox options follow the naming and tooltip conventions from
design-guidelines.md Section 3.

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `POS.MissionGenerationInterval` | integer (minutes) | 30 | Time between automatic mission generation ticks |
| `POS.MissionMaxActive` | integer | 3 | Maximum concurrent active missions (excludes deliveries) |
| `POS.MissionRewardMultiplier` | integer (percentage) | 100 | Global reward scaling for all mission types |
| `POS.MissionExpiryMultiplier` | integer (percentage) | 100 | Global expiry time scaling (higher = more time) |
| `POS.EnableRecoveryMissions` | boolean | true | Enable/disable recovery mission category |
| `POS.EnableSurveyMissions` | boolean | true | Enable/disable survey mission category |

Recon missions have no separate enable toggle -- they are the baseline
mission type and are always available. The existing
`POS.EnableCancellationPenalty` and `POS.EnableNegotiation` sandbox options
continue to apply to all mission types.

---

## 14. Translation Key Conventions

All user-visible text uses translation keys via `getText()` or
`PhobosLib.safeGetText()`. Keys follow established POSnet conventions from
design-guidelines.md Section 4.

| Category | Pattern | Example |
|----------|---------|---------|
| Mission definition names | `UI_POS_Mission_{id}` | `UI_POS_Mission_recon_pharmacy` |
| Briefing section labels | `UI_POS_Briefing_{section}` | `UI_POS_Briefing_situation` |
| Objective step descriptions | `UI_POS_Objective_{type}_{step}` | `UI_POS_Objective_recon_enter` |
| Voice pack archetype labels | `UI_POS_Voice_{archetype}` | `UI_POS_Voice_smuggler` |
| Category display names | `UI_POS_Category_{category}` | `UI_POS_Category_recovery` |
| Error/status messages | `UI_POS_Mission_Error_{code}` | `UI_POS_Mission_Error_NoBuilding` |
| Sandbox option labels | `POS_MissionGenerationInterval` | (standard POS_ prefix) |
| Sandbox option tooltips | `POS_MissionGenerationInterval_tooltip` | (standard _tooltip suffix) |

Note: Briefing text itself is NOT stored as translation keys. It is generated
from text pools at runtime and persisted as final strings. The text pools
contain English text directly; future localisation of text pools would use
parallel pool files per language, not the translation key system.

---

## 15. Implementation Phases

### Phase 1: Schema + Resolver Engine

**Scope**: Create the foundational modules with no gameplay changes.

- `POS_MissionSchema.lua` -- schema definition, registered with PhobosLib
- `POS_TextPoolSchema.lua` -- text pool schema
- `POS_MissionBriefingResolver.lua` -- text resolution pipeline (resolve,
  pick, filter, assemble)
- `POS_VoicePackRegistry.lua` -- voice pack loader and override mapping
- `_template.lua` files for `Definitions/Missions/` and
  `Definitions/TextPools/`
- New constants in `POS_Constants.lua`
- Unit-testable in isolation (no world state required for resolver tests)

**Depends on**: PhobosLib v1.59.0 text compositor functions.

### Phase 2: Initial Definitions (Recon)

**Scope**: Replace the hardcoded recon catalogue with data-driven definitions.

- Create 16 recon mission definition files (one per existing target)
- Create 4-5 shared text pools (`recon_common`, `recon_medical`,
  `recon_industrial`, `recon_security`)
- Refactor `POS_ReconGenerator.generate()` to read from the mission registry
- Verify all existing recon gameplay is preserved (same tiers, same rewards,
  same buildings, same completion flow)
- Remove `POS_ReconGenerator.TARGETS` hardcoded array

**Migration risk**: Low. The operation table structure is unchanged. Only the
source of target data moves from a hardcoded array to a registry.

### Phase 3: Recovery Missions

**Scope**: Add the recovery mission type as the first new category.

- Create 4-6 recovery mission definitions (medical, electronics, documents,
  radio parts)
- Create `recovery_common` and `recovery_medical` text pools
- Register `recovery_retrieve` objective type checker with
  `POS_CompletionDetector`
- Extend `POS_Screen_Operations` to display recovery missions and handle
  item-based turn-in
- Add `POS.EnableRecoveryMissions` sandbox option

### Phase 4: Survey Missions

**Scope**: Add multi-location survey missions with market integration.

- Create 3-4 survey mission definitions (zone-scoped)
- Create `survey_common` text pool
- Register `survey_visit` objective type checker with
  `POS_CompletionDetector`
- Implement multi-objective tracking in the terminal UI (progress per
  location)
- Wire survey completion data into `POS_MarketSimulation` zone observations
- Add `POS.EnableSurveyMissions` sandbox option

### Phase 5: Voice Packs

**Scope**: Add archetype-specific textual personality to briefings.

- Create 7 voice pack text pools (one per archetype)
- Populate `POS_VoicePackRegistry` with override mappings
- Create 3-4 entries per voice pack per overridable section (minimum viable
  variety)
- Test with each archetype as sponsor to verify tone consistency

### Phase 6: Polish

**Scope**: Tuning, balancing, and completeness.

- Anti-repetition tuning (adjust history sizes based on pool sizes)
- Difficulty/reward balance pass across all three categories
- Reward calibration relative to existing recon and delivery payouts
- Translation completeness (all keys present in EN translation files)
- Text pool variety expansion (target 8-10 entries per pool minimum)
- Terminal UI refinements for briefing section rendering
