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
-- Manages screen registry, navigation stack, and widget lifecycle.
--
-- All screens use the widget-based lifecycle:
--   { id, create(contentPanel, params, terminal),
--     destroy(), refresh(params) }
---------------------------------------------------------------

require "PhobosLib"

-- Guard: Screen files load alphabetically before this file and use
-- require "POS_ScreenManager" to pull it in. If PZ's auto-loader then
-- re-executes this file, we must not wipe already-registered screens.
POS_ScreenManager = POS_ScreenManager or {}

--- Registry of screen definitions keyed by screen ID.
--- { id, create(contentPanel, params, terminal), destroy(), refresh(params) }
POS_ScreenManager.screens = POS_ScreenManager.screens or {}

--- Current screen ID.
if POS_ScreenManager.currentScreen == nil then
    POS_ScreenManager.currentScreen = nil
end

--- Current screen parameters (passed during navigateTo).
if POS_ScreenManager.currentParams == nil then
    POS_ScreenManager.currentParams = nil
end

--- Navigation stack for "back" functionality.
--- Each entry: { screenId, params }
POS_ScreenManager.navigationStack = POS_ScreenManager.navigationStack or {}

--- Dirty flag — set when screen needs refresh.
if POS_ScreenManager.dirty == nil then
    POS_ScreenManager.dirty = true
end

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

--- Destroy the current screen's widgets (if applicable).
local function destroyCurrentScreen()
    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if screen and screen.destroy then
        pcall(screen.destroy)
    end
end

--- Create a screen's widgets in the content panel.
---@param screenId string Screen ID to create
---@param params table|nil Screen parameters
local function createWidgetScreen(screenId, params)
    local screen = POS_ScreenManager.screens[screenId]
    if not screen or not screen.create then return end
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    if not terminal or not terminal.contentPanel then return end
    pcall(screen.create, terminal.contentPanel, params, terminal)
end

---------------------------------------------------------------
-- Screen registration
---------------------------------------------------------------

--- Register a screen definition.
---@param definition table { id, create(), destroy(), refresh() }
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

    -- Destroy current screen before switching
    destroyCurrentScreen()

    -- Push current screen to stack (if we have one)
    if POS_ScreenManager.currentScreen then
        table.insert(POS_ScreenManager.navigationStack, {
            screenId = POS_ScreenManager.currentScreen,
            params   = POS_ScreenManager.currentParams,
        })
    end

    POS_ScreenManager.currentScreen = screenId
    POS_ScreenManager.currentParams = params
    POS_ScreenManager.dirty = false

    -- Create new screen widgets
    createWidgetScreen(screenId, params)

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated to: " .. screenId .. " (stack depth: "
        .. tostring(#POS_ScreenManager.navigationStack) .. ")")
end

--- Go back to the previous screen. No-op if stack is empty.
function POS_ScreenManager.goBack()
    local stack = POS_ScreenManager.navigationStack
    if #stack == 0 then return end

    -- Destroy current screen before going back
    destroyCurrentScreen()

    local prev = table.remove(stack)
    POS_ScreenManager.currentScreen = prev.screenId
    POS_ScreenManager.currentParams = prev.params
    POS_ScreenManager.dirty = false

    -- Create previous screen widgets
    createWidgetScreen(prev.screenId, prev.params)

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated back to: " .. prev.screenId)
end

--- Replace the current screen without pushing to the navigation stack.
--- Used for pagination — avoids cluttering the back-button history.
---@param screenId string Target screen ID
---@param params table|nil Optional parameters for the target screen
function POS_ScreenManager.replaceCurrent(screenId, params)
    if not POS_ScreenManager.screens[screenId] then
        print("[POS:ScreenMgr] replaceCurrent: unknown screen '" .. tostring(screenId) .. "'")
        return
    end

    destroyCurrentScreen()

    POS_ScreenManager.currentScreen = screenId
    POS_ScreenManager.currentParams = params
    POS_ScreenManager.dirty = false

    createWidgetScreen(screenId, params)

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "replaced current with: " .. screenId)
end

--- Reset navigation to a specific screen, clearing the stack.
---@param screenId string Target screen ID
function POS_ScreenManager.resetTo(screenId)
    -- Destroy current screen before reset
    destroyCurrentScreen()
    POS_ScreenManager.navigationStack = {}
    POS_ScreenManager.currentScreen = nil
    POS_ScreenManager.currentParams = nil
    POS_ScreenManager.navigateTo(screenId)
end

---------------------------------------------------------------
-- Refresh
---------------------------------------------------------------

--- Refresh the current screen if dirty. Called by POS_TerminalUI.
---@param _terminal table POS_TerminalUI instance (unused, kept for compat)
function POS_ScreenManager.refreshIfNeeded(_terminal)
    if not POS_ScreenManager.dirty then return end

    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if screen and screen.refresh then
        pcall(screen.refresh, POS_ScreenManager.currentParams)
    end
    POS_ScreenManager.dirty = false
end

--- Force a refresh on the next frame.
function POS_ScreenManager.markDirty()
    POS_ScreenManager.dirty = true
end
