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
-- POS_Constants_Signal.lua
-- Signal Ecology v2 constants. Core baselines, thresholds,
-- and tuning values for the five-pillar signal model.
--
-- Domain-specific constants for the Signal Ecology system.
-- Loaded after POS_Constants.lua (alphabetical load order).
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Tier baselines (floor/ceiling clamps per reputation tier)
---------------------------------------------------------------

POS_Constants.SIGNAL_TIER_BASELINES = {
    { floor = 0.10, ceiling = 0.60 },  -- Tier I
    { floor = 0.25, ceiling = 0.80 },  -- Tier II
    { floor = 0.35, ceiling = 0.85 },  -- Tier III
    { floor = 0.45, ceiling = 0.92 },  -- Tier IV
    { floor = 0.55, ceiling = 0.98 },  -- Tier V
}

---------------------------------------------------------------
-- Qualitative state thresholds (checked descending)
---------------------------------------------------------------

POS_Constants.SIGNAL_STATE_LOCKED_MIN      = 0.85
POS_Constants.SIGNAL_STATE_CLEAR_MIN       = 0.65
POS_Constants.SIGNAL_STATE_FADED_MIN       = 0.45
POS_Constants.SIGNAL_STATE_FRAGMENTED_MIN  = 0.25
POS_Constants.SIGNAL_STATE_GHOSTED_MIN     = 0.10

-- State names (for translation key construction: "UI_POS_Signal_State_" .. name)
POS_Constants.SIGNAL_STATES = { "locked", "clear", "faded", "fragmented", "ghosted", "lost" }

---------------------------------------------------------------
-- Clarity contribution per reputation tier (index = tier)
-- Clarity is multiplicative in the composite formula, so these
-- values cap the maximum achievable signal. Tuned so that:
--   Tier 1 (SIGINT 0-1): best ~0.49 (faded)
--   Tier 2 (SIGINT 2-3): best ~0.61 (faded, approaching clear)
--   Tier 3 (SIGINT 4-5): best ~0.66 (clear)
--   Tier 4 (SIGINT 6-7): best ~0.69 (clear)
--   Tier 5 (SIGINT 8+):  best ~0.71 (clear)
---------------------------------------------------------------

POS_Constants.SIGNAL_CLARITY_BY_TIER = { 0.70, 0.85, 0.92, 0.97, 1.00 }

---------------------------------------------------------------
-- Agent saturation scaling
---------------------------------------------------------------

POS_Constants.SIGNAL_AGENT_SAT_PER_AGENT = 0.04
POS_Constants.SIGNAL_AGENT_SAT_CAP       = 0.25

---------------------------------------------------------------
-- WBN text degradation dropout rates per qualitative state
---------------------------------------------------------------

POS_Constants.SIGNAL_WBN_DROPOUT_LOCKED      = 0.00
POS_Constants.SIGNAL_WBN_DROPOUT_CLEAR       = 0.00
POS_Constants.SIGNAL_WBN_DROPOUT_FADED       = 0.15
POS_Constants.SIGNAL_WBN_DROPOUT_FRAGMENTED  = 0.40
POS_Constants.SIGNAL_WBN_DROPOUT_GHOSTED     = 0.70

---------------------------------------------------------------
-- Recalculation interval (game hours between full recalcs)
---------------------------------------------------------------

POS_Constants.SIGNAL_RECALC_INTERVAL_HOURS = 1

---------------------------------------------------------------
-- Safe fallback composite (used if ecology fails to initialise)
---------------------------------------------------------------

POS_Constants.SIGNAL_FALLBACK_COMPOSITE = 0.50

---------------------------------------------------------------
-- Pillar base values (before modifiers)
---------------------------------------------------------------

-- Propagation base (before weather/season modifiers)
POS_Constants.SIGNAL_PROPAGATION_BASE = 0.85

-- Infrastructure base (before power/grid modifiers)
POS_Constants.SIGNAL_INFRASTRUCTURE_BASE = 0.70

-- Saturation base (before agents/market modifiers)
POS_Constants.SIGNAL_SATURATION_BASE = 0.10

-- Intent stub (always 1.0 until Tier V Phase E)
POS_Constants.SIGNAL_INTENT_STUB = 1.0

---------------------------------------------------------------
-- Pillar quality word thresholds (for UI display)
---------------------------------------------------------------

