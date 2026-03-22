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
-- POS_Constants_Media.lua
-- VHS, microcassette, floppy, data-recorder constants,
-- media modData keys, confidence thresholds, chunk types.
---------------------------------------------------------------

require "POS_Constants"

---------------------------------------------------------------
-- Passive recon device item types
---------------------------------------------------------------

POS_Constants.ITEM_RECON_CAMCORDER      = "PhobosOperationalSignals.ReconCamcorder"
POS_Constants.ITEM_FIELD_SURVEY_LOGGER  = "PhobosOperationalSignals.FieldSurveyLogger"
POS_Constants.ITEM_DATA_CALCULATOR      = "PhobosOperationalSignals.DataCalculator"
POS_Constants.ITEM_BLANK_VHS_TAPE       = "PhobosOperationalSignals.BlankVHSCTape"
POS_Constants.ITEM_RECORDED_RECON_TAPE  = "PhobosOperationalSignals.RecordedReconTape"
POS_Constants.ITEM_WORN_VHS_TAPE        = "PhobosOperationalSignals.WornVHSTape"
POS_Constants.ITEM_DAMAGED_VHS_TAPE     = "PhobosOperationalSignals.DamagedVHSTape"
POS_Constants.ITEM_MAGNETIC_TAPE_SCRAP  = "PhobosOperationalSignals.MagneticTapeScrap"
POS_Constants.ITEM_REFURBISHED_TAPE     = "PhobosOperationalSignals.RefurbishedVHSCTape"
POS_Constants.ITEM_SPLICED_TAPE         = "PhobosOperationalSignals.SplicedReconTape"
POS_Constants.ITEM_IMPROVISED_TAPE      = "PhobosOperationalSignals.ImprovisedReconTape"

---------------------------------------------------------------
-- Passive recon scan parameters
---------------------------------------------------------------

POS_Constants.RECON_CAMCORDER_SCAN_RADIUS  = 40
POS_Constants.RECON_LOGGER_SCAN_RADIUS     = 25
POS_Constants.RECON_SCAN_INTERVAL_SECONDS  = 60
POS_Constants.RECON_LOGGER_INTERNAL_CAP    = 10

---------------------------------------------------------------
-- VHS tape parameters
---------------------------------------------------------------

POS_Constants.VHS_FACTORY_CAPACITY         = 20
POS_Constants.VHS_REFURBISHED_CAPACITY     = 15
POS_Constants.VHS_SPLICED_CAPACITY         = 8
POS_Constants.VHS_IMPROVISED_CAPACITY      = 4
POS_Constants.VHS_MIN_OPERATION_DAYS       = 3
POS_Constants.VHS_DEGRADATION_RATE_PCT     = 10

---------------------------------------------------------------
-- Tape confidence modifiers (basis points)
---------------------------------------------------------------

POS_Constants.VHS_CONFIDENCE_MOD_FACTORY      = 0
POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED  = -1000
POS_Constants.VHS_CONFIDENCE_MOD_SPLICED      = -2500
POS_Constants.VHS_CONFIDENCE_MOD_IMPROVISED   = -5000

---------------------------------------------------------------
-- Device inventory bonuses (when carried but not equipped)
---------------------------------------------------------------

POS_Constants.CAMCORDER_CARRY_CONFIDENCE_BONUS  = 1500   -- +15% in BPS
POS_Constants.LOGGER_CARRY_CONFIDENCE_BONUS     = 1000   -- +10% in BPS
POS_Constants.CALCULATOR_CARRY_CONFIDENCE_BONUS = 500    -- +5% in BPS

---------------------------------------------------------------
-- Camcorder noise
---------------------------------------------------------------

POS_Constants.CAMCORDER_NOISE_LEVEL_DEFAULT = 5

---------------------------------------------------------------
-- Tape modData keys
---------------------------------------------------------------

POS_Constants.MD_TAPE_ENTRIES     = "POS_TapeEntries"
POS_Constants.MD_TAPE_CAPACITY    = "POS_TapeCapacity"
POS_Constants.MD_TAPE_QUALITY     = "POS_TapeQuality"
POS_Constants.MD_TAPE_REGION      = "POS_TapeRegion"
POS_Constants.MD_TAPE_DURATION    = "POS_TapeDuration"
POS_Constants.MD_TAPE_ENTRY_COUNT = "POS_TapeEntryCount"
POS_Constants.MD_TAPE_WEAR        = "POS_TapeWear"

