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
-- POS_VoicePackRegistry.lua
-- Maps market agent archetype IDs to text pool overrides for
-- mission briefing sections.  Only "situation" and "submission"
-- sections are overridable per §32 design.
--
-- Voice packs change the *tone* of briefings (e.g. smuggler
-- uses shadier language) without altering mission structure.
---------------------------------------------------------------

require "POS_Constants"

POS_VoicePackRegistry = {}

---------------------------------------------------------------
-- Internal state
---------------------------------------------------------------

-- archetypeId -> { sectionName -> textPoolId }
local _overrides = {}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Register a voice pack override for an archetype.
--- Only sections listed in MISSION_VOICE_OVERRIDE_SECTIONS are accepted.
--- @param archetypeId string Market agent archetype ID
--- @param sectionName string Briefing section (e.g. "situation")
--- @param textPoolId string Text pool ID to use instead of default
function POS_VoicePackRegistry.register(archetypeId, sectionName, textPoolId)
    if not archetypeId or not sectionName or not textPoolId then return end

    -- Validate section is overridable
    local allowed = false
    for _, s in ipairs(POS_Constants.MISSION_VOICE_OVERRIDE_SECTIONS) do
        if s == sectionName then
            allowed = true
            break
        end
    end
    if not allowed then return end

    if not _overrides[archetypeId] then
        _overrides[archetypeId] = {}
    end
    _overrides[archetypeId][sectionName] = textPoolId
end

--- Get the text pool override for an archetype + section.
--- @param archetypeId string
--- @param sectionName string
--- @return string|nil Text pool ID, or nil for default
function POS_VoicePackRegistry.getOverride(archetypeId, sectionName)
    if not archetypeId or not _overrides[archetypeId] then return nil end
    return _overrides[archetypeId][sectionName]
end

--- Register all overrides from a voice pack definition table.
--- @param archetypeId string
--- @param overrides table Map of sectionName → textPoolId
function POS_VoicePackRegistry.registerPack(archetypeId, overrides)
    if not archetypeId or type(overrides) ~= "table" then return end
    for section, poolId in pairs(overrides) do
        POS_VoicePackRegistry.register(archetypeId, section, poolId)
    end
end

---------------------------------------------------------------
-- Built-in voice packs
---------------------------------------------------------------

local _builtInRegistered = false

--- Register built-in voice packs. Called lazily on first resolve.
function POS_VoicePackRegistry.initBuiltIn()
    if _builtInRegistered then return end
    _builtInRegistered = true

    -- Smuggler archetype uses shadier language for situations
    POS_VoicePackRegistry.registerPack("smuggler", {
        situation  = "voice_smuggler_situations",
    })

    -- Military logistics uses formal/terse language
    POS_VoicePackRegistry.registerPack("military_logistics", {
        situation  = "voice_military_situations",
    })

    -- Baseline trader uses mercantile language
    POS_VoicePackRegistry.registerPack("baseline_trader", {
        situation  = "voice_trader_situations",
    })
end
