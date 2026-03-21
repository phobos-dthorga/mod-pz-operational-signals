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
-- Archetype Definition Template
-- ============================================================================
-- Copy this file and rename it to create a new market agent archetype.
-- Place the new file in this same directory (Definitions/Archetypes/).
--
-- The loader discovers all .lua files in this folder automatically.
-- Files starting with "_" are ignored by the loader.
--
-- All fields are validated against POS_ArchetypeSchema.lua at load time.
-- ============================================================================

return {
    -- Schema version (must be 1 for current format)
    schemaVersion = 1,

    -- Unique identifier for this archetype (must be unique across all archetypes)
    id = "my_archetype",

    -- Display name shown in the terminal UI
    name = "My Custom Archetype",

    -- Translation key for the display name (used for i18n lookup in getText())
    displayNameKey = "UI_POS_Agent_YourArchetype",

    -- Short description of the archetype's role in the market
    description = "A brief description of what this archetype represents.",

    -- Behaviour class that controls the agent's AI logic.
    -- Valid values:
    --   "baseline_trader"      - Standard buy/sell trader
    --   "speculator"           - Buys low, sells high, amplifies volatility
    --   "wholesaler"           - Bulk distributor, drives regional supply
    --   "smuggler"             - High-risk, high-reward, operates in secrecy
    --   "military_logistics"   - Controlled distribution, stable but rigid
    --   "specialist_crafter"   - Focuses on niche crafted goods
    behaviour = "baseline_trader",

    -- Tuning parameters that control agent personality and market behaviour
    tuning = {
        -- How consistently the agent shows up to trade (0.0 = unreliable, 1.0 = always present)
        reliability = 0.55,

        -- How much the agent's prices fluctuate between visits (0.0 = stable, 1.0 = wild swings)
        volatility = 0.30,

        -- General stock level tendency: "none", "low", "medium", "high"
        stockBias = "medium",

        -- Price markup/discount tendency (-1.0 = deep discounts, 0.0 = fair, 1.0 = gouging)
        priceBias = 0.0,

        -- How often (in game days) the agent refreshes their inventory (1-30)
        refreshDays = 2,

        -- How much this agent affects regional market prices (0-10)
        influence = 1,

        -- How hidden this agent is from casual discovery (0.0 = public, 1.0 = invisible)
        secrecy = 0.20,

        -- Chance per tick to generate market rumours (0.0 = silent, 1.0 = constant chatter)
        rumorRate = 0.10,

        -- Willingness to engage in risky trades (0.0 = conservative, 1.0 = reckless)
        riskTolerance = 0.50,
    },

    -- Category affinities: how much this archetype favours each commodity category.
    -- Values from 0.0 (no interest) to 1.0+ (primary focus).
    -- Categories: food, medicine, ammunition, fuel, tools, radio, weapons
    affinities = {
        food       = 0.5,
        medicine   = 0.5,
        ammunition = 0.5,
        fuel       = 0.5,
        tools      = 0.5,
        radio      = 0.5,
        weapons    = 0.5,
    },

    -- Set to true to activate this archetype. Templates ship disabled.
    enabled = false,
}
