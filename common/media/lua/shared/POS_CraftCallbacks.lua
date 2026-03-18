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
-- POS_CraftCallbacks.lua
-- OnCreate callbacks for POSnet crafting recipes.
--
-- CraftFieldReport: transfers operation ID from photograph to
-- field report, and applies small damage to writing implement.
---------------------------------------------------------------

require "PhobosLib"

POS_CraftCallbacks = POS_CraftCallbacks or {}

--- Writing implement full type names for damage targeting.
local WRITING_IMPLEMENTS = {
    ["Base.Pen"] = true,
    ["Base.Pencil"] = true,
    ["Base.RedPen"] = true,
    ["Base.BluePen"] = true,
    ["Base.GreenPen"] = true,
    ["Base.PenMultiColor"] = true,
    ["Base.PenFancy"] = true,
    ["Base.PenSpiffo"] = true,
    ["Base.PencilSpiffo"] = true,
}

--- OnCreate callback for the CraftFieldReport recipe.
--- Transfers the operation ID from the consumed ReconPhotograph
--- to the created FieldReport, and damages the writing implement.
---@param items table Input items (B42: may be table or ArrayList)
---@param result any The created FieldReport item
---@param player any IsoPlayer
function POS_CraftCallbacks.onCreateFieldReport(items, result, player)
    if not result or not player then return end

    -- Transfer operation ID from photograph modData to report
    local operationId = nil
    PhobosLib.iterateItems(items, function(item)
        if item and item:getFullType() == "PhobosOperationalSignals.ReconPhotograph" then
            local md = item:getModData()
            if md and md.POS_OperationId then
                operationId = md.POS_OperationId
            end
        end
    end)

    if operationId then
        local md = result:getModData()
        if md then
            md.POS_OperationId = operationId
        end
        PhobosLib.debug("POS", "[CraftCallback] Field report created for operation: " .. operationId)
    end

    -- Damage writing implement
    local chancePct = POS_Sandbox and POS_Sandbox.getWritingDamageChance
        and POS_Sandbox.getWritingDamageChance() or 20
    local damageAmt = POS_Sandbox and POS_Sandbox.getWritingDamageAmount
        and POS_Sandbox.getWritingDamageAmount() or 7

    local inv = player:getInventory()
    if inv then
        PhobosLib.iterateItems(items, function(item)
            if item then
                local fullType = item:getFullType()
                if WRITING_IMPLEMENTS[fullType] then
                    local damaged = PhobosLib.damageItemCondition(
                        item, math.max(1, damageAmt - 2), damageAmt + 2, chancePct)
                    if damaged then
                        PhobosLib.debug("POS", "[CraftCallback] Writing implement damaged: " .. fullType)
                    end
                end
            end
        end)
    end

    -- Mark operation objective as having notes written
    if operationId and POS_OperationLog then
        local op = POS_OperationLog.get(operationId)
        if op and op.objectives and op.objectives[1] then
            op.objectives[1].notesWritten = true
        end
    end
end
