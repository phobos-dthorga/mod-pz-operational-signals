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
-- POS_ZScienceIntegration.lua
-- Optional cross-mod integration with ZScienceSkill.
-- Mirrors SIGINT XP to ZScience at configured ratio,
-- and produces ZScience specimens at high SIGINT levels.
-- All functionality gated by getActivatedMods():contains().
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_ZScienceIntegration = {}

local _TAG = "[POS:ZScience]"

---------------------------------------------------------------
-- Detection
---------------------------------------------------------------

--- Check if ZScienceSkill mod is active.
---@return boolean
function POS_ZScienceIntegration.isAvailable()
    local ok, result = pcall(function()
        return getActivatedMods():contains("ZScienceSkill")
    end)
    return ok and result == true
end

---------------------------------------------------------------
-- XP Mirror
---------------------------------------------------------------

--- Mirror SIGINT XP to ZScience skill.
--- Called from POS_SIGINTSkill.addXP() after SIGINT XP is awarded.
---@param player IsoPlayer
---@param sigintXP number Amount of SIGINT XP just awarded
function POS_ZScienceIntegration.mirrorXP(player, sigintXP)
    if not POS_ZScienceIntegration.isAvailable() then return end
    if not player or not sigintXP or sigintXP <= 0 then return end

    local ratio = POS_Constants.SIGINT_ZSCIENCE_MIRROR_RATIO
    local mirrorAmount = math.floor(sigintXP * ratio)
    if mirrorAmount <= 0 then return end

    -- Use PhobosLib XP mirror if available
    if PhobosLib.registerXPMirror then
        -- One-time registration (idempotent)
        PhobosLib.registerXPMirror(
            POS_Constants.SIGINT_PERK_ID,
            "Science",
            ratio
        )
        -- PhobosLib handles mirroring automatically after registration
        return
    end

    -- Manual fallback: directly add ZScience XP
    pcall(function()
        if PhobosLib.addXP then
            PhobosLib.addXP(player, "Science", mirrorAmount)
        end
    end)
end

---------------------------------------------------------------
-- Specimen Generation
---------------------------------------------------------------

-- Specimen types producible at high SIGINT levels
local SIGINT_SPECIMENS = {
    { level = 6, item = "ZScienceSkill.SpecimenElectronic",  chance = 15 },
    { level = 8, item = "ZScienceSkill.SpecimenDocumentary", chance = 20 },
    { level = 10, item = "ZScienceSkill.SpecimenSignal",     chance = 25 },
}

--- Roll for a ZScience specimen output from intelligence processing.
--- Called after terminal analysis or satellite broadcast.
---@param player IsoPlayer
---@param sigintLevel number Current SIGINT level
---@return boolean produced Whether a specimen was produced
function POS_ZScienceIntegration.rollSpecimen(player, sigintLevel)
    if not POS_ZScienceIntegration.isAvailable() then return false end
    if not player or not sigintLevel then return false end

    local inv = player:getInventory()
    if not inv then return false end

    for _, spec in ipairs(SIGINT_SPECIMENS) do
        if sigintLevel >= spec.level then
            if ZombRand(100) < spec.chance then
                local ok = pcall(function()
                    inv:AddItem(spec.item)
                end)
                if ok then
                    PhobosLib.debug("POS", _TAG,
                        "Specimen produced: " .. spec.item)
                    return true
                end
            end
        end
    end

    return false
end

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

--- Register XP mirror on game start (one-time setup).
function POS_ZScienceIntegration.init()
    if not POS_ZScienceIntegration.isAvailable() then
        PhobosLib.debug("POS", _TAG, "ZScienceSkill not active — skipping integration")
        return
    end

    if PhobosLib.registerXPMirror then
        PhobosLib.registerXPMirror(
            POS_Constants.SIGINT_PERK_ID,
            "Science",
            POS_Constants.SIGINT_ZSCIENCE_MIRROR_RATIO
        )
        PhobosLib.debug("POS", _TAG,
            "XP mirror registered (ratio: " ..
            tostring(POS_Constants.SIGINT_ZSCIENCE_MIRROR_RATIO) .. ")")
    end
end

Events.OnGameStart.Add(POS_ZScienceIntegration.init)