---------------------------------------------------------------
-- Intel gathering cooldown
---------------------------------------------------------------

POS_Constants.INTEL_COOLDOWN_DAYS_DEFAULT = 12
POS_Constants.INTEL_VISIT_KEY_PREFIX      = "POS_IntelVisit_"
POS_Constants.INTEL_CLEANUP_MULTIPLIER    = 2

---------------------------------------------------------------
-- VHS tape event log linking
---------------------------------------------------------------

POS_Constants.MD_TAPE_ID = "POS_TapeId"

---------------------------------------------------------------
-- VHS review at TV station
---------------------------------------------------------------

POS_Constants.VHS_REVIEW_TIME_PER_ENTRY    = 300
POS_Constants.VHS_REVIEW_SOURCE_LABEL      = "VHS Tape Review"
POS_Constants.NOTEBOOK_CONDITION_PER_NOTE  = 1

---------------------------------------------------------------
-- VHS media confidence threshold tiers (for resolveThresholdTier)
---------------------------------------------------------------

--- Sorted ascending by threshold. Used with PhobosLib.resolveThresholdTier().
--- confMod <= -2500 -> low, confMod <= -1000 -> medium, else -> high.
POS_Constants.VHS_CONFIDENCE_THRESHOLDS = {
    { threshold = POS_Constants.VHS_CONFIDENCE_MOD_SPLICED,     result = POS_Constants.CONFIDENCE_LOW },
    { threshold = POS_Constants.VHS_CONFIDENCE_MOD_REFURBISHED, result = POS_Constants.CONFIDENCE_MEDIUM },
}

-- NOTE: MICROCASSETTE_CONFIDENCE_THRESHOLDS and FLOPPY_CONFIDENCE_THRESHOLDS
-- are defined after their base constants (see below) to avoid
-- forward-reference nil errors during Lua load.

---------------------------------------------------------------
-- Data-Recorder screen IDs
---------------------------------------------------------------

POS_Constants.SCREEN_DATA_MANAGEMENT = "pos.data"

---------------------------------------------------------------
-- Data-Recorder item types
---------------------------------------------------------------

POS_Constants.ITEM_DATA_RECORDER          = "PhobosOperationalSignals.DataRecorder"
POS_Constants.ITEM_MICROCASSETTE          = "PhobosOperationalSignals.Microcassette"
POS_Constants.ITEM_RECORDED_MICROCASSETTE = "PhobosOperationalSignals.RecordedMicrocassette"
POS_Constants.ITEM_REWOUND_MICROCASSETTE  = "PhobosOperationalSignals.RewoundMicrocassette"
POS_Constants.ITEM_SPENT_MICROCASSETTE    = "PhobosOperationalSignals.SpentMicrocassette"
POS_Constants.ITEM_BLANK_FLOPPY_DISK     = "PhobosOperationalSignals.BlankFloppyDisk"
POS_Constants.ITEM_RECORDED_FLOPPY_DISK  = "PhobosOperationalSignals.RecordedFloppyDisk"
POS_Constants.ITEM_WORN_FLOPPY_DISK      = "PhobosOperationalSignals.WornFloppyDisk"
POS_Constants.ITEM_CORRUPT_FLOPPY_DISK   = "PhobosOperationalSignals.CorruptFloppyDisk"

---------------------------------------------------------------
-- Media family identifiers
---------------------------------------------------------------

POS_Constants.MEDIA_FAMILY_VHS          = "vhs"
POS_Constants.MEDIA_FAMILY_MICROCASSETTE = "microcassette"
POS_Constants.MEDIA_FAMILY_FLOPPY       = "floppy"

---------------------------------------------------------------
-- Media fidelity levels
---------------------------------------------------------------

POS_Constants.MEDIA_FIDELITY_STANDARD = "standard"
POS_Constants.MEDIA_FIDELITY_HIGH     = "high"
POS_Constants.MEDIA_FIDELITY_DIGITAL  = "digital"

---------------------------------------------------------------
-- Media capacity (entries)
---------------------------------------------------------------

POS_Constants.MICROCASSETTE_CAPACITY       = 10
POS_Constants.MICROCASSETTE_REWIND_CAP     = 10
POS_Constants.FLOPPY_CAPACITY              = 40

