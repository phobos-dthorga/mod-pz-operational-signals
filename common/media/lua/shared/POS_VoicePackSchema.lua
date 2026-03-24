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
-- Schema for voice pack definition files.
-- Each voice pack maps a market agent archetype to text pool
-- overrides for specific briefing sections.
--
-- Addon mods can register voice packs via:
--   Definitions/VoicePacks/my_custom_voice.lua
--
-- See design-guidelines.md §32.7.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion = { type = "number", required = true },
        id            = { type = "string",  required = true },
        archetypeId   = { type = "string",  required = true },
        description   = { type = "string",  default = "" },
        overrides     = { type = "table",   required = true },
        enabled       = { type = "boolean", default = true },
    }
}
