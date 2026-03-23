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
-- Schema for sell-side contract definitions.
--
-- Contracts are world-originated demand orders: someone out
-- there needs something and is willing to pay.  They are NOT
-- player-originated sell offers (that comes later with the
-- free-agent system).
--
-- kind values:
--   "procurement"     — standard supply request
--   "urgent"          — premium price, short deadline
--   "standing"        — recurring weekly supply, lower margins
--   "grey_market"     — cash only, higher betrayal risk
--   "military"        — strict specs, good pay, gated access
--   "arbitrage"       — exploit regional price differences
--
-- See design-guidelines.md §43.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion   = { type = "number", required = true },
        id              = { type = "string",  required = true },
        name            = { type = "string",  required = true },
        description     = { type = "string",  default = "" },
        kind            = { type = "string",  required = true, enum = {
            "procurement", "urgent", "standing",
            "grey_market", "military", "arbitrage",
        }},
        -- What the buyer wants
        categoryId      = { type = "string",  required = true },
        itemFilter      = { type = "string",  default = "" },
        quantityMin     = { type = "number",  min = 1, default = 5 },
        quantityMax     = { type = "number",  min = 1, default = 20 },
        -- Pricing
        payMultiplierMin = { type = "number", min = 0.5, max = 5.0, default = 1.0 },
        payMultiplierMax = { type = "number", min = 0.5, max = 5.0, default = 1.5 },
        -- Timing
        deadlineDaysMin = { type = "number",  min = 1, default = 3 },
        deadlineDaysMax = { type = "number",  min = 1, default = 7 },
        -- Difficulty / gating
        urgency         = { type = "number",  min = 1, max = 5, default = 2 },
        sigintRequired  = { type = "number",  min = 0, max = 10, default = 0 },
        reputationMin   = { type = "number",  min = 0, default = 0 },
        -- Buyer identity
        archetypeId     = { type = "string",  default = "" },
        -- Risk
        betrayalChance  = { type = "number",  min = 0, max = 1, default = 0 },
        -- Briefing text pool overrides
        briefingPools   = { type = "table" },
        -- Enabled flag
        enabled         = { type = "boolean", default = true },
    }
}
