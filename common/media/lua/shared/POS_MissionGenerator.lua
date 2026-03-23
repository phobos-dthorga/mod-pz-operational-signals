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
-- POS_MissionGenerator.lua
-- Data-driven mission creation using the Mission Briefing
-- Resolver (§32 compositor pipeline).
--
-- Selects a mission definition from the registry, resolves
-- world context (zone, target, sponsor archetype), builds a
-- token context table, and delegates to the briefing resolver
-- for compositional text generation.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_MissionGenerator = {}

local _TAG = "[POS:MissionGen]"

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

local _missionRegistry
local _initialised = false

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

local BUILTIN_PATHS = {
    "Definitions/Missions/recon_basic",
    "Definitions/Missions/recon_targeted",
    "Definitions/Missions/delivery_standard",
    "Definitions/Missions/trade_procurement",
    "Definitions/Missions/signal_intercept",
}

function POS_MissionGenerator.init()
    if _initialised then return end
    _initialised = true

    local schema = require("POS_MissionSchema")
    _missionRegistry = PhobosLib.createRegistry({
        name           = "Missions",
        schema         = schema,
        idField        = "id",
        allowOverwrite = true,
        tag            = _TAG,
    })

    for _, path in ipairs(BUILTIN_PATHS) do
        local ok, data = pcall(require, path)
        if ok and type(data) == "table" then
            _missionRegistry:register(data)
        else
            PhobosLib.warn("POS", _TAG, "Failed to load mission definition: " .. tostring(path))
        end
    end

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. tostring(_missionRegistry:count()) .. " mission definition(s)")
end

---------------------------------------------------------------
-- Context building
---------------------------------------------------------------

