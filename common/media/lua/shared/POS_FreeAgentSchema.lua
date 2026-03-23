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
-- Schema for free agent assignment records.
-- Each record tracks a runner/broker/courier sent into the
-- wasteland on the player's behalf. State machine:
--
--   drafted → assembling → transit → negotiation → settlement → completed
--                              ↓           ↓
--                           delayed    compromised
--
-- See design-guidelines.md §46.
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion    = { type = "number", required = true },
        id               = { type = "string",  required = true },
        agentName        = { type = "string",  required = true },
        agentArchetype   = { type = "string",  required = true,
            enum = { "runner", "broker", "courier", "smuggler", "wholesaler_contact" } },
        contractId       = { type = "string",  default = "" },
        state            = { type = "string",  required = true,
            enum = { "drafted", "assembling", "transit", "negotiation",
                     "settlement", "completed", "failed", "delayed", "compromised" } },
        zoneId           = { type = "string",  default = "" },
        cargoFullType    = { type = "string",  default = "" },
        cargoQuantity    = { type = "number",  default = 0 },
        commissionRate   = { type = "number",  min = 0, max = 1, default = 0.10 },
        estimatedDays    = { type = "number",  min = 1, max = 30, default = 3 },
        startDay         = { type = "number",  default = 0 },
        lastStateDay     = { type = "number",  default = 0 },
        settlementPayout = { type = "number",  default = 0 },
        riskLevel        = { type = "number",  min = 0, max = 1, default = 0.1 },
        enabled          = { type = "boolean", default = true },
    }
}
