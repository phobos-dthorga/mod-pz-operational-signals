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
-- Definitions/Speculation/default_speculation.lua
-- Default speculative rumour templates for the entropy system.
-- Generated when certainty drops below ENTROPY_SPECULATION_THRESHOLD.
-- Addon mods can register additional templates via the
-- POS_SpeculationRegistry.
--
-- See entropy-system-design.md §4.2 and design-guidelines.md §59.
---------------------------------------------------------------

return {
    {
        schemaVersion = 1,
        id = "spec_shortage",
        impactHint = "shortage",
        weight = 40,
        confidenceMin = 0.15,
        confidenceMax = 0.35,
        descriptionKey = "UI_POS_Rumour_Speculative_Shortage",
    },
    {
        schemaVersion = 1,
        id = "spec_surplus",
        impactHint = "surplus",
        weight = 30,
        confidenceMin = 0.10,
        confidenceMax = 0.30,
        descriptionKey = "UI_POS_Rumour_Speculative_Surplus",
    },
    {
        schemaVersion = 1,
        id = "spec_disruption",
        impactHint = "disruption",
        weight = 30,
        confidenceMin = 0.10,
        confidenceMax = 0.25,
        descriptionKey = "UI_POS_Rumour_Speculative_Disruption",
    },
}
