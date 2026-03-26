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
-- Definitions/SignalModifiers/season.lua
-- Seasonal signal modifiers affecting propagation and saturation.
---------------------------------------------------------------

local registry = POS_SignalModifierRegistry and POS_SignalModifierRegistry.getRegistry()
if not registry then return end

registry:register({
    schemaVersion = 1,
    id = "season_summer",
    pillar = "propagation",
    trigger = "summer",
    propagation = 0.05,
    saturation = 0.10,
    severity = 0.1,
    description = "Summer improves propagation, increases trade saturation",
})

registry:register({
    schemaVersion = 1,
    id = "season_autumn",
    pillar = "propagation",
    trigger = "autumn",
    propagation = -0.05,
    saturation = 0.00,
    severity = 0.2,
    description = "Autumn slightly degrades propagation conditions",
})

registry:register({
    schemaVersion = 1,
    id = "season_winter",
    pillar = "propagation",
    trigger = "winter",
    propagation = -0.10,
    saturation = -0.10,
    severity = 0.5,
    description = "Winter degrades propagation and reduces trade activity",
})

registry:register({
    schemaVersion = 1,
    id = "season_spring",
    pillar = "propagation",
    trigger = "spring",
    propagation = 0.00,
    saturation = 0.05,
    severity = 0.1,
    description = "Spring slightly increases trade activity",
})
