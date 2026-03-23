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
-- Schema for per-item base price overrides.
-- Each entry represents a single PZ item whose base price
-- should be set to a curated value rather than the default
-- weight-based formula.
--
-- id        = PZ fullType (e.g. "Base.Generator")
-- basePrice = absolute base price in dollars
-- isLuxury  = if true, price is scaled by zone luxuryDemand
-- reason    = audit trail / documentation
---------------------------------------------------------------

return {
    schemaVersion = 1,
    fields = {
        schemaVersion = { type = "number", required = true },
        id            = { type = "string",  required = true },
        basePrice     = { type = "number",  required = true, min = 0.01 },
        isLuxury      = { type = "boolean", default = false },
        reason        = { type = "string",  default = "" },
    }
}
