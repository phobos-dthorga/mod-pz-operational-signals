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
-- POS_MenuBuilder.lua
-- Generates menu entries from the registry for display in
-- terminal screens.
--
-- Queries POS_Registry for screens matching a given menuPath,
-- evaluates `requires` and `canOpen` gates, and returns an
-- ordered list of { def, enabled, reason } entries.
---------------------------------------------------------------

require "POS_Registry"
require "POS_API"

POS_MenuBuilder = {}

--- Build a menu for the given path.
--- Returns an ordered list of { def, enabled, reason } entries.
--- Each entry has:
---   def — the full screen definition from POS_Registry
---   enabled — boolean, true if canOpen passes
---   reason — string translation key if disabled, nil if enabled
function POS_MenuBuilder.buildMenu(menuPath, player, ctx)
    local entries = POS_Registry.getMenuEntries(menuPath, player, ctx)
    local result = {}

    for _, def in ipairs(entries) do
        local enabled = true
        local reason = nil

        -- Check requires first
        if def.requires then
            local ok, r = POS_API.checkRequires(def.requires, ctx or {})
            if not ok then
                enabled = false
                reason = r
            end
        end

        -- Then check canOpen
        if enabled and def.canOpen then
            local pcallOk, canOpenResult, canOpenReason = pcall(def.canOpen, player, ctx or {})
            if pcallOk then
                if canOpenResult == false then
                    enabled = false
                    reason = canOpenReason
                end
            else
                enabled = false
                reason = POS_Constants.ERR_EXTENSION_FAIL
            end
        end

        table.insert(result, {
            def = def,
            enabled = enabled,
            reason = reason,
        })
    end

    return result
end
