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
-- POS_ReconGenerator.lua
-- Generates recon missions from the 4-tier target catalogue.
--
-- Each target type maps to one or more PZ RoomDef names.
-- At generation time, the system finds a matching building
-- from the player-discovered cache and creates an operation
-- with a "recon" objective.
---------------------------------------------------------------

require "PhobosLib"
require "POS_BuildingCache"
require "POS_Reputation"
require "POS_RewardCalculator"

POS_ReconGenerator = POS_ReconGenerator or {}

--- Maximum attempts to find a target type with a cached building.
local MAX_TARGET_ATTEMPTS = 10

---------------------------------------------------------------
-- Target catalogue — 16 recon targets across 4 tiers
---------------------------------------------------------------

POS_ReconGenerator.TARGETS = {
    -- Tier I — Low Risk Recon
    {
        id = "pos_recon_bathroom",
        tier = 1,
        nameKey = "UI_POS_Recon_Bathroom",
        descKey = "UI_POS_Recon_Bathroom_Desc",
        roomDefs = { "bathroom" },
        baseReward = 1500,
        baseReputation = 40,
    },
    {
        id = "pos_recon_kitchen",
        tier = 1,
        nameKey = "UI_POS_Recon_Kitchen",
        descKey = "UI_POS_Recon_Kitchen_Desc",
        roomDefs = { "kitchen" },
        baseReward = 1750,
        baseReputation = 45,
    },
    {
        id = "pos_recon_office",
        tier = 1,
        nameKey = "UI_POS_Recon_Office",
        descKey = "UI_POS_Recon_Office_Desc",
        roomDefs = { "office" },
        baseReward = 2000,
        baseReputation = 50,
    },
    {
        id = "pos_recon_livingroom",
        tier = 1,
        nameKey = "UI_POS_Recon_LivingRoom",
        descKey = "UI_POS_Recon_LivingRoom_Desc",
        roomDefs = { "livingroom" },
        baseReward = 2100,
        baseReputation = 55,
    },

    -- Tier II — Moderate Risk Recon
    {
        id = "pos_recon_pharmacy",
        tier = 2,
        nameKey = "UI_POS_Recon_Pharmacy",
        descKey = "UI_POS_Recon_Pharmacy_Desc",
        roomDefs = { "pharmacy" },
        baseReward = 3000,
        baseReputation = 90,
    },
    {
        id = "pos_recon_clinic",
        tier = 2,
        nameKey = "UI_POS_Recon_Clinic",
        descKey = "UI_POS_Recon_Clinic_Desc",
        roomDefs = { "medical" },
        baseReward = 3200,
        baseReputation = 100,
    },
    {
        id = "pos_recon_grocery",
        tier = 2,
        nameKey = "UI_POS_Recon_Grocery",
        descKey = "UI_POS_Recon_Grocery_Desc",
        roomDefs = { "grocerystorage", "store" },
        baseReward = 3400,
        baseReputation = 110,
    },
    {
        id = "pos_recon_classroom",
        tier = 2,
        nameKey = "UI_POS_Recon_Classroom",
        descKey = "UI_POS_Recon_Classroom_Desc",
        roomDefs = { "classroom" },
        baseReward = 3100,
        baseReputation = 95,
    },

    -- Tier III — Elevated Risk Recon
    {
        id = "pos_recon_policestation",
        tier = 3,
        nameKey = "UI_POS_Recon_PoliceStation",
        descKey = "UI_POS_Recon_PoliceStation_Desc",
        roomDefs = { "policestation", "security" },
        baseReward = 4000,
        baseReputation = 140,
    },
    {
        id = "pos_recon_firestation",
        tier = 3,
        nameKey = "UI_POS_Recon_FireStation",
        descKey = "UI_POS_Recon_FireStation_Desc",
        roomDefs = { "firestation" },
        baseReward = 4200,
        baseReputation = 150,
    },
    {
        id = "pos_recon_warehouse",
        tier = 3,
        nameKey = "UI_POS_Recon_Warehouse",
        descKey = "UI_POS_Recon_Warehouse_Desc",
        roomDefs = { "warehouse", "storage" },
        baseReward = 4500,
        baseReputation = 170,
    },
    {
        id = "pos_recon_factory",
        tier = 3,
        nameKey = "UI_POS_Recon_Factory",
        descKey = "UI_POS_Recon_Factory_Desc",
        roomDefs = { "factory", "industrial" },
        baseReward = 4700,
        baseReputation = 180,
    },

    -- Tier IV — High Risk Recon
    {
        id = "pos_recon_hospital",
        tier = 4,
        nameKey = "UI_POS_Recon_Hospital",
        descKey = "UI_POS_Recon_Hospital_Desc",
        roomDefs = { "hospitalroom", "medical" },
        baseReward = 6000,
        baseReputation = 260,
    },
    {
        id = "pos_recon_prison",
        tier = 4,
        nameKey = "UI_POS_Recon_Prison",
        descKey = "UI_POS_Recon_Prison_Desc",
        roomDefs = { "prisoncell", "security" },
        baseReward = 6500,
        baseReputation = 300,
    },
    {
        id = "pos_recon_mall",
        tier = 4,
        nameKey = "UI_POS_Recon_Mall",
        descKey = "UI_POS_Recon_Mall_Desc",
        roomDefs = { "mall", "store" },
        baseReward = 6800,
        baseReputation = 320,
    },
    {
        id = "pos_recon_military",
        tier = 4,
        nameKey = "UI_POS_Recon_Military",
        descKey = "UI_POS_Recon_Military_Desc",
        roomDefs = { "military", "security" },
        baseReward = 7500,
        baseReputation = 350,
    },
}

