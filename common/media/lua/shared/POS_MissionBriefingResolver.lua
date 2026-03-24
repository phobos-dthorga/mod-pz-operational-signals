--  ________________________________________________________________________
-- / Copyright (c) 2026 Phobos A. D'thorga                                \
-- |                                                                        |
-- |           /\_/\                                                         |
-- |         =/ o o \=    Phobos' PZ Modding                                |
-- |          (  V  )     All rights reserved.                              |
-- |     /\  / \   / \                                                      |
-- |    /  \/   '-'   \   This source code is part of the Phobos            |
-- |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
-- |  (__/    \_/ \/  \__)                                                  |
-- |     |   | |  | |     Unauthorised copying, modification, or            |
-- |     |___|_|  |_|     distribution of this file is prohibited.          |
-- |                                                                        |
-- \________________________________________________________________________/
--

---------------------------------------------------------------
-- POS_MissionBriefingResolver.lua
-- Compositional briefing generator for data-driven missions.
--
-- 8-step pipeline per briefing section (title, situation,
-- tasking, constraints, submission):
--   1. Look up pool ID from definition (or voice pack override)
--   2. Load pool entries from registry
--   3. Filter by PhobosLib.conditionsPass(entry, context)
--   4. Filter by PhobosLib.avoidRecent(entryId, history)
--   5. Select via PhobosLib.pickWeighted(entries)
--   6. Resolve tokens via PhobosLib.resolveTokens(text, ctx)
--   7. Store result + entry ID in history
--   8. Return briefing table + textMeta
--
-- Uses PhobosLib text compositor utilities (§31 in design docs).
-- See design-guidelines.md §32.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MissionBriefingResolver = {}

local _TAG = "[POS:BriefingResolver]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _textPoolRegistry
local _history = {}  -- rolling history of used entry IDs (anti-repetition)
local _initialised = false

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

