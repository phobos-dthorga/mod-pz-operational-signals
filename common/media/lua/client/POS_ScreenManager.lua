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
-- Manages screen registry, navigation stack, and content.
--
-- Supports two screen types (backward compatible):
--   Legacy: { id, rebuildLines(), onAction() }  — line-based
--   Widget: { id, create(), destroy(), refresh() } — widget-based
---------------------------------------------------------------

require "PhobosLib"

-- Guard: Screen files load alphabetically before this file and use
-- require "POS_ScreenManager" to pull it in. If PZ's auto-loader then
-- re-executes this file, we must not wipe already-registered screens.
POS_ScreenManager = POS_ScreenManager or {}

--- Registry of screen definitions keyed by screen ID.
--- Legacy: { id, rebuildLines(terminal, params), onAction(terminal, actionId, data) }
--- Widget: { id, create(contentPanel, params, terminal), destroy(), refresh(params) }
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

--- Current hit zones (populated by rebuildLines).
--- Each entry: { lineIndex, actionId, data }
POS_ScreenManager.hitZones = POS_ScreenManager.hitZones or {}

--- Dirty flag — set when screen needs rebuild.
if POS_ScreenManager.dirty == nil then
    POS_ScreenManager.dirty = true
end

---------------------------------------------------------------
-- Screen registration
---------------------------------------------------------------

--- Check if a screen definition uses the widget-based lifecycle.
---@param screen table Screen definition
---@return boolean True if widget-based (has create/destroy)
local function isWidgetScreen(screen)
    return screen and screen.create ~= nil
end

--- Destroy the current widget-based screen (if applicable).
local function destroyCurrentScreen()
    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]
    if screen and isWidgetScreen(screen) and screen.destroy then
        pcall(screen.destroy)
    end
end

--- Create a widget-based screen in the content panel.
---@param screenId string Screen ID to create
---@param params table|nil Screen parameters
local function createWidgetScreen(screenId, params)
    local screen = POS_ScreenManager.screens[screenId]
    if not screen or not isWidgetScreen(screen) then return end
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    if not terminal or not terminal.contentPanel then return end
    pcall(screen.create, terminal.contentPanel, params, terminal)
end

--- Register a screen definition.
--- Supports both legacy (rebuildLines/onAction) and widget (create/destroy/refresh).
---@param definition table Screen definition with id field
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

    -- Destroy current widget screen before switching
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
    POS_ScreenManager.dirty = true
    POS_ScreenManager.hitZones = {}

    -- Create new widget screen (no-op for legacy screens)
    createWidgetScreen(screenId, params)

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated to: " .. screenId .. " (stack depth: "
        .. tostring(#POS_ScreenManager.navigationStack) .. ")")
end

--- Go back to the previous screen. No-op if stack is empty.
function POS_ScreenManager.goBack()
    local stack = POS_ScreenManager.navigationStack
    if #stack == 0 then return end

    -- Destroy current widget screen before going back
    destroyCurrentScreen()

    local prev = table.remove(stack)
    POS_ScreenManager.currentScreen = prev.screenId
    POS_ScreenManager.currentParams = prev.params
    POS_ScreenManager.dirty = true
    POS_ScreenManager.hitZones = {}

    -- Create previous widget screen (no-op for legacy screens)
    createWidgetScreen(prev.screenId, prev.params)

    PhobosLib.debug("POS", "[POS:ScreenMgr]",
        "navigated back to: " .. prev.screenId)
end

--- Reset navigation to a specific screen, clearing the stack.
---@param screenId string Target screen ID
function POS_ScreenManager.resetTo(screenId)
    -- Destroy current widget screen before reset
    destroyCurrentScreen()
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
--- Widget-based screens handle their own content via child widgets,
--- so this only runs for legacy line-based screens.
---@param terminal table POS_TerminalUI instance
---@return table Array of {text, colour} lines
function POS_ScreenManager.rebuildIfNeeded(terminal)
    if not POS_ScreenManager.dirty then
        return terminal.cachedLines
    end

    local screen = POS_ScreenManager.screens[POS_ScreenManager.currentScreen]

    -- Widget screens: call refresh instead of rebuildLines
    if screen and isWidgetScreen(screen) then
        if screen.refresh then
            pcall(screen.refresh, POS_ScreenManager.currentParams)
        end
        terminal.cachedLines = {}
        POS_ScreenManager.hitZones = {}
        POS_ScreenManager.dirty = false
        return terminal.cachedLines
    end

    -- Legacy screens: rebuild lines as before
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

    -- Widget screens handle clicks via their own ISButton/ISPanel children
    if isWidgetScreen(screen) then return false end

    -- Legacy: calculate which line was clicked using screen rect
    local sx, sy, sw, sh = terminal:getScreenRect()
    local pad = 8  -- matches SCREEN_PAD in POS_TerminalUI
    local lh = terminal._lineHeight or 16
    local contentY = mouseY - sy - pad + (terminal.scrollOffset or 0)

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
