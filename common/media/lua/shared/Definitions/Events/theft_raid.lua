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

return {
    schemaVersion = 1,
    id = "theft_raid",
    name = "Theft / Raid",
    displayNameKey = "UI_POS_MarketEvent_TheftRaid",
    description = "Bandits or looters hit a supply cache, destroying stock.",
    signalClass = "hard",
    pressureEffect = 0.4,
    durationDays = 3,
    affectedCategories = { "weapons", "ammunition", "fuel" },
    probability = 0.06,
}
