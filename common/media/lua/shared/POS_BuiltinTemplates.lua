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
-- POS_BuiltinTemplates.lua
-- Built-in mission templates for POSnet.
--
-- Registers starter templates for end-to-end testing.
-- External mods can register additional templates via
-- POS_MissionTemplates.register().
---------------------------------------------------------------

local CAT = POS_MissionTemplates.CATEGORY
local DIFF = POS_MissionTemplates.DIFFICULTY

---------------------------------------------------------------
-- Industrial Recovery: Acquire a Screwdriver
---------------------------------------------------------------
POS_MissionTemplates.register({
    id = "pos_ir_acquire_screwdriver",
    category = CAT.INDUSTRIAL_RECOVERY,
    difficulty = DIFF.EASY,
    objectives = {
        {
            type = "item_acquire",
            description = "Acquire a screwdriver",
            target = "Base.Screwdriver",
            count = 1,
        },
    },
})

---------------------------------------------------------------
-- Industrial Recovery: Acquire Nails
---------------------------------------------------------------
POS_MissionTemplates.register({
    id = "pos_ir_acquire_nails",
    category = CAT.INDUSTRIAL_RECOVERY,
    difficulty = DIFF.EASY,
    objectives = {
        {
            type = "item_acquire",
            description = "Acquire a box of nails",
            target = "Base.Nails",
            count = 1,
        },
    },
})

---------------------------------------------------------------
-- Vehicle Salvage: Acquire a Wrench
---------------------------------------------------------------
POS_MissionTemplates.register({
    id = "pos_vs_acquire_wrench",
    category = CAT.VEHICLE_SALVAGE,
    difficulty = DIFF.EASY,
    objectives = {
        {
            type = "item_acquire",
            description = "Acquire a wrench",
            target = "Base.Wrench",
            count = 1,
        },
    },
})

---------------------------------------------------------------
-- Survivor Assistance: Acquire First Aid Kit
---------------------------------------------------------------
POS_MissionTemplates.register({
    id = "pos_sa_acquire_firstaid",
    category = CAT.SURVIVOR_ASSISTANCE,
    difficulty = DIFF.MEDIUM,
    objectives = {
        {
            type = "item_acquire",
            description = "Acquire a first aid kit",
            target = "Base.FirstAidKit",
            count = 1,
        },
    },
})

---------------------------------------------------------------
-- Scientific Research: Acquire a Notebook
---------------------------------------------------------------
POS_MissionTemplates.register({
    id = "pos_sr_acquire_notebook",
    category = CAT.SCIENTIFIC_RESEARCH,
    difficulty = DIFF.EASY,
    objectives = {
        {
            type = "item_acquire",
            description = "Acquire a notebook",
            target = "Base.Notebook",
            count = 1,
        },
    },
})
