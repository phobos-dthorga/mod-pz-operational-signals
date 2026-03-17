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
-- POS_Screen_Stockmarket.lua
-- Placeholder "COMING SOON" screen for the Stockmarket feature.
---------------------------------------------------------------

require "PhobosLib"
require "POS_ScreenManager"

local function safeGetText(key, ...)
    local ok, result = pcall(getText, key, ...)
    if ok and result then return result end
    return key
end

local TERM = {
    text   = { r = 0.20, g = 0.90, b = 0.20 },
    dim    = { r = 0.12, g = 0.50, b = 0.12 },
    header = { r = 0.30, g = 1.00, b = 0.30 },
    warn   = { r = 0.90, g = 0.80, b = 0.10 },
}

---------------------------------------------------------------

local screen = {}
screen.id = "STOCKMARKET_PLACEHOLDER"

function screen.rebuildLines(_terminal, _params)
    local lines = {}
    local hitZones = {}

    table.insert(lines, { text = safeGetText("UI_POS_Stock_Header"), colour = TERM.header })
    table.insert(lines, { text = string.rep("=", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = "     " .. safeGetText("UI_POS_Stock_ComingSoon"), colour = TERM.warn })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = "  " .. safeGetText("UI_POS_Stock_Message"), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = "", colour = TERM.text })
    table.insert(lines, { text = string.rep("-", 40), colour = TERM.dim })
    table.insert(lines, { text = "", colour = TERM.text })

    local backIdx = #lines + 1
    table.insert(lines, { text = "[0] " .. safeGetText("UI_POS_BackPrompt"), colour = TERM.text })
    table.insert(hitZones, { lineIndex = backIdx, actionId = "back" })

    return lines, hitZones
end

function screen.onAction(_terminal, actionId, _data)
    if actionId == "back" then
        POS_ScreenManager.goBack()
    end
end

---------------------------------------------------------------

POS_ScreenManager.registerScreen(screen)
