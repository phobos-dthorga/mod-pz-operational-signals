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

--[[
    PhobosOperationalSignals — Registry Declarations
    =================================================
    Build 42.13+ requires all custom identifiers to be registered here
    BEFORE scripts and Lua files load.  This file is loaded by the engine
    automatically from  media/registries.lua  and runs before everything else.

    See: https://pzwiki.net/wiki/Registries
]]

-- SIGINT Character Traits (6 total: 3 positive, 3 negative)
CharacterTrait.register("pos:POS_AnalyticalMind")
CharacterTrait.register("pos:POS_RadioHobbyist")
CharacterTrait.register("pos:POS_SystemsThinker")
CharacterTrait.register("pos:POS_Impatient")
CharacterTrait.register("pos:POS_DisorganisedThinker")
CharacterTrait.register("pos:POS_SignalBlindness")

-- Item Tags (intelligence hierarchy)
ItemTag.register("pos:POS_RawIntel")
ItemTag.register("pos:POS_IntelFragment")
ItemTag.register("pos:POS_CameraInput")
ItemTag.register("pos:POS_Intelligence")
