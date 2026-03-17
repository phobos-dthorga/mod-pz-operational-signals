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
-- POS_Distributions.lua
-- Loot distribution tables for POSnet items.
--
-- The Portable Computer is a rare find that replaces the
-- desktop computer requirement for POSnet access.
---------------------------------------------------------------
require "Items/ItemPicker"
require "Items/Distributions"
require "Items/ProceduralDistributions"

-----------------------------------------------------
-- Nil-guarded distribution helper.
-- Prevents crash if a distribution key is renamed,
-- removed, or absent in the current B42 build.
-----------------------------------------------------
local function dist(listName, itemType, chance)
    local entry = ProceduralDistributions.list[listName]
    if entry and entry.items then
        table.insert(entry.items, itemType)
        table.insert(entry.items, chance)
    end
end

-----------------------------------------------------
-- PORTABLE COMPUTER
-- Very rare find — rewards exploration of offices,
-- military bases, electronics stores, and police stations.
-----------------------------------------------------
local PC = "PhobosOperationalSignals.PortableComputer"

-- Electronics stores — most likely find location
dist("ElectronicStoreComputers",  PC, 0.8)
dist("ElectronicStoreMisc",       PC, 0.3)

-- Military — bunkers and storage facilities
dist("ArmyStorageElectronics",    PC, 0.6)
dist("ArmyBunkerStorage",        PC, 0.3)

-- Offices — desk drawers and shelves
dist("OfficeDesk",                PC, 0.3)
dist("OfficeDrawers",             PC, 0.2)

-- Police stations — desks
dist("PoliceDesk",                PC, 0.2)

-- Schools — lockers
dist("SchoolLockers",             PC, 0.1)
