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
-- POS_Constants_Entropy.lua
-- Constants for the POSnet entropy / fog-of-market system.
-- Design reference: docs/architecture/entropy-system-design.md
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Decay rates (applied once per economy tick)
---------------------------------------------------------------

--- Multiplicative freshness decay per tick (0.88 = 12% loss per tick)
POS_Constants.ENTROPY_FRESHNESS_DECAY          = 0.88

--- Multiplicative contradiction natural decay per tick
POS_Constants.ENTROPY_CONTRADICTION_DECAY      = 0.75

--- Multiplicative rumourLoad natural decay per tick (slow)
POS_Constants.ENTROPY_RUMOUR_LOAD_DECAY        = 0.95

--- Certainty loss per silenceDay (additive per tick)
POS_Constants.ENTROPY_CERTAINTY_SILENCE_RATE   = 0.03

--- Certainty loss per unit of rumourLoad (additive per tick)
POS_Constants.ENTROPY_CERTAINTY_NOISE_RATE     = 0.02

--- How much rumourLoad attenuates effective pressure (0.50 = 50% max)
POS_Constants.ENTROPY_NOISE_WEIGHT             = 0.50

---------------------------------------------------------------
-- Trust parameters
---------------------------------------------------------------

POS_Constants.ENTROPY_TRUST_DEFAULT            = 0.50
POS_Constants.ENTROPY_TRUST_MIN                = 0.10
POS_Constants.ENTROPY_TRUST_MAX                = 0.95

---------------------------------------------------------------
-- Silence thresholds (in game days)
---------------------------------------------------------------

--- Days without observation before "warning" label
POS_Constants.ENTROPY_SILENCE_WARNING_DAYS     = 3

--- Days without observation before "stale" classification
POS_Constants.ENTROPY_SILENCE_STALE_DAYS       = 5

--- Days without observation before "cold market" label
POS_Constants.ENTROPY_SILENCE_COLD_DAYS        = 8

---------------------------------------------------------------
-- Saturation (overload from too many low-quality inputs)
---------------------------------------------------------------

--- Observations per tick before saturation penalties apply
POS_Constants.ENTROPY_SATURATION_THRESHOLD     = 8

--- Confidence penalty per observation above saturation threshold
POS_Constants.ENTROPY_SATURATION_CONF_PENALTY  = 0.10

---------------------------------------------------------------
-- Default values for new zone/category intel state
---------------------------------------------------------------

POS_Constants.ENTROPY_DEFAULT_CERTAINTY        = 0.50
POS_Constants.ENTROPY_DEFAULT_FRESHNESS        = 0.50

---------------------------------------------------------------
-- UI atmospheric state thresholds (certainty-based)
-- Bands are sorted descending; first match wins.
---------------------------------------------------------------

POS_Constants.ENTROPY_LABEL_CLEAR              = 0.80
POS_Constants.ENTROPY_LABEL_AGEING             = 0.60
POS_Constants.ENTROPY_LABEL_CONFLICTING        = 0.40
POS_Constants.ENTROPY_LABEL_DISTORTED          = 0.20

---------------------------------------------------------------
-- Atmospheric state band definitions (for resolveQualitativeBand)
---------------------------------------------------------------

POS_Constants.ENTROPY_ATMOSPHERIC_BANDS = {
    { name = "clear",       min = 0.80, key = "UI_POS_Entropy_Clear",       r = 0.20, g = 0.90, b = 0.50 },
    { name = "ageing",      min = 0.60, key = "UI_POS_Entropy_Ageing",      r = 0.33, g = 1.00, b = 0.33 },
    { name = "conflicting", min = 0.40, key = "UI_POS_Entropy_Conflicting", r = 1.00, g = 0.80, b = 0.20 },
    { name = "distorted",   min = 0.20, key = "UI_POS_Entropy_Distorted",   r = 1.00, g = 0.50, b = 0.20 },
    { name = "cold",        min = 0.00, key = "UI_POS_Entropy_Cold",        r = 1.00, g = 0.30, b = 0.30 },
}

---------------------------------------------------------------
-- Notification throttling
---------------------------------------------------------------

--- Minimum game-minutes between entropy notifications per zone/category
POS_Constants.ENTROPY_PN_THROTTLE_MIN          = 60

--- Contradiction score threshold that triggers a notification
POS_Constants.ENTROPY_PN_CONTRADICTION_THRESHOLD = 0.70

---------------------------------------------------------------
-- Observation freshness boost
---------------------------------------------------------------

--- How much freshness is restored when a new observation arrives
POS_Constants.ENTROPY_OBSERVATION_FRESHNESS_BOOST = 0.30

--- How much certainty is restored per observation (scaled by confidence)
POS_Constants.ENTROPY_OBSERVATION_CERTAINTY_BOOST = 0.10
