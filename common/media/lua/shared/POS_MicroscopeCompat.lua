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
-- POS_MicroscopeCompat.lua
-- Soft dependency on ZVirusVaccine42BETA (ZVV) microscope.
--
-- ZVV's LabMicroscope2 entity claims the vanilla microscope
-- sprites (location_community_medical_01_136+) as a CraftBench
-- with recipe tag "ZVirusVaccine42BETA:Microscope".
--
-- POSnet cannot define its own entity for the same sprites
-- (duplicate sprite error). Instead:
--   - Microcassette precision recipes (RewindMicrocassette,
--     RecycleMicrocassette) are PORTABLE by default.
--   - When ZVV is detected, these recipes can optionally be
--     performed at the microscope workstation as a thematic
--     enhancement, but are NOT gated to it.
--
-- This module detects ZVV at world load and logs the status.
---------------------------------------------------------------

require "PhobosLib"

POS_MicroscopeCompat = {}

local ZVV_MOD_ID = "ZVirusVaccine42BETA"
local TAG = "MicroscopeCompat"

--- Whether ZVV (and its microscope workstation) is available.
POS_MicroscopeCompat.hasZVV = false

--- Detect ZVV at game start and log the result.
local function onGameStart()
    local mods = getActivatedMods()
    if mods and mods:contains(ZVV_MOD_ID) then
        POS_MicroscopeCompat.hasZVV = true
        PhobosLib.debug("POS", TAG,
            "ZVV detected — microscope workstation available for microcassette recipes")
    else
        PhobosLib.debug("POS", TAG,
            "ZVV not detected — microcassette recipes are portable (no workstation required)")
    end
end

Events.OnGameStart.Add(onGameStart)
