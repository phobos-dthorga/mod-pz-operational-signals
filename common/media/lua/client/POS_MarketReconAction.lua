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
-- POS_MarketReconAction.lua
-- Timed action for field market note-taking.
-- Uses ISBaseTimedAction pattern — consumes paper, damages
-- writing tool, generates a Raw Market Note with procedural data.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_RoomCategoryMap"
require "POS_Reputation"
require "POS_NoteTooltip"
require "POS_MarketNoteGenerator"
require "POS_SIGINTSkill"
require "POS_SIGINTService"
require "TimedActions/ISBaseTimedAction"

POS_MarketReconAction = ISBaseTimedAction:derive("POS_MarketReconAction")

--- Build a visit key scoped to the entire room zone (building + room name).
--- Shared between context menu (cooldown check) and action (cooldown recording).
---@param sq IsoGridSquare
---@return string|nil visitKey, or nil if not in a valid room
function POS_MarketReconAction.getVisitKey(sq)
    if not sq then return nil end
    local building = sq:getBuilding()
    if not building then return nil end
    local room = sq:getRoom()
    if not room then return nil end

    -- Building def coordinates give a stable per-building identity
    local bx, by = 0, 0
    pcall(function()
        local def = building:getDef()
        if def then
            bx = def:getX()
            by = def:getY()
        end
    end)

    local roomDef = room:getRoomDef()
    local roomName = (roomDef and roomDef:getName()) or "unknown"
    return POS_Constants.INTEL_VISIT_KEY_PREFIX
        .. tostring(bx) .. "_" .. tostring(by) .. "_" .. roomName
end

--- Find a writing tool in inventory.
local function findWritingTool(player)
    local inv = player:getInventory()
    for _, fullType in ipairs(POS_Constants.WRITING_TOOLS) do
        local item = inv:getFirstTypeRecurse(fullType)
        if item then return item end
    end
    return nil
end

--- Find paper in inventory.
local function findPaper(player)
    local inv = player:getInventory()
    for _, fullType in ipairs(POS_Constants.PAPER_TYPES) do
        local item = inv:getFirstTypeRecurse(fullType)
        if item then return item end
    end
    return nil
end

function POS_MarketReconAction:new(player, categoryId, location)
    local o = ISBaseTimedAction.new(self, player)
    o.categoryId = categoryId
    o.location = location or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    o.paper = nil
    o.writingTool = nil

    -- Check for repeat visit discount
    local actionTime = POS_Sandbox and POS_Sandbox.getMarketNoteActionTime
        and POS_Sandbox.getMarketNoteActionTime()
        or POS_Constants.MARKET_NOTE_ACTION_TIME
    -- TODO: check modData for repeat visit and apply discount
    o.maxTime = actionTime

    return o
end

function POS_MarketReconAction:isValid()
    return self.character and not self.character:isDead()
        and findWritingTool(self.character) ~= nil
        and findPaper(self.character) ~= nil
end

function POS_MarketReconAction:start()
    -- Lock items
    self.paper = findPaper(self.character)
    self.writingTool = findWritingTool(self.character)

    -- Play writing animation
    self:setActionAnim("Write")
    self:setOverrideHandModels(nil, nil)
end

function POS_MarketReconAction:update()
    -- Character mumbles periodically
    if self.character and ZombRand(POS_Constants.CHARACTER_MUMBLE_CHANCE) == 0 then
        self.character:Say(PhobosLib.safeGetText("UI_POS_Market_Mumble"))
    end
end

function POS_MarketReconAction:stop()
    ISBaseTimedAction.stop(self)
end

function POS_MarketReconAction:perform()
    local player = self.character
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end

    -- Consume paper
    if self.paper and inv:contains(self.paper) then
        inv:Remove(self.paper)
    end

    -- Damage writing tool
    if self.writingTool then
        local dmgChance = POS_Sandbox and POS_Sandbox.getWritingDamageChance
            and POS_Sandbox.getWritingDamageChance()
            or POS_Constants.WRITING_DAMAGE_CHANCE_DEFAULT
        local dmgAmount = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
            and POS_Sandbox.getWritingDamageAmount()
            or POS_Constants.WRITING_DAMAGE_AMOUNT_DEFAULT
        PhobosLib.damageItemCondition(self.writingTool,
            math.max(1, dmgAmount - POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET),
            dmgAmount + POS_Constants.WRITING_DAMAGE_VARIANCE_OFFSET,
            dmgChance)
    end

    -- Determine confidence from reputation
    local confidence = POS_Constants.CONFIDENCE_LOW
    if POS_Reputation and POS_Reputation.getTier then
        local tier = POS_Reputation.getTier(player)
        if tier >= POS_Constants.CONFIDENCE_TIER_HIGH then
            confidence = POS_Constants.CONFIDENCE_HIGH
        elseif tier >= POS_Constants.CONFIDENCE_TIER_MEDIUM then
            confidence = POS_Constants.CONFIDENCE_MEDIUM
        end
    end

    -- Apply SIGINT field confidence bonus (+1 per 3 levels, max +3)
    if POS_SIGINTService and POS_SIGINTService.getFieldConfidenceBonus then
        confidence = confidence + POS_SIGINTService.getFieldConfidenceBonus(player)
    end

    -- Create Raw Market Note
    local note = inv:AddItem(POS_Constants.ITEM_RAW_MARKET_NOTE)
    if note then
        local ctx = { sourceTier = POS_Constants.SOURCE_TIER_FIELD }

        -- Populate modData via shared generator
        POS_MarketNoteGenerator.populateNoteModData(
            note, self.categoryId, self.location, confidence, ctx)

        -- Record visit timestamp for cooldown (scoped to room zone)
        local sq = player:getSquare()
        if sq then
            local visitKey = POS_MarketReconAction.getVisitKey(sq)
            if visitKey then
                player:getModData()[visitKey] = getGameTime():getNightsSurvived()
            end
        end

        -- Apply dynamic tooltip
        if POS_NoteTooltip and POS_NoteTooltip.applyToNote then
            POS_NoteTooltip.applyToNote(note)
        end

        -- Create readable document
        POS_MarketNoteGenerator.createReadableDocument(
            note, self.categoryId, self.location, confidence)
    end

    -- Award SIGINT XP for manual note-taking (tertiary source)
    if POS_SIGINTSkill and POS_SIGINTSkill.isAvailable
        and POS_SIGINTSkill.isAvailable() then
        POS_SIGINTSkill.addXP(player, POS_Constants.SIGINT_XP_MANUAL_NOTE)
    end

    PhobosLib.debug("POS", "[POS:ReconAction]",
        "Market note created for category: " .. self.categoryId)

    ISBaseTimedAction.perform(self)
end