--- Build the token context table for briefing resolution.
--- @param player IsoPlayer
--- @param definition table Mission definition
--- @param difficulty number Resolved difficulty
--- @param zoneId string|nil
--- @param archetypeId string|nil
--- @return table Context tokens for PhobosLib.resolveTokens
local function buildContext(player, definition, difficulty, zoneId, archetypeId)
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local expiryMin = definition.expiryDaysMin or 3
    local expiryMax = definition.expiryDaysMax or 7
    local expiryDays = expiryMin + ZombRand(expiryMax - expiryMin + 1)
    local rewardMin = definition.rewardMin or 50
    local rewardMax = definition.rewardMax or 200
    local rewardCash = rewardMin + ZombRand(rewardMax - rewardMin + 1)

    -- Resolve zone name from registry
    local zoneName = zoneId or "unknown"
    if POS_MarketSimulation and POS_MarketSimulation.getZoneLuxuryDemand then
        -- Zone exists in registry; get display name
        local zoneData = PhobosLib.getWorldModDataTable("POSNET", "MarketZones")
        if zoneData and zoneData[zoneId] then
            zoneName = zoneData[zoneId].name or zoneId
        end
    end

    -- Pick a sponsor name from archetype
    local sponsorName = archetypeId or "POSnet Operations"

    -- Generate an operation code
    local opCode = tostring(ZombRand(1000, 9999))

    -- Pick a band name
    local bandName = (ZombRand(2) == 0) and "amateur" or "tactical"

    -- Pick a category from the commodity market
    local categories = POS_MarketRegistry and POS_MarketRegistry.getAllCategories
        and POS_MarketRegistry.getAllCategories() or {}
    local categoryName = definition.category or "general"
    if #categories > 0 then
        local cat = categories[ZombRand(#categories) + 1]
        if cat and cat.id then categoryName = cat.id end
    end

    return {
        zoneName       = zoneName,
        category       = categoryName,
        difficulty     = difficulty,
        targetName     = "target site",   -- placeholder — future: resolve from building cache
        rewardCash     = rewardCash,
        deadlineDay    = day + expiryDays,
        sponsorName    = sponsorName,
        playerName     = player and player:getDisplayName() or "Operator",
        operationCode  = opCode,
        bandName       = bandName,
        objectiveCount = definition.objectives and #definition.objectives or 1,
        _expiryDays    = expiryDays,
        _rewardCash    = rewardCash,
    }
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Generate a new operation using the compositor pipeline.
--- @param player IsoPlayer The player receiving the operation
--- @param targetDifficulty number|nil Desired difficulty (1-5, nil = auto)
--- @param targetCategory string|nil Desired category (nil = any)
--- @param archetypeId string|nil Sponsor archetype for voice pack
--- @return table|nil Operation data table, or nil if generation failed
function POS_MissionGenerator.generate(player, targetDifficulty, targetCategory, archetypeId)
    POS_MissionGenerator.init()

    if not player then return nil end
    if not _missionRegistry then return nil end

    -- Select a mission definition
    local all = _missionRegistry:getAll()
    local candidates = {}
    for _, def in ipairs(all) do
        if def.enabled ~= false then
            -- Filter by difficulty range
            local diff = targetDifficulty or (POS_Constants.MISSION_MIN_DIFFICULTY
                + ZombRand(POS_Constants.MISSION_MAX_DIFFICULTY - POS_Constants.MISSION_MIN_DIFFICULTY + 1))
            if diff >= (def.difficultyMin or 1) and diff <= (def.difficultyMax or 5) then
                -- Filter by category if specified
                if not targetCategory or def.category == targetCategory then
                    candidates[#candidates + 1] = { def = def, difficulty = diff }
                end
            end
        end
    end

    if #candidates == 0 then
        PhobosLib.debug("POS", _TAG, "No matching mission definitions for difficulty/category")
        return nil
    end

    -- Random selection from candidates
    local pick = candidates[ZombRand(#candidates) + 1]
    local definition = pick.def
    local difficulty = pick.difficulty

    -- Resolve zone (random from Living Market zones, or fallback)
    local zoneId = nil
    if POS_Constants.MARKET_ZONES then
        local zones = POS_Constants.MARKET_ZONES
        if #zones > 0 then
            zoneId = zones[ZombRand(#zones) + 1]
        end
    end

    -- Build token context
    local context = buildContext(player, definition, difficulty, zoneId, archetypeId)

    -- Resolve compositional briefing
    local briefing, textMeta = {}, {}
    if POS_MissionBriefingResolver and POS_MissionBriefingResolver.resolveBriefing then
        briefing, textMeta = POS_MissionBriefingResolver.resolveBriefing(
            definition, context, archetypeId)
    end

    -- Build operation data
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local operation = {
        id           = "POS_" .. tostring(getTimestampMs()) .. "_" .. tostring(ZombRand(10000)),
        definitionId = definition.id,
        category     = definition.category,
        difficulty   = difficulty,
        status       = POS_Constants.STATUS_ACTIVE,
        createdDay   = day,
        expiryDay    = context.deadlineDay,
        rewardCash   = context._rewardCash,
        zoneId       = zoneId,
        archetypeId  = archetypeId,
        briefing     = briefing,
        textMeta     = textMeta,
        objectives   = {},
    }

    -- Clone objectives from definition with token resolution
    if definition.objectives then
        for i = 1, #definition.objectives do
            local obj = definition.objectives[i]
            operation.objectives[i] = {
                type        = obj.type,
                description = PhobosLib.resolveTokens(obj.description or "", context),
                completed   = false,
            }
        end
    end

    PhobosLib.debug("POS", _TAG, "Generated operation: " .. operation.id
        .. " [" .. tostring(operation.category) .. ", diff=" .. tostring(difficulty) .. "]")

    -- Emit event
    if POS_Events and POS_Events.OnMissionGenerated then
        POS_Events.OnMissionGenerated:trigger({
            missionId  = operation.id,
            category   = operation.category,
            difficulty = difficulty,
        })
    end

    return operation
end

--- Get the mission definition registry (for addon extensions).
--- @return table|nil Registry instance
function POS_MissionGenerator.getRegistry()
    POS_MissionGenerator.init()
    return _missionRegistry
end
