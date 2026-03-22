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
-- POS_CameraService.lua
-- Business logic for Camera Workstation (Tier III — Compilation).
-- Input validation, confidence calculation, artifact generation,
-- cooldown management, reputation grants.
-- All game-state mutations happen here — context menu delegates.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_SIGINTSkill"
require "POS_SIGINTService"

POS_CameraService = {}

---------------------------------------------------------------
-- Camera Workstation Detection
---------------------------------------------------------------

--- Check if a world object is a camera workstation.
---@param worldObj IsoObject
---@return boolean
function POS_CameraService.isCameraWorkstation(worldObj)
    if not worldObj then return false end
    local sprites = POS_Constants.CAMERA_WORKSTATION_SPRITES
    if not sprites or #sprites == 0 then return false end

    local ok, spriteName = PhobosLib.safecall(function()
        local sprite = worldObj:getSprite()
        return sprite and sprite:getName()
    end)
    if not ok or not spriteName then return false end

    for _, name in ipairs(sprites) do
        if spriteName == name then return true end
    end
    return false
end

--- Check if the player is in a media building (TV studio, broadcast, AV room).
---@param player IsoPlayer
---@return boolean
function POS_CameraService.isInMediaBuilding(player)
    if not player then return false end
    local roomName = PhobosLib.getPlayerRoomName(player)
    if not roomName then return false end
    local lower = string.lower(roomName)

    for _, mediaType in ipairs(POS_Constants.CAMERA_MEDIA_ROOM_TYPES) do
        if lower:find(mediaType) then return true end
    end
    return false
end

---------------------------------------------------------------
-- Input Validation
---------------------------------------------------------------

