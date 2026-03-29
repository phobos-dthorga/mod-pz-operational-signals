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
-- POS_Constants_BroadcastInfluence.lua
-- Constants for the POSnet broadcast influence system.
-- Design reference: docs/architecture/broadcast-influence-design.md
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- World ModData key
---------------------------------------------------------------

POS_Constants.WMD_BROADCAST_INFLUENCE = "POSNET.BroadcastInfluence"

---------------------------------------------------------------
-- Record storage
---------------------------------------------------------------

--- Maximum number of broadcast influence records to retain
POS_Constants.BROADCAST_RECORD_MAX = 30

---------------------------------------------------------------
-- Freshness decay
---------------------------------------------------------------

--- Multiplicative freshness decay per economy tick (0.85 = 15% loss/tick)
POS_Constants.BROADCAST_FRESHNESS_DECAY = 0.85

--- Freshness floor below which a record is considered resolved
POS_Constants.BROADCAST_RESOLVED_FRESHNESS_FLOOR = 0.01

---------------------------------------------------------------
-- Perceived pressure parameters
---------------------------------------------------------------

--- Maximum absolute contribution of broadcast perceived pressure
POS_Constants.BROADCAST_PERCEIVED_PRESSURE_WEIGHT = 0.40

--- Multiplier converting broadcast strength to pressure magnitude
POS_Constants.BROADCAST_STRENGTH_TO_PRESSURE_MULT = 0.60

---------------------------------------------------------------
-- Trust mutation
---------------------------------------------------------------

--- Scaling factor for trust mutation from broadcasts
POS_Constants.BROADCAST_TRUST_MUTATION_RATE = 1.0

--- Trust delta threshold that triggers a rising/falling notification
POS_Constants.BROADCAST_TRUST_NOTIFY_THRESHOLD = 0.10

---------------------------------------------------------------
-- Direction per broadcast mode (signed multiplier)
-- Positive = upward price pressure, negative = downward.
---------------------------------------------------------------

POS_Constants.BROADCAST_MODE_PRESSURE_DIRECTION = {
    scarcity_alert   =  1.0,   -- prices up
    surplus_notice   = -1.0,   -- prices down
    route_warning    =  0.5,   -- mild scarcity
    contact_bulletin =  0.0,   -- trust-only, no pressure
    strategic_rumour =  0.3,   -- panic-induced mild scarcity
}