---------------------------------------------------------------
-- Media confidence modifiers (basis points)
---------------------------------------------------------------

POS_Constants.MICROCASSETTE_CONFIDENCE_MOD         = 1000
POS_Constants.MICROCASSETTE_REWOUND_CONFIDENCE_MOD = 500
POS_Constants.FLOPPY_CONFIDENCE_MOD                = 2000
POS_Constants.FLOPPY_WORN_CONFIDENCE_MOD           = 1000

--- Microcassette confidence thresholds (must be after base constant definitions).
--- confMod >= MICROCASSETTE_CONFIDENCE_MOD -> high, else -> medium.
POS_Constants.MICROCASSETTE_CONFIDENCE_THRESHOLDS = {
    { threshold = POS_Constants.MICROCASSETTE_CONFIDENCE_MOD - 1,
      result    = POS_Constants.CONFIDENCE_MEDIUM },
}

--- Floppy confidence thresholds (must be after base constant definitions).
--- confMod >= FLOPPY_CONFIDENCE_MOD -> high,
--- confMod >= FLOPPY_WORN_CONFIDENCE_MOD -> medium, else -> low.
POS_Constants.FLOPPY_CONFIDENCE_THRESHOLDS = {
    { threshold = POS_Constants.FLOPPY_WORN_CONFIDENCE_MOD - 1,
      result    = POS_Constants.CONFIDENCE_LOW },
    { threshold = POS_Constants.FLOPPY_CONFIDENCE_MOD - 1,
      result    = POS_Constants.CONFIDENCE_MEDIUM },
}

---------------------------------------------------------------
-- Data-Recorder modData keys
---------------------------------------------------------------

POS_Constants.MD_RECORDER_ID             = "POS_RecorderId"
POS_Constants.MD_RECORDER_BUFFER_COUNT   = "POS_RecorderBufferCount"
POS_Constants.MD_RECORDER_BUFFER_CAP     = "POS_RecorderBufferCapacity"
POS_Constants.MD_RECORDER_MEDIA_TYPE     = "POS_RecorderMediaType"
POS_Constants.MD_RECORDER_MEDIA_ID       = "POS_RecorderMediaId"
POS_Constants.MD_RECORDER_MEDIA_USED     = "POS_RecorderMediaUsed"
POS_Constants.MD_RECORDER_MEDIA_CAP      = "POS_RecorderMediaCapacity"
POS_Constants.MD_RECORDER_TOTAL_RECORDED = "POS_RecorderTotalRecorded"
POS_Constants.MD_RECORDER_LAST_REGION    = "POS_RecorderLastRegion"
POS_Constants.MD_RECORDER_POWERED        = "POS_RecorderPowered"
POS_Constants.MD_RECORDER_SOURCE_ID      = "POS_RecorderSourceId"
POS_Constants.MD_RECORDER_TUTORIAL_SHOWN = "POS_RecorderTutorialShown"
POS_Constants.MD_RECORDER_AUTO_FEED      = "POS_RecorderAutoFeed"

---------------------------------------------------------------
-- Media search order (shared between context menu, auto-feed,
-- and MediaManager.findUsableMedia). Priority: floppy (digital)
-- > microcassette (high) > VHS (best quality first).
---------------------------------------------------------------

POS_Constants.USABLE_MEDIA_SEARCH_ORDER = {
    POS_Constants.ITEM_BLANK_FLOPPY_DISK,
    POS_Constants.ITEM_RECORDED_FLOPPY_DISK,
    POS_Constants.ITEM_WORN_FLOPPY_DISK,
    POS_Constants.ITEM_MICROCASSETTE,
    POS_Constants.ITEM_RECORDED_MICROCASSETTE,
    POS_Constants.ITEM_REWOUND_MICROCASSETTE,
    POS_Constants.ITEM_BLANK_VHS_TAPE,
    POS_Constants.ITEM_REFURBISHED_TAPE,
    POS_Constants.ITEM_SPLICED_TAPE,
    POS_Constants.ITEM_IMPROVISED_TAPE,
}

POS_Constants.MEDIA_FAMILY_DISPLAY_ORDER = {
    POS_Constants.MEDIA_FAMILY_FLOPPY,
    POS_Constants.MEDIA_FAMILY_MICROCASSETTE,
    POS_Constants.MEDIA_FAMILY_VHS,
}

