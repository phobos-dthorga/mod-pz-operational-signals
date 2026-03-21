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

-- ============================================================================
-- Market Event Definition Template
-- ============================================================================
-- Copy this file and rename it to create a new market event.
-- Place the new file in this same directory (Definitions/Events/).
--
-- The loader discovers all .lua files in this folder automatically.
-- Files starting with "_" are ignored by the loader.
--
-- All fields are validated against POS_EventSchema.lua at load time.
-- ============================================================================

return {
    -- Schema version (must be 1 for current format)
    schemaVersion = 1,

    -- Unique identifier for this event (must be unique across all events)
    id = "my_event",

    -- Display name shown in the terminal UI and event log
    name = "My Custom Event",

    -- Translation key for the display name (used for i18n lookup in getText())
    displayNameKey = "UI_POS_MarketEvent_YourEvent",

    -- Short description of what happens when this event fires
    description = "A brief description of the market event.",

    -- Signal classification that determines how the event is detected and reported.
    -- Valid values:
    --   "hard"       - Concrete, observable event (shipment arrives, raid happens)
    --   "soft"       - Rumour or unconfirmed intelligence (delays, shortages)
    --   "structural" - Deliberate market manipulation by agents (withholding, dumping)
    signalClass = "soft",

    -- How much this event shifts supply pressure in affected categories.
    -- Negative values = increased supply (prices drop).
    -- Positive values = decreased supply / increased demand (prices rise).
    -- Typical range: -0.5 to +0.5
    pressureEffect = 0,

    -- How many in-game days this event's effects persist (minimum 1)
    durationDays = 3,

    -- List of commodity categories affected by this event.
    -- Categories: "food", "medicine", "ammunition", "fuel", "tools", "radio", "weapons"
    affectedCategories = {},

    -- Base probability of this event firing per market tick (0.0 to 1.0).
    -- Typical range: 0.03 (rare) to 0.15 (common)
    probability = 0.10,

    -- Set to true to activate this event. Templates ship disabled.
    enabled = false,
}
