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
-- POS_BootSequence.lua
-- Manages the terminal boot sequence text.
--
-- Loads boot sequence definitions from Definitions/BootSequence/
-- via PhobosLib data-pack architecture. MP servers and addon mods
-- can override the default boot text by registering their own
-- definition with id "default" (allowOverwrite = true).
--
-- Tokens in boot lines are resolved at runtime:
--   %FREQ%    — connected frequency in MHz
--   %BAND%    — band name
--   %PLAYER%  — player display name
--   %SIGNAL%  — signal strength percentage
--   %RADIO%   — connected radio name
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_BootSequence = POS_BootSequence or {}

local _TAG = "BootSeq"

---------------------------------------------------------------
-- Registry
---------------------------------------------------------------

local _schema = require "POS_BootSequenceSchema"

local _registry = PhobosLib.createRegistry({
    name           = "BootSequences",
    schema         = _schema,
    idField        = "id",
    allowOverwrite = true,  -- MP servers can override default
    tag            = "[POS:BootSeq]",
})

local BUILTIN_PATHS = {
    "Definitions/BootSequence/default",
}

local _initialised = false

function POS_BootSequence.init()
    if _initialised then return end
    _initialised = true

    PhobosLib.loadDefinitions({
        registry = _registry,
        paths    = BUILTIN_PATHS,
        tag      = "[POS:BootSeq:Loader]",
    })

    PhobosLib.debug("POS", _TAG,
        "Loaded " .. _registry:count() .. " boot sequence(s)")
end

--- Get the boot sequence registry (for addon mods to register overrides).
---@return table PhobosLib registry
function POS_BootSequence.getRegistry()
    POS_BootSequence.init()
    return _registry
end

---------------------------------------------------------------
-- Token resolution
---------------------------------------------------------------

--- Resolve tokens in a boot line.
---@param line string Raw boot line with %TOKEN% placeholders
---@param ctx  table  { freq, band, player, signal, radio }
---@return string Resolved line
local function resolveTokens(line, ctx)
    local result = line
    if ctx.freq   then result = result:gsub("%%FREQ%%", ctx.freq) end
    if ctx.band   then result = result:gsub("%%BAND%%", ctx.band) end
    if ctx.player then result = result:gsub("%%PLAYER%%", ctx.player) end
    if ctx.signal then result = result:gsub("%%SIGNAL%%", ctx.signal) end
    if ctx.radio  then result = result:gsub("%%RADIO%%", ctx.radio) end
    return result
end

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Get the resolved boot lines for the current terminal connection.
---@param terminal table POS_TerminalUI instance
---@return table { lines, durationSeconds, postBootPauseSec, systemName }
function POS_BootSequence.getBootData(terminal)
    POS_BootSequence.init()

    local def = _registry:get("default")
    if not def then
        -- Fallback: minimal boot text
        return {
            lines = { "POSnet Terminal", "", "System ready.", ">_" },
            durationSeconds = 5,
            postBootPauseSec = 1.0,
            systemName = "POSNET BBS",
        }
    end

    -- Build token context from terminal state
    local player = getPlayer()
    local ctx = {
        freq   = string.format("%.1f", (terminal.frequency or 91500) / 1000),
        band   = terminal.band == "tactical" and "Tactical" or "Operations",
        player = player and player:getDisplayName() or "GUEST",
        signal = string.format("%.0f%%", (terminal.signalStrength or 1.0) * 100),
        radio  = terminal.radioName or "Radio",
    }

    -- Resolve tokens in each line
    local resolved = {}
    for _, line in ipairs(def.lines) do
        resolved[#resolved + 1] = resolveTokens(line, ctx)
    end

    return {
        lines            = resolved,
        durationSeconds  = def.durationSeconds or 15,
        postBootPauseSec = def.postBootPauseSec or 1.0,
        systemName       = def.systemName or "POSNET BBS",
    }
end
