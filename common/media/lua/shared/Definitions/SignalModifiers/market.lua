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
-- Definitions/SignalModifiers/market.lua
-- Market condition signal modifiers affecting saturation and noise.
---------------------------------------------------------------

local registry = POS_SignalModifierRegistry and POS_SignalModifierRegistry.getRegistry()
if not registry then return end

registry:register({
    schemaVersion = 1,
    id = "market_stable",
    pillar = "saturation",
    trigger = "market_stable",
    saturation = 0.00,
    noise = 0.00,
    severity = 0.0,
    description = "Stable market conditions, no saturation impact",
})

registry:register({
    schemaVersion = 1,
    id = "market_high_demand",
    pillar = "saturation",
    trigger = "market_high_demand",
    saturation = 0.15,
    noise = 0.05,
    severity = 0.4,
    description = "High demand increases signal saturation",
})

registry:register({
    schemaVersion = 1,
    id = "market_scarcity",
    pillar = "saturation",
    trigger = "market_scarcity",
    saturation = 0.10,
    noise = 0.15,
    severity = 0.6,
    description = "Scarcity drives noisy, saturated signal traffic",
})

registry:register({
    schemaVersion = 1,
    id = "market_volatile",
    pillar = "saturation",
    trigger = "market_volatile",
    saturation = 0.20,
    noise = 0.20,
    severity = 0.7,
    description = "Volatile market floods channels with conflicting signals",
})

registry:register({
    schemaVersion = 1,
    id = "market_panic",
    pillar = "saturation",
    trigger = "market_panic",
    saturation = 0.30,
    noise = 0.25,
    severity = 0.9,
    description = "Market panic causes extreme saturation and noise",
})
