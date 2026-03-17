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
-- POS_ScreenManager.lua
-- Screen state machine for the POSnet terminal.
-- Manages screen registry, navigation stack, content building,
-- and clickable hit-zone detection.
---------------------------------------------------------------

require "PhobosLib"

POS_ScreenManager = {}

--- Registry of screen definitions keyed by screen ID.
--- Each entry: { id, rebuildLines(terminal, params), onAction(terminal, actionId, data) }
POS_ScreenManager.screens = {}

--- Current screen ID.
POS_ScreenManager.currentScreen = nil

--- Current screen parameters (passed during navigateTo).
POS_ScreenManager.currentParams = nil

--- Navigation stack for "back" functionality.
--- Each entry: { screenId, params }
POS_ScreenManager.navigationStack = {}

--- Current hit zones (populated by rebuildLines).
--- Each entry: { lineIndex, actionId, data }
POS_ScreenManager.hitZones = {}

--- Dirty flag — set when screen needs rebuild.
POS_ScreenManager.dirty = true

---------------------------------------------------------------
-- Screen registration
---------------------------------------------------------------

--- Register a screen definition.
---@param definition table { id, rebuildLines(terminal, params), onAction(terminal, actionId, data) }
function POS_ScreenManager.registerScreen(definition)
    if not definition or not definition.id then
        print("[POS:ScreenMgr] registerScreen: missing id")
        return
    end
    POS_ScreenManager.screens[definition.id] = definition
    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "registered screen: " .. definition.id)
end

---------------------------------------------------------------
-- Navigation
---------------------------------------------------------------

--- Navigate to a screen, pushing current screen onto the stack.
---@param screenId string Target screen ID
---@param params table|nil Optional parameters for the target screen
function POS_ScreenManager.navigateTo(screenId, params)
    if not POS_ScreenManager.screens[screenId] then
        print("[POS:ScreenMgr] navigateTo: unknown screen '" .. tostring(screenId) .. "'")
        return
    end

    -- Push current screen to stack (if we have one)
    if POS_ScreenManager.currentScreen then
        table.insert(POS_ScreenManager.navigationStack, {
            screenId = POS_ScreenManager.currentScreen,
            params   = POS_ScreenManager.currentParams,
        })
    end

    POS_ScreenManager.currentScreen = screenId
    POS_ScreenManager.currentParams = params
    POS_ScreenManager.dirty = true
    POS_ScreenManager.hitZones = {}

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated to: " .. screenId .. " (stack depth: "
        .. tostring(#POS_ScreenManager.navigationStack) .. ")")
end

--- Go back to the previous screen. No-op if stack is empty.
function POS_ScreenManager.goBack()
    local stack = POS_ScreenManager.navigationStack
    if #stack == 0 then return end

    local prev = table.remove(stack)
    POS_ScreenManager.currentScreen = prev.screenId
    POS_ScreenManager.currentParams = prev.params
    POS_ScreenManager.dirty = true
    POS_ScreenManager.hitZones = {}

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated back to: " .. prev.screenId)
end

--- Reset navigation to a specific screen, clearing the stack.
---@param screenId string Target screen ID
function POS_ScreenManager.resetTo(screenId)
    POS_ScreenManager.navigationStack = {}
    POS_ScreenManager.currentScreen = nil
    POS_ScreenManager.currentParams = nil
    POS_ScreenManager.navigateTo(screenId)
end

---------------------------------------------------------------
-- Content building
---------------------------------------------------------------

--- Rebuild lines if dirty. Called by POS_TerminalUI each frame
--- (throttled to every 30 frames by the terminal itself).
---@param terminal table POS_TerminalUI instance
---@return table Array of {text, colour} lines
function POS_ScreenManager.rebuildIfNeeded(terminal)
    if not POS_ScreenManager.dirty then
        return terminal.cachedLines
    end

    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if not screen or not screen.rebuildLines then
        terminal.cachedLines = {}
        POS_ScreenManager.hitZones = {}
        POS_ScreenManager.dirty = false
        return terminal.cachedLines
    end

    local lines, hitZones = screen.rebuildLines(terminal, POS_ScreenManager.currentParams)
    terminal.cachedLines = lines or {}
    POS_ScreenManager.hitZones = hitZones or {}
    POS_ScreenManager.dirty = false

    return terminal.cachedLines
end

--- Force a rebuild on the next frame.
function POS_ScreenManager.markDirty()
    POS_ScreenManager.dirty = true
end

---------------------------------------------------------------
-- Click handling
---------------------------------------------------------------

--- Handle a mouse click on the terminal, mapping Y position to hit zones.
---@param terminal table POS_TerminalUI instance
---@param mouseX number Mouse X relative to window
---@param mouseY number Mouse Y relative to window
---@return boolean True if click was consumed
function POS_ScreenManager.handleClick(terminal, mouseX, mouseY)
    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if not screen then return false end

    -- Calculate which line was clicked
    local th = terminal:titleBarHeight()
    local pad = 16
    local lh = terminal._lineHeight or 16
    local contentY = mouseY - th - pad + (terminal.scrollOffset or 0)

    if contentY < 0 then return false end

    local lineIndex = math.floor(contentY / lh) + 1

    -- Check hit zones for this line
    for _, zone in ipairs(POS_ScreenManager.hitZones) do
        if zone.lineIndex == lineIndex then
            if screen.onAction then
                screen.onAction(terminal, zone.actionId, zone.data)
                return true
            end
        end
    end

    return false
end