--- Find items suitable for the "Compile Site Survey" action.
--- Requires 1-3 same-category notes/intel fragments.
---@param player IsoPlayer
---@return table Array of items with POS_RawIntel or POS_CameraInput tags
function POS_CameraService.findCompileInputs(player)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end

    local rawItems = PhobosLib.findItemsByTag(inv, POS_Constants.TAG_RAW_INTEL)
    local cameraItems = PhobosLib.findItemsByTag(inv, POS_Constants.TAG_CAMERA_INPUT)

    local result = {}
    for _, item in ipairs(rawItems) do result[#result + 1] = item end
    for _, item in ipairs(cameraItems) do result[#result + 1] = item end
    return result
end

--- Find items suitable for "Review Recorded Tape" action.
--- Requires 1 VHS or microcassette.
---@param player IsoPlayer
---@return table Array of suitable media items
function POS_CameraService.findTapeInputs(player)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end

    -- Check for VHS tapes and microcassettes with recorded data
    local results = {}
    local tapeTypes = { "Base.VideoTape", "PhobosOperationalSignals.MicrocassetteTape" }
    for _, fullType in ipairs(tapeTypes) do
        local item = inv:getFirstTypeRecurse(fullType)
        if item then
            local md = PhobosLib.getModData(item)
            if md and (md.POS_EntryCount or md.POS_RecordedEntries) then
                results[#results + 1] = item
            end
        end
    end
    return results
end

--- Find items suitable for "Produce Market Bulletin" action.
--- Requires 2-5 any-category notes/fragments + blank VHS + paper.
---@param player IsoPlayer
---@return table Array of intel items
function POS_CameraService.findBulletinInputs(player)
    return POS_CameraService.findCompileInputs(player)
end

---------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------

--- Get the cooldown key for a camera action at the player's building.
---@param player IsoPlayer
---@param actionType string Action type constant
---@return string|nil
function POS_CameraService.getCooldownKey(player, actionType)
    if not player then return nil end
    local sq = player:getSquare()
    if not sq then return nil end
    local building = sq:getBuilding()
    if not building then return nil end

    local bx, by = 0, 0
    PhobosLib.safecall(function()
        local def = building:getDef()
        if def then
            bx = def:getX()
            by = def:getY()
        end
    end)

    return POS_Constants.CAMERA_VISIT_KEY_PREFIX
        .. tostring(bx) .. "_" .. tostring(by) .. "_" .. actionType
end

--- Check if a camera action is on cooldown.
---@param player IsoPlayer
---@param actionType string
---@return boolean onCooldown, number hoursLeft
function POS_CameraService.isOnCooldown(player, actionType)
    local key = POS_CameraService.getCooldownKey(player, actionType)
    if not key then return false, 0 end

    local modData = player:getModData()
    local lastUseHour = modData[key] or -9999
    local currentHour = getGameTime():getWorldAgeHours()

    local cooldownHours
    if actionType == POS_Constants.CAMERA_COMPILE_ACTION then
        cooldownHours = POS_Sandbox and POS_Sandbox.getCameraCompileCooldown
            and POS_Sandbox.getCameraCompileCooldown()
            or POS_Constants.CAMERA_COMPILE_COOLDOWN_DEFAULT
    elseif actionType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        cooldownHours = POS_Sandbox and POS_Sandbox.getCameraTapeCooldown
            and POS_Sandbox.getCameraTapeCooldown()
            or POS_Constants.CAMERA_TAPE_COOLDOWN_DEFAULT
    else
        cooldownHours = POS_Sandbox and POS_Sandbox.getCameraBulletinCooldown
            and POS_Sandbox.getCameraBulletinCooldown()
            or POS_Constants.CAMERA_BULLETIN_COOLDOWN_DEFAULT
    end

    local hoursSince = currentHour - lastUseHour
    if hoursSince < cooldownHours then
        return true, math.ceil(cooldownHours - hoursSince)
    end
    return false, 0
end

--- Record a cooldown timestamp.
---@param player IsoPlayer
---@param actionType string
function POS_CameraService.recordCooldown(player, actionType)
    local key = POS_CameraService.getCooldownKey(player, actionType)
    if not key then return end
    player:getModData()[key] = getGameTime():getWorldAgeHours()
end

---------------------------------------------------------------
-- Confidence Calculation
---------------------------------------------------------------

--- Calculate confidence for a compiled artifact.
---@param player IsoPlayer
---@param inputs table Array of input items
---@param actionType string
---@return number Confidence value (0-99)
function POS_CameraService.calculateConfidence(player, inputs, actionType)
    if not inputs or #inputs == 0 then return 0 end

    -- Average input confidence
    local totalConf = 0
    for _, item in ipairs(inputs) do
        local md = PhobosLib.getModData(item)
        totalConf = totalConf + (md and tonumber(md.POS_Confidence) or 20)
    end
    local avgConf = totalConf / #inputs

    -- Quality multiplier by action type
    local multiplier
    local cap
    if actionType == POS_Constants.CAMERA_COMPILE_ACTION then
        multiplier = POS_Constants.CAMERA_SURVEY_MULTIPLIER
        cap = POS_Constants.CAMERA_SURVEY_CONFIDENCE_CAP
    elseif actionType == POS_Constants.CAMERA_TAPE_REVIEW_ACTION then
        multiplier = POS_Constants.CAMERA_REPORT_MULTIPLIER
        cap = POS_Constants.CAMERA_REPORT_CONFIDENCE_CAP
    else
        multiplier = POS_Constants.CAMERA_BULLETIN_MULTIPLIER
        cap = POS_Constants.CAMERA_BULLETIN_CONFIDENCE_CAP
    end

    local confidence = avgConf * multiplier

    -- Location bonus (media building)
    if POS_CameraService.isInMediaBuilding(player) then
        confidence = confidence + POS_Constants.CAMERA_LOCATION_BONUS
    end

    -- Diversity bonuses (unique locations from inputs)
    local locations = {}
    local categories = {}
    for _, item in ipairs(inputs) do
        local md = PhobosLib.getModData(item)
        if md then
            if md.POS_Location then locations[md.POS_Location] = true end
            if md.POS_Category then categories[md.POS_Category] = true end
        end
    end

    local locCount = 0
    for _ in pairs(locations) do locCount = locCount + 1 end
    confidence = confidence + math.min(
        locCount * POS_Constants.CAMERA_DIVERSITY_BONUS_PER_LOC,
        POS_Constants.CAMERA_DIVERSITY_BONUS_CAP
    )

    -- Category bonus (bulletin only)
    if actionType == POS_Constants.CAMERA_BULLETIN_ACTION then
        local catCount = 0
        for _ in pairs(categories) do catCount = catCount + 1 end
        confidence = confidence + math.min(
            catCount * POS_Constants.CAMERA_CATEGORY_BONUS_PER_CAT,
            POS_Constants.CAMERA_CATEGORY_BONUS_CAP
        )
    end

    -- Camera input bonus (from Intel Fragments tagged POS_CameraInput)
    local cameraInputCount = 0
    for _, item in ipairs(inputs) do
        local ok, hasTag = PhobosLib.safecall(function()
            return item:hasTag(POS_Constants.TAG_CAMERA_INPUT)
        end)
        if ok and hasTag then
            cameraInputCount = cameraInputCount + 1
        end
    end
    confidence = confidence + (cameraInputCount * POS_Constants.CAMERA_EQUIPMENT_BONUS)

    -- SIGINT confidence bonus
    confidence = confidence + POS_SIGINTService.getConfidenceBonus(player)

    -- SIGINT verification strength (secondary: +1% per level, max +10%)
    local verification = POS_SIGINTService.getVerificationStrength(player)
    confidence = confidence * (1.0 + verification)

    -- Clamp to cap
    return math.min(math.floor(confidence), cap)
end

---------------------------------------------------------------
-- Living Market Zone Pressure Enrichment (Phase 7D)
---------------------------------------------------------------

--- Attach Living Market zone pressure summary to an artifact's modData.
--- Only runs when the Living Market is enabled. Adds POS_ZonePressure
--- key containing a table of zoneId → pressure data.
---@param artifact InventoryItem
local function enrichWithZonePressure(artifact)
    if not artifact then return end
    if not POS_Sandbox or not POS_Sandbox.isLivingMarketEnabled() then return end

    local ok, POS_MarketSimulation = PhobosLib.safecall(require, "POS_MarketSimulation")
    if not ok or not POS_MarketSimulation or not POS_MarketSimulation.getZoneState then return end

    local zones = POS_Constants.MARKET_ZONES or {}
    local pressureData = {}
    local count = 0
    for _, zoneId in ipairs(zones) do
        local state = POS_MarketSimulation.getZoneState(zoneId)
        if state and state.pressure then
            pressureData[zoneId] = state.pressure
            count = count + 1
        end
    end

    if count > 0 then
        local md = PhobosLib.getModData(artifact)
        if md then
            md.POS_ZonePressure = pressureData
        end
        PhobosLib.debug("POS", "[POS:Camera]",
            "Zone pressure data attached to artifact (" .. count .. " zones)")
    end
end

---------------------------------------------------------------
-- Core Processing
---------------------------------------------------------------

--- Process a compile site survey action.
---@param player IsoPlayer
---@param inputs table 1-3 same-category notes
---@return table|nil Artifact item, or nil on failure
function POS_CameraService.compileSiteSurvey(player, inputs)
    if not player or not inputs or #inputs == 0 then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local confidence = POS_CameraService.calculateConfidence(
        player, inputs, POS_Constants.CAMERA_COMPILE_ACTION)

    -- Consume inputs
    for _, item in ipairs(inputs) do
        if inv:contains(item) then inv:Remove(item) end
    end

    -- Consume paper
    for _, ft in ipairs(POS_Constants.PAPER_TYPES) do
        local paper = inv:getFirstTypeRecurse(ft)
        if paper then inv:Remove(paper); break end
    end

    -- Create output
    local artifact = inv:AddItem(POS_Constants.ITEM_COMPILED_SITE_SURVEY)
    if artifact then
        local md = artifact:getModData()
        if md then
            md.POS_Confidence = confidence
            md.POS_SourceCount = #inputs
            md.POS_CompileDay = getGameTime():getNightsSurvived()
            md.POS_SIGINTLevel = POS_SIGINTSkill.getLevel(player)
            md.POS_ArtifactType = POS_Constants.CAMERA_COMPILE_ACTION

            -- Inherit primary category from first input
            local firstMd = PhobosLib.getModData(inputs[1])
            if firstMd and firstMd.POS_Category then
                md.POS_Category = firstMd.POS_Category
            end
        end

        if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
            POS_NoteTooltip.applyToNote(artifact)
        end

        -- Phase 7D: attach Living Market zone pressure data
        enrichWithZonePressure(artifact)
    end

    -- Award XP
    POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_CAMERA_SURVEY)

    -- Record cooldown
    POS_CameraService.recordCooldown(player, POS_Constants.CAMERA_COMPILE_ACTION)

    return artifact
end

--- Process a tape review action.
---@param player IsoPlayer
---@param tape InventoryItem VHS or microcassette
---@return table|nil Artifact item, or nil on failure
function POS_CameraService.reviewRecordedTape(player, tape)
    if not player or not tape then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local confidence = POS_CameraService.calculateConfidence(
        player, { tape }, POS_Constants.CAMERA_TAPE_REVIEW_ACTION)

    -- Do NOT consume tape (reviewed, not destroyed)
    -- Consume paper + pen
    for _, ft in ipairs(POS_Constants.PAPER_TYPES) do
        local paper = inv:getFirstTypeRecurse(ft)
        if paper then inv:Remove(paper); break end
    end

    -- Create output
    local artifact = inv:AddItem(POS_Constants.ITEM_VERIFIED_INTEL_REPORT)
    if artifact then
        local md = artifact:getModData()
        if md then
            md.POS_Confidence = confidence
            md.POS_SourceCount = 1
            md.POS_CompileDay = getGameTime():getNightsSurvived()
            md.POS_SIGINTLevel = POS_SIGINTSkill.getLevel(player)
            md.POS_ArtifactType = POS_Constants.CAMERA_TAPE_REVIEW_ACTION

            local tapeMd = PhobosLib.getModData(tape)
            if tapeMd and tapeMd.POS_Region then
                md.POS_Category = tapeMd.POS_Region
            end
        end

        if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
            POS_NoteTooltip.applyToNote(artifact)
        end

        -- Phase 7D: attach Living Market zone pressure data
        enrichWithZonePressure(artifact)
    end

    -- Award XP
    POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_CAMERA_TAPE_REVIEW)

    -- Record cooldown
    POS_CameraService.recordCooldown(player, POS_Constants.CAMERA_TAPE_REVIEW_ACTION)

    return artifact