--- Load text pool definitions into registry.
--- Called lazily on first resolve.
function POS_MissionBriefingResolver.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_TextPoolSchema")
    _textPoolRegistry = PhobosLib.createRegistry({
        name           = "TextPools",
        schema         = schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    -- Load built-in text pool definitions
    local paths = {
        "Definitions/TextPools/titles_common",
        "Definitions/TextPools/situations_common",
        "Definitions/TextPools/taskings_common",
        "Definitions/TextPools/constraints_common",
        "Definitions/TextPools/submissions_common",
    }

    -- Load voice packs (all 8 archetypes)
    local voicePaths = {
        "Definitions/TextPools/voice_scavenger",
        "Definitions/TextPools/voice_quartermaster",
        "Definitions/TextPools/voice_wholesaler",
        "Definitions/TextPools/voice_smuggler",
        "Definitions/TextPools/voice_military",
        "Definitions/TextPools/voice_trader",
        "Definitions/TextPools/voice_speculator",
        "Definitions/TextPools/voice_crafter",
    }

    for _, path in ipairs(paths) do
        local ok, data = pcall(require, path)
        if ok and type(data) == "table" then
            _textPoolRegistry:register(data)
        else
            PhobosLib.warn("POS", _TAG, "Failed to load text pool: " .. tostring(path))
        end
    end

    for _, path in ipairs(voicePaths) do
        local ok, data = pcall(require, path)
        if ok and type(data) == "table" then
            _textPoolRegistry:register(data)
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. tostring(_textPoolRegistry:count()) .. " text pool(s)")

    -- Register built-in voice packs
    if POS_VoicePackRegistry and POS_VoicePackRegistry.initBuiltIn then
        POS_VoicePackRegistry.initBuiltIn()
    end
end

---------------------------------------------------------------
-- Pool lookup
---------------------------------------------------------------

--- Get entries from a text pool by ID.
--- @param poolId string Text pool ID
--- @return table Array of entries, or empty table
local function getPoolEntries(poolId)
    if not _textPoolRegistry then return {} end
    local pool = _textPoolRegistry:get(poolId)
    if not pool or not pool.entries then return {} end
    return pool.entries
end

---------------------------------------------------------------
-- Section resolution (8-step pipeline)
---------------------------------------------------------------

--- Resolve a single briefing section.
--- @param sectionName string One of MISSION_BRIEFING_SECTIONS
--- @param definition table Mission definition
--- @param context table Token resolution context
--- @param archetypeId string|nil Sponsor archetype for voice pack override
--- @return string|nil Resolved text, or nil if pool is empty
--- @return string|nil Entry ID used (for history tracking)
local function resolveSection(sectionName, definition, context, archetypeId)
    -- Step 1: Determine pool ID (voice pack override → definition → common fallback)
    local poolId = nil

    -- Check voice pack override for this section
    if archetypeId and POS_VoicePackRegistry
            and POS_VoicePackRegistry.getOverride then
        poolId = POS_VoicePackRegistry.getOverride(archetypeId, sectionName)
    end

    -- Fall back to definition's briefingPools
    if not poolId and definition.briefingPools then
        poolId = definition.briefingPools[sectionName]
    end

    -- Fall back to common pool
    if not poolId then
        poolId = sectionName .. "s_common"
    end

    -- Step 2: Load pool entries
    local entries = getPoolEntries(poolId)
    if #entries == 0 then
        PhobosLib.debug("POS", _TAG,
            "Empty pool for section '" .. sectionName .. "' (pool: " .. tostring(poolId) .. ")")
        return nil, nil
    end

    -- Step 3: Filter by conditions
    local filtered = {}
    for _, entry in ipairs(entries) do
        if PhobosLib.conditionsPass(entry, context) then
            filtered[#filtered + 1] = entry
        end
    end

    if #filtered == 0 then
        -- Fall back to unfiltered if conditions eliminated everything
        filtered = entries
    end

    -- Step 4: Filter by anti-repetition history
    local nonRecent = {}
    for _, entry in ipairs(filtered) do
        if not PhobosLib.avoidRecent(entry.id, _history,
                POS_Constants.MISSION_HISTORY_MAX_SIZE) then
            nonRecent[#nonRecent + 1] = entry
        end
    end

    -- Fall back to all filtered if anti-repetition eliminated everything
    if #nonRecent == 0 then
        nonRecent = filtered
    end

    -- Step 5: Weighted random selection
    local selected = PhobosLib.pickWeighted(nonRecent, context)
    if not selected then
        -- Last resort: pick any entry
        selected = nonRecent[ZombRand(#nonRecent) + 1]
    end

    if not selected then return nil, nil end

    -- Step 6: Resolve tokens
    local resolvedText = PhobosLib.resolveTokens(selected.text or "", context)

    -- Step 7: Store in history
    if selected.id then
        table.insert(_history, selected.id)
        while #_history > POS_Constants.MISSION_HISTORY_MAX_SIZE do
            table.remove(_history, 1)
        end
    end

    return resolvedText, selected.id
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Resolve a full mission briefing from a definition + context.
--- Returns a table of resolved text for each section.
---
--- @param definition table Mission definition (from registry)
--- @param context table Token context: { zoneName, targetName, rewardCash, ... }
--- @param archetypeId string|nil Sponsor archetype ID for voice overrides
--- @return table briefing  Map of sectionName → resolved text string
--- @return table textMeta  Map of sectionName → entry ID used
function POS_MissionBriefingResolver.resolveBriefing(definition, context, archetypeId)
    POS_MissionBriefingResolver.init()

    if not definition then return {}, {} end

    local briefing = {}
    local textMeta = {}

    for _, section in ipairs(POS_Constants.MISSION_BRIEFING_SECTIONS) do
        -- Skip constraints for low-difficulty missions (difficulty 1)
        local skipConstraints = (section == "constraints")
            and context and context.difficulty
            and context.difficulty <= POS_Constants.MISSION_MIN_DIFFICULTY

        if not skipConstraints then
            local text, entryId = resolveSection(section, definition, context, archetypeId)
            briefing[section] = text or ""
            textMeta[section] = entryId
        else
            briefing[section] = ""
            textMeta[section] = nil
        end
    end

    PhobosLib.debug("POS", _TAG, "Resolved briefing for definition: " .. tostring(definition.id))
    return briefing, textMeta
end

--- Get the text pool registry (for addon mod extensions).
--- @return table|nil Registry instance
function POS_MissionBriefingResolver.getTextPoolRegistry()
    POS_MissionBriefingResolver.init()
    return _textPoolRegistry
end
