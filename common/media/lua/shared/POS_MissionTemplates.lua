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
-- POS_MissionTemplates.lua
-- Mission category definitions and objective template registry.
--
-- Each template defines:
--   id          — unique string identifier
--   category    — one of the 5 mission categories
--   difficulty  — "easy", "medium", "hard", "critical"
--   objectives  — array of objective definitions
--   broadcast   — radio message template (getText keys)
--
-- External mods can register additional templates via
-- POS_MissionTemplates.register(template).
---------------------------------------------------------------

POS_MissionTemplates = {}

--- Mission categories
POS_MissionTemplates.CATEGORY = {
    INDUSTRIAL_RECOVERY    = "IndustrialRecovery",
    VEHICLE_SALVAGE        = "VehicleSalvage",
    SCIENTIFIC_RESEARCH    = "ScientificResearch",
    SURVIVOR_ASSISTANCE    = "SurvivorAssistance",
    INFRASTRUCTURE_REPAIR  = "InfrastructureRepair",
}

--- Difficulty levels
POS_MissionTemplates.DIFFICULTY = {
    EASY     = "easy",
    MEDIUM   = "medium",
    HARD     = "hard",
    CRITICAL = "critical",
}

--- Internal template registry
local registry = {}

--- Register a mission template.
--- @param template table Mission template definition
function POS_MissionTemplates.register(template)
    if not template or not template.id then return end
    registry[template.id] = template
end

--- Get all registered templates.
--- @return table Map of id → template
function POS_MissionTemplates.getAll()
    return registry
end

--- Get templates filtered by category.
--- @param category string One of POS_MissionTemplates.CATEGORY values
--- @return table Array of matching templates
function POS_MissionTemplates.getByCategory(category)
    local results = {}
    for _, tmpl in pairs(registry) do
        if tmpl.category == category then
            table.insert(results, tmpl)
        end
    end
    return results
end

--- Get a template by ID.
--- @param id string Template identifier
--- @return table|nil Template or nil if not found
function POS_MissionTemplates.get(id)
    return registry[id]
end