end

--- Process a produce market bulletin action.
---@param player IsoPlayer
---@param inputs table 2-5 any-category notes
---@return table|nil Artifact item, or nil on failure
function POS_CameraService.produceMarketBulletin(player, inputs)
    if not player or not inputs or #inputs < 2 then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local confidence = POS_CameraService.calculateConfidence(
        player, inputs, POS_Constants.CAMERA_BULLETIN_ACTION)

    -- Consume inputs
    for _, item in ipairs(inputs) do
        if inv:contains(item) then inv:Remove(item) end
    end

    -- Consume paper + blank VHS
    for _, ft in ipairs(POS_Constants.PAPER_TYPES) do
        local paper = inv:getFirstTypeRecurse(ft)
        if paper then inv:Remove(paper); break end
    end
    local blankVhs = inv:getFirstTypeRecurse("Base.VideoTape")
    if blankVhs then inv:Remove(blankVhs) end

    -- Create output
    local artifact = inv:AddItem(POS_Constants.ITEM_MARKET_BULLETIN)
    if artifact then
        local md = artifact:getModData()
        if md then
            md.POS_Confidence = confidence
            md.POS_SourceCount = #inputs
            md.POS_CompileDay = getGameTime():getNightsSurvived()
            md.POS_SIGINTLevel = POS_SIGINTSkill.getLevel(player)
            md.POS_ArtifactType = POS_Constants.CAMERA_BULLETIN_ACTION
            md.POS_Category = "mixed"
        end

        if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
            POS_NoteTooltip.applyToNote(artifact)
        end

        -- Phase 7D: attach Living Market zone pressure data
        enrichWithZonePressure(artifact)
    end

    -- Award XP
    POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_CAMERA_BULLETIN)

    -- Grant reputation
    if PhobosLib.addPlayerReputation then
        local repAmount = POS_Sandbox and POS_Sandbox.getCameraBulletinRep
            and POS_Sandbox.getCameraBulletinRep()
            or POS_Constants.CAMERA_BULLETIN_REP_DEFAULT
        PhobosLib.addPlayerReputation(player, "POS", repAmount)
    end

    -- Record cooldown
    POS_CameraService.recordCooldown(player, POS_Constants.CAMERA_BULLETIN_ACTION)

    return artifact
end
