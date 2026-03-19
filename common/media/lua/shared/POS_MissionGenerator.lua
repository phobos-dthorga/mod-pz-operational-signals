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
-- Procedural mission creation from registered templates.
--
-- Selects a random template, resolves location parameters,
-- scales difficulty based on game day, and produces an
-- operation data table ready for the Operation Log.
---------------------------------------------------------------

require "PhobosLib"

POS_MissionGenerator = {}

--- Generate a new operation from available templates.
--- @param player IsoPlayer The player receiving the operation
--- @return table|nil Operation data table, or nil if generation failed
function POS_MissionGenerator.generate(player)
    if not player then return nil end

    local templates = POS_MissionTemplates.getAll()
    local candidates = {}
    for _, tmpl in pairs(templates) do
        table.insert(candidates, tmpl)
    end

    if #candidates == 0 then
        PhobosLib.debug("POS", "No mission templates registered — cannot generate.")
        return nil
    end

    -- Weighted random selection (placeholder — equal weight for now)
    local selected = candidates[ZombRand(#candidates) + 1]
    if not selected then return nil end

    local gameTime = getGameTime()
    local day = gameTime and gameTime:getNightsSurvived() or 0

    local operation = {
        id = "POS_" .. tostring(getTimestampMs()),
        templateId = selected.id,
        category = selected.category,
        difficulty = selected.difficulty,
        objectives = {},
        status = POS_Constants.STATUS_ACTIVE,
        createdDay = day,
        expiryDay = day + POS_Sandbox.getOperationExpiryDays(),
    }

    -- Clone objectives from template
    if selected.objectives then
        for i = 1, #selected.objectives do
            local obj = selected.objectives[i]
            table.insert(operation.objectives, {
                type = obj.type,
                description = obj.description,
                target = obj.target,
                completed = false,
            })
        end
    end

    PhobosLib.debug("POS", "Generated operation: " .. operation.id
        .. " [" .. (operation.category or "?") .. "]")

    return operation
end
