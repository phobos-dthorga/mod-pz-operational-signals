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
-- POS_CrossModMarkets.lua
-- Cross-mod commodity category registration for PCP and PIP.
-- Runtime detection via getActivatedMods(). Registered at
-- OnGameStart to ensure POS_MarketRegistry is loaded.
--
-- Categories are OPTIONAL — only activated when the respective
-- mod is present. Players who only install POSnet will see
-- the base 6 categories.
---------------------------------------------------------------

require "PhobosLib"
require "POS_MarketRegistry"

POS_CrossModMarkets = {}

--- Register cross-mod commodity categories.
--- Called at OnGameStart so mod detection is reliable.
local function registerCrossModCategories()
    local mods = getActivatedMods()
    if not mods then return end

    -- PhobosChemistryPathways — chemicals, agriculture, biofuel
    if mods:contains("PhobosChemistryPathways") then
        POS_MarketRegistry.registerCategory({
            id = "chemicals",
            labelKey = "UI_POS_Market_Cat_Chemicals",
            sortOrder = 70,
        })
        POS_MarketRegistry.registerCategory({
            id = "agriculture",
            labelKey = "UI_POS_Market_Cat_Agriculture",
            sortOrder = 80,
        })
        POS_MarketRegistry.registerCategory({
            id = "biofuel",
            labelKey = "UI_POS_Market_Cat_Biofuel",
            sortOrder = 90,
        })
        PhobosLib.debug("POS", "[POS:CrossMod]",
            "PCP detected — registered chemicals/agriculture/biofuel categories")
    end

    -- PhobosIndustrialPathology — specimens, biohazard
    if mods:contains("PhobosIndustrialPathology") then
        POS_MarketRegistry.registerCategory({
            id = "specimens",
            labelKey = "UI_POS_Market_Cat_Specimens",
            sortOrder = 100,
        })
        POS_MarketRegistry.registerCategory({
            id = "biohazard",
            labelKey = "UI_POS_Market_Cat_Biohazard",
            sortOrder = 110,
        })
        PhobosLib.debug("POS", "[POS:CrossMod]",
            "PIP detected — registered specimens/biohazard categories")
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(registerCrossModCategories)
end
