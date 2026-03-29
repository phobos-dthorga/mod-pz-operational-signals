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
-- Definitions/ReceiverProfiles/vanilla_radios.lua
-- Receiver quality profiles for all 17 vanilla PZ radio items.
-- baseFactor: dropout multiplier at pristine condition.
--   0.20 = best (military), 0.95 = worst (makeshift).
--
-- Addon mods can register profiles for custom radio items via:
--   POS_ReceiverProfileRegistry.getRegistry():register({...})
--   POS_ReceiverProfileRegistry.rebuildIndex()
--
-- See design-guidelines.md §60 for receiver quality architecture.
---------------------------------------------------------------

return {
    -- Military / high-end ham (Excellent tier: factor 0.20)
    {
        schemaVersion = 1,
        id            = "manpack_radio",
        fullType      = "Base.ManPackRadio",
        category      = "ham",
        baseFactor    = 0.20,
        description   = "Military-grade receiver with exceptional sensitivity",
    },
    {
        schemaVersion = 1,
        id            = "ham_radio_2",
        fullType      = "Base.HamRadio2",
        category      = "ham",
        baseFactor    = 0.20,
        description   = "High-end ham radio with excellent reception",
    },

    -- Upper-tier handheld / mid ham (Good tier: factor 0.44-0.64)
    {
        schemaVersion = 1,
        id            = "walkie_talkie_5",
        fullType      = "Base.WalkieTalkie5",
        category      = "handheld",
        baseFactor    = 0.44,
        description   = "Top-tier walkie-talkie with strong reception",
    },
    {
        schemaVersion = 1,
        id            = "ham_radio_1",
        fullType      = "Base.HamRadio1",
        category      = "ham",
        baseFactor    = 0.64,
        description   = "Entry-level ham radio with decent reception",
    },

    -- Mid-tier handheld (Fair tier: factor 0.72-0.86)
    {
        schemaVersion = 1,
        id            = "walkie_talkie_4",
        fullType      = "Base.WalkieTalkie4",
        category      = "handheld",
        baseFactor    = 0.72,
        description   = "Upper-mid walkie-talkie",
    },
    {
        schemaVersion = 1,
        id            = "ham_radio_makeshift",
        fullType      = "Base.HamRadioMakeShift",
        category      = "ham",
        baseFactor    = 0.84,
        isMakeshift   = true,
        description   = "Makeshift ham radio — reduced sensitivity",
    },
    {
        schemaVersion = 1,
        id            = "walkie_talkie_3",
        fullType      = "Base.WalkieTalkie3",
        category      = "handheld",
        baseFactor    = 0.86,
        description   = "Mid-range walkie-talkie",
    },

    -- Low-tier handheld / makeshift (Poor tier: factor 0.93-0.95)
    {
        schemaVersion = 1,
        id            = "walkie_talkie_2",
        fullType      = "Base.WalkieTalkie2",
        category      = "handheld",
        baseFactor    = 0.93,
        description   = "Low-range walkie-talkie with weak reception",
    },
    {
        schemaVersion = 1,
        id            = "walkie_talkie_makeshift",
        fullType      = "Base.WalkieTalkieMakeShift",
        category      = "handheld",
        baseFactor    = 0.95,
        isMakeshift   = true,
        description   = "Makeshift walkie-talkie — worst portable receiver",
    },
    {
        schemaVersion = 1,
        id            = "walkie_talkie_1",
        fullType      = "Base.WalkieTalkie1",
        category      = "handheld",
        baseFactor    = 0.95,
        description   = "Basic walkie-talkie with minimal reception range",
    },

    -- Commercial receivers (Fair tier: factor 0.75)
    {
        schemaVersion = 1,
        id            = "radio_black",
        fullType      = "Base.RadioBlack",
        category      = "commercial",
        baseFactor    = 0.75,
        description   = "Commercial FM receiver",
    },
    {
        schemaVersion = 1,
        id            = "radio_red",
        fullType      = "Base.RadioRed",
        category      = "commercial",
        baseFactor    = 0.75,
        description   = "Commercial FM receiver",
    },
    {
        schemaVersion = 1,
        id            = "radio_makeshift",
        fullType      = "Base.RadioMakeShift",
        category      = "commercial",
        baseFactor    = 0.90,
        isMakeshift   = true,
        description   = "Makeshift FM receiver — poor reception quality",
    },
    {
        schemaVersion = 1,
        id            = "cd_player",
        fullType      = "Base.CDplayer",
        category      = "commercial",
        baseFactor    = 0.75,
        description   = "CD player with basic FM receiver",
    },

    -- Television sets (Fair tier: factor 0.75)
    {
        schemaVersion = 1,
        id            = "tv_antique",
        fullType      = "Base.TvAntique",
        category      = "tv",
        baseFactor    = 0.75,
        description   = "Antique television — grid-powered broadcast receiver",
    },
    {
        schemaVersion = 1,
        id            = "tv_black",
        fullType      = "Base.TvBlack",
        category      = "tv",
        baseFactor    = 0.75,
        description   = "Standard television — grid-powered broadcast receiver",
    },
    {
        schemaVersion = 1,
        id            = "tv_widescreen",
        fullType      = "Base.TvWideScreen",
        category      = "tv",
        baseFactor    = 0.75,
        description   = "Widescreen television — grid-powered broadcast receiver",
    },
}
