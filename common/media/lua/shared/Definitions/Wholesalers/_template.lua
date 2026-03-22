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
-- Wholesaler Definition Template
-- ============================================================================
-- Copy this file and rename it to create a new wholesaler entity.
-- Place the new file in this same directory (Definitions/Wholesalers/).
--
-- The loader discovers all .lua files in this folder automatically.
-- Files starting with "_" are ignored by the loader.
--
-- Wholesalers are bulk distributors tied to a specific market zone. Their
-- stock levels, throughput, and behaviour directly influence regional
-- supply pressure and pricing.
--
-- All fields are validated against POS_WholesalerSchema.lua at load time.
-- ============================================================================

return {
    -- Schema version (must be 1 for current format)
    schemaVersion = 1,

    -- Unique identifier for this wholesaler (must be unique across all wholesalers)
    id = "my_wholesaler",

    -- Display name shown in the terminal UI
    name = "My Custom Wholesaler",

    -- Translation key for the display name (used for i18n lookup in getText())
    displayNameKey = "UI_POS_Wholesaler_Name_YourWholesaler",

    -- Short description of this wholesaler's role and character
    description = "A brief description of this wholesaler.",

    -- The market zone this wholesaler operates in (must match a valid zone ID)
    regionId = "muldraugh",

    -- Archetype that controls base AI behaviour (typically "wholesaler")
    archetype = "wholesaler",

    -- Per-category weight overrides (0.0 = ignores category, 1.0 = normal weight).
    -- Categories not listed default to 0.0.
    -- Categories: food, medicine, ammunition, fuel, tools, radio, weapons
    categoryWeights = {
        food     = 1.0,
        medicine = 0.5,
        fuel     = 0.8,
        tools    = 0.6,
    },

    -- How full this wholesaler's warehouse typically is (0.0 = empty, 1.0 = overflowing)
    stockLevel = 0.75,

    -- Rate at which goods flow through this wholesaler (0.0 = bottleneck, 1.0 = high throughput)
    throughput = 0.60,

    -- Ability to absorb supply shocks without disruption (0.0 = fragile, 1.0 = rock solid)
    resilience = 0.70,

    -- How easily this wholesaler can be discovered by players (0.0 = hidden, 1.0 = well-known)
    visibility = 0.35,

    -- How consistently this wholesaler fulfils orders (0.0 = unreliable, 1.0 = always delivers)
    reliability = 0.80,

    -- How much this wholesaler's actions move regional prices (0.0 = negligible, 1.0 = dominant)
    influence = 0.85,

    -- How covertly this wholesaler operates (0.0 = transparent, 1.0 = completely hidden)
    secrecy = 0.20,

    -- Base price markup/discount tendency (-1.0 = deep discounts, 0.0 = fair, 1.0 = gouging)
    markupBias = -0.08,

    -- Supply pressure level at which the wholesaler enters panic buying mode (0.0 to 1.0)
    panicThreshold = 0.25,

    -- Stock level at which the wholesaler begins dumping excess inventory (0.0 to 1.0)
    dumpThreshold = 0.90,

    -- Set to true to activate this wholesaler. Templates ship disabled.
    enabled = false,
}
