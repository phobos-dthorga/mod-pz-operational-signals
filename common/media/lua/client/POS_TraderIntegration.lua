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
-- POS_TraderIntegration.lua
-- Dynamic Trading soft dependency.
-- When DT is active, registers a "Market Broker" archetype
-- that trades compiled market reports and raw market notes.
-- When DT is NOT active, does nothing.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_TraderIntegration = {}

local _TAG = "[POS:TraderInt]"

--- Register Market Broker archetype with Dynamic Trading.
--- Called at OnGameStart after mods are detected.
local function registerMarketBroker()
    local mods = getActivatedMods()
    if not mods or not mods:contains("DynamicTrading") then return end

    -- Guard: only register if DT API is available
    if not DynamicTrading or not DynamicTrading.registerArchetype then
        PhobosLib.debug("POS", _TAG,
            "DynamicTrading mod detected but API not available")
        return
    end

    DynamicTrading.registerArchetype({
        id = "POS_MarketBroker",
        name = "Market Broker",
        items = {
            {
                fullType = POS_Constants.ITEM_RAW_MARKET_NOTE,
                weight = 30,
                minQuantity = 1,
                maxQuantity = 3,
            },
            {
                fullType = POS_Constants.ITEM_COMPILED_REPORT,
                weight = 10,
                minQuantity = 1,
                maxQuantity = 1,
            },
        },
    })

    PhobosLib.debug("POS", _TAG,
        "Market Broker archetype registered with Dynamic Trading")
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(registerMarketBroker)
end