POS_Constants.SIGNAL_PILLAR_EXCELLENT_MIN = 0.80
POS_Constants.SIGNAL_PILLAR_GOOD_MIN      = 0.60
POS_Constants.SIGNAL_PILLAR_FAIR_MIN      = 0.40
POS_Constants.SIGNAL_PILLAR_UNSTABLE_MIN  = 0.20

---------------------------------------------------------------
-- Market trigger thresholds (average zone pressure → market state)
---------------------------------------------------------------

POS_Constants.SIGNAL_MARKET_DEMAND_THRESHOLD    = 0.15  -- high_demand
POS_Constants.SIGNAL_MARKET_SCARCITY_THRESHOLD  = 0.30  -- scarcity
POS_Constants.SIGNAL_MARKET_VOLATILE_THRESHOLD  = 0.50  -- volatile
POS_Constants.SIGNAL_MARKET_PANIC_THRESHOLD     = 0.70  -- panic

---------------------------------------------------------------
-- SIGINT skill level → signal tier mapping (level 0-10 → tier 1-5)
---------------------------------------------------------------

POS_Constants.SIGNAL_DEFAULT_TIER = 2  -- used when SIGINT is unavailable

---------------------------------------------------------------
-- Signal Ecology BPS scaling for passive recon chunks.
-- Maps composite signal (0-1) deviation from 0.5 midpoint to BPS bonus.
-- At 0.5 (faded): +0 BPS. At 0.85 (locked): +1400 BPS.
-- At 0.1 (ghosted): -1600 BPS.
---------------------------------------------------------------

POS_Constants.SIGNAL_ECOLOGY_BPS_SCALE = 4000

---------------------------------------------------------------
-- WBN broadcast proximity gate
-- Maximum squared tile distance from receiving device to player.
-- Matches WORLD_RADIO_SCAN_RADIUS (20 tiles) for consistency.
---------------------------------------------------------------

POS_Constants.WBN_HEARING_RANGE_SQ = 400  -- 20^2

---------------------------------------------------------------
-- Receiver quality (hardware-dependent WBN dropout scaling)
-- See design-guidelines.md §60 for receiver quality architecture.
---------------------------------------------------------------

-- Formula constants (fallback for radios without a registered profile)
POS_Constants.RECEIVER_RANGE_NORMALISER   = 20000  -- max transmit range for 0-1 normalisation
POS_Constants.RECEIVER_RANGE_WEIGHT       = 0.70   -- how much range contributes to quality
POS_Constants.RECEIVER_HAM_BONUS          = 0.10   -- subtracted from factor for ham category
POS_Constants.RECEIVER_MAKESHIFT_PENALTY  = 0.15   -- added to factor for makeshift items
POS_Constants.RECEIVER_COMMERCIAL_BASE    = 0.75   -- fixed factor for 0-range commercial/tv
POS_Constants.RECEIVER_FACTOR_MIN         = 0.20   -- absolute floor (military-grade)
POS_Constants.RECEIVER_FACTOR_MAX         = 0.95   -- absolute ceiling (worst makeshift)
POS_Constants.RECEIVER_FACTOR_FALLBACK    = 1.00   -- when no radio detected (ecology-only)
POS_Constants.RECEIVER_CONDITION_WEIGHT   = 0.50   -- minimum performance at 0% condition
POS_Constants.RECEIVER_CONFIDENCE_SCALE   = 0.30   -- how much quality affects fragment confidence

-- Receiver quality band thresholds (inverted: 1.0 - factor, higher = better)
-- Used with PhobosLib.resolveQualitativeBand() for label resolution
POS_Constants.RECEIVER_QUALITY_BANDS = {
    { name = "excellent", min = 0.70 },  -- factor ≤ 0.30 (ManPack, HamRadio2)
    { name = "good",      min = 0.50 },  -- factor ≤ 0.50 (WT4-5, HamRadio1)
    { name = "fair",      min = 0.25 },  -- factor ≤ 0.75 (commercial, WT2-3)
    { name = "poor",      min = 0.00 },  -- factor > 0.75 (makeshift, damaged)
}

---------------------------------------------------------------
-- SIGINT skill level → signal tier mapping (level 0-10 → tier 1-5)
---------------------------------------------------------------

-- Index = SIGINT level (0-10), value = signal tier (1-5)
POS_Constants.SIGNAL_SIGINT_TIER_MAP = {
    [0]  = 1,
    [1]  = 1,
    [2]  = 2,
    [3]  = 2,
    [4]  = 3,
    [5]  = 3,
    [6]  = 4,
    [7]  = 4,
    [8]  = 5,
    [9]  = 5,
    [10] = 5,
}