POS_Constants.MEDIA_FAMILY_LABEL_KEYS = {
    [POS_Constants.MEDIA_FAMILY_FLOPPY]       = "UI_POS_ContextMenu_FamilyFloppy",
    [POS_Constants.MEDIA_FAMILY_MICROCASSETTE] = "UI_POS_ContextMenu_FamilyMicrocassette",
    [POS_Constants.MEDIA_FAMILY_VHS]          = "UI_POS_ContextMenu_FamilyVHS",
}

---------------------------------------------------------------
-- Unified media modData keys (replaces POS_Tape* keys)
---------------------------------------------------------------

POS_Constants.MD_MEDIA_ID           = "POS_MediaId"
POS_Constants.MD_MEDIA_FAMILY       = "POS_MediaFamily"
POS_Constants.MD_MEDIA_ENTRY_COUNT  = "POS_MediaEntryCount"
POS_Constants.MD_MEDIA_CAPACITY     = "POS_MediaCapacity"
POS_Constants.MD_MEDIA_FIDELITY     = "POS_MediaFidelity"
POS_Constants.MD_MEDIA_CONF_MOD     = "POS_MediaConfidenceMod"
POS_Constants.MD_MEDIA_WEAR         = "POS_MediaWear"
POS_Constants.MD_MEDIA_REGION       = "POS_MediaRegion"
POS_Constants.MD_MEDIA_CYCLE_COUNT  = "POS_MediaCycleCount"
POS_Constants.MD_MEDIA_MIGRATED     = "POS_MediaMigrated"

---------------------------------------------------------------
-- Data chunk types
---------------------------------------------------------------

POS_Constants.CHUNK_TYPE_BUILDING_SCAN      = "building_scan"
POS_Constants.CHUNK_TYPE_RADIO_INTERCEPT    = "radio_intercept"
POS_Constants.CHUNK_TYPE_MARKET_OBSERVATION = "market_observation"
POS_Constants.CHUNK_TYPE_SIGNAL_PROBE       = "signal_probe"
POS_Constants.CHUNK_TYPE_ENVIRONMENTAL      = "environmental"

---------------------------------------------------------------
-- Data source categories
---------------------------------------------------------------

POS_Constants.DATA_SOURCE_RADIO   = "radio"
POS_Constants.DATA_SOURCE_RECON   = "recon"
POS_Constants.DATA_SOURCE_PASSIVE = "passive"

---------------------------------------------------------------
-- Device confidence base values (basis points)
---------------------------------------------------------------

POS_Constants.DEVICE_CONFIDENCE_CAMCORDER = 3000
POS_Constants.DEVICE_CONFIDENCE_LOGGER    = 1000
POS_Constants.DEVICE_CONFIDENCE_RECORDER  = 0

---------------------------------------------------------------
-- Recorder parameters
---------------------------------------------------------------

POS_Constants.RECORDER_INTERNAL_BUFFER_DEFAULT   = 8
POS_Constants.RECORDER_POWER_DRAIN_RATE_DEFAULT  = 50
POS_Constants.RECORDER_PROCESSING_TIME_DEFAULT   = 30
POS_Constants.RECORDER_CONDITION_BPS_PER_PERCENT = 50

---------------------------------------------------------------
-- Floppy disk corruption
---------------------------------------------------------------

POS_Constants.FLOPPY_CORRUPTION_CHANCE_DEFAULT = 5
POS_Constants.MICROCASSETTE_MAX_REWINDS_DEFAULT = 1

---------------------------------------------------------------
-- Data-Recorder event log types
---------------------------------------------------------------

POS_Constants.EVENT_RECORDER_CHUNK   = "recorder_chunk"
POS_Constants.EVENT_RECORDER_PROCESS = "recorder_process"
POS_Constants.EVENT_MEDIA_INSERT     = "media_insert"
POS_Constants.EVENT_MEDIA_EJECT      = "media_eject"

---------------------------------------------------------------
-- Confidence formula constants
---------------------------------------------------------------

POS_Constants.CONFIDENCE_MIN_EFFECTIVE  = 10
POS_Constants.CONFIDENCE_BASE_EFFECTIVE = 50
POS_Constants.CONFIDENCE_BPS_DIVISOR    = 100