---------------------------------------------------------------
-- Generation
---------------------------------------------------------------

--- Get target types available for the player's current tier.
---@param player any IsoPlayer
---@return table Array of target definitions
function POS_ReconGenerator.getAvailableTargets(player)
    local maxTier = POS_Reputation.getMaxMissionTier(player)
    local results = {}
    for _, target in ipairs(POS_ReconGenerator.TARGETS) do
        if target.tier <= maxTier then
            table.insert(results, target)
        end
    end
    return results
end

--- Generate a recon operation for a player.
--- Picks a random target type the player qualifies for, then
--- finds a matching building from the discovery cache.
---@param player any IsoPlayer
---@return table|nil Operation table, or nil if no valid target/building
function POS_ReconGenerator.generate(player)
    if not player then return nil end

    local targets = POS_ReconGenerator.getAvailableTargets(player)
    if #targets == 0 then return nil end

    -- Shuffle and try each target type until we find a cached building
    for _ = 1, math.min(MAX_TARGET_ATTEMPTS, #targets) do
        local target = targets[ZombRand(#targets) + 1]

        local buildings = POS_BuildingCache.findByAnyRoom(target.roomDefs)
        if #buildings > 0 then
            local building = buildings[ZombRand(#buildings) + 1]

            local gameTime = getGameTime()
            local currentDay = gameTime and gameTime:getNightsSurvived() or 0
            local expiryDays = POS_Sandbox and POS_Sandbox.getOperationExpiryDays
                and POS_Sandbox.getOperationExpiryDays() or 7

            local scaledReward = POS_RewardCalculator.scaleReward(target.baseReward)

            local operation = {
                id = "POS_RECON_" .. tostring(getTimestampMs()),
                templateId = target.id,
                category = "Recon",
                tier = target.tier,
                difficulty = ({ "easy", "medium", "hard", "critical" })[target.tier] or "easy",
                status = "available",
                nameKey = target.nameKey,
                descKey = target.descKey,
                objectives = {
                    {
                        type = POS_Constants.MISSION_TYPE_RECON,
                        targetRoomDefs = target.roomDefs,
                        targetBuildingX = building.x,
                        targetBuildingY = building.y,
                        description = target.nameKey,
                        entered = false,
                        completed = false,
                    },
                },
                baseReward = target.baseReward,
                scaledReward = scaledReward,
                baseReputation = target.baseReputation,
                createdDay = currentDay,
                expiryDay = currentDay + expiryDays,
            }

            PhobosLib.debug("POS", "[ReconGen] Generated: "
                .. target.id .. " at "
                .. math.floor(building.x) .. ", " .. math.floor(building.y)
                .. " (tier " .. target.tier .. ", $" .. scaledReward .. ")")

            return operation
        end
    end

    PhobosLib.debug("POS", "[ReconGen] No matching buildings in cache")
    return nil
end
