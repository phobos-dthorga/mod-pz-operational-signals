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
-- POS_Screen_RelayCommand.lua
-- Tier V Strategic Relay terminal control screen.
-- Remote calibration, bandwidth allocation, relay dashboard,
-- and operational status for discovered relay sites.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Relay"
require "POS_TerminalWidgets"
require "POS_ScreenManager"
require "POS_StrategicRelayService"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:RelayCmd]"

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Build an ASCII bar string.
--- @param value  number  0.0-1.0
--- @param width  number  Character width of bar
--- @return string  Bar string like "[########--------] 65%"
local function _buildBar(value, width)
    local barLen = width or 20
    local filled = math.floor((value or 0) * barLen)
    if filled > barLen then filled = barLen end
    if filled < 0 then filled = 0 end
    return "[" .. string.rep("#", filled) .. string.rep("-", barLen - filled) .. "]"
end

--- Get network health word from calibration state value.
--- @param healthVal number  0.0-1.0
--- @return string translationKey, table colour
local function _getHealthLabel(healthVal, colours)
    if healthVal >= POS_Constants.RELAY_HEALTH_EXCELLENT then
        return "UI_POS_Relay_Health_Excellent", colours.success
    elseif healthVal >= POS_Constants.RELAY_HEALTH_GOOD then
        return "UI_POS_Relay_Health_Good", colours.success
    elseif healthVal >= POS_Constants.RELAY_HEALTH_DEGRADED then
        return "UI_POS_Relay_Health_Degraded", colours.warning
    elseif healthVal >= POS_Constants.RELAY_HEALTH_CRITICAL then
        return "UI_POS_Relay_Health_Critical", colours.error
    else
        return "UI_POS_Relay_Offline", colours.error
    end
end

--- Get the operational status label from calibration state.
--- @param calState number
--- @return string translationKey, table colour
local function _getOperationalLabel(calState, colours)
    if calState >= POS_Constants.RELAY_CALIBRATION_DEGRADED_THRESHOLD then
        return "UI_POS_Relay_Operational", colours.success
    elseif calState >= POS_Constants.RELAY_CALIBRATION_MIN_OPERATIONAL then
        return "UI_POS_Relay_Degraded", colours.warning
    else
        return "UI_POS_Relay_Offline", colours.error
    end
end

--- Find the first discovered relay site ID.
--- @return string|nil siteId
local function _getFirstRelaySiteId()
    local ok, relays = PhobosLib.safecall(POS_StrategicRelayService.getAllRelays)
    if not ok or not relays or #relays == 0 then return nil end
    return relays[1].siteId
end

--- Check wired link for the given relay from the player terminal.
--- @param siteId string
--- @return boolean
local function _hasWiredLink(siteId)
    -- Delegate to the service which uses Tier IV wiring validation
    -- via the relay's stored coordinates → getSquare → isWired
    local ok, linked = PhobosLib.safecall(
        POS_StrategicRelayService.isRelayLinked, siteId, nil)
    return ok and linked == true
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_RELAY_COMMAND
screen.menuPath = {"pos.network"}
screen.titleKey = "UI_POS_Relay_Title"
screen.sortOrder = 30
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_Relay_Title")

    local player = getSpecificPlayer(0)
    if not player then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Relay_NoRelay"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Find relay
    local siteId = _getFirstRelaySiteId()
    if not siteId then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Relay_NoRelay"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Check wired link (Tier V requires wired)
    if not _hasWiredLink(siteId) then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Relay_NoWiredLink"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Get relay status
    local ok, status = PhobosLib.safecall(
        POS_StrategicRelayService.getRelayStatus, siteId)
    if not ok or not status then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Relay_NoRelay"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -----------------------------------------------------------
    -- Section 1: Relay Dashboard
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Relay_Dashboard"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Site ID
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Relay_SiteId") .. ": " .. tostring(siteId), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Calibration bar
    local calState = status.calibrationState or 0
    local calPct = math.floor(calState * 100)
    local calColour
    if calState >= POS_Constants.RELAY_CALIBRATION_DEGRADED_THRESHOLD then
        calColour = C.success
    elseif calState >= POS_Constants.RELAY_CALIBRATION_MIN_OPERATIONAL then
        calColour = C.warning
    else
        calColour = C.error
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Relay_CalibrationState") .. ": "
        .. _buildBar(calState, 20) .. " " .. tostring(calPct) .. "%", calColour)
    ctx.y = ctx.y + ctx.lineH

    -- Network Health
    local healthVal = status.networkHealth or 0
    local healthKey, healthColour = _getHealthLabel(healthVal, C)
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Relay_NetworkHealth") .. ": "
        .. W.safeGetText(healthKey), healthColour)
    ctx.y = ctx.y + ctx.lineH

    -- Power Draw
    local powerDraw = status.powerDraw or 0
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Relay_PowerDraw") .. ": "
        .. string.format("%.2f kW/h", powerDraw), C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 2: Remote Calibration
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Relay_Calibration"), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    if status.isCalibrating then
        -- Calibration in progress
        local calProgress = status.calibrationProgress or 0
        local calProgPct = math.floor(calProgress * 100)
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_Relay_Calibrating") .. " "
            .. _buildBar(calProgress, 25) .. " " .. tostring(calProgPct) .. "%", C.textBright)
        ctx.y = ctx.y + ctx.lineH + 4

        -- CANCEL button
        local capturedSiteId = siteId
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[ " .. W.safeGetText("UI_POS_Relay_CancelCalibrate") .. " ]", nil,
            function()
                PhobosLib.safecall(
                    POS_StrategicRelayService.cancelCalibration, capturedSiteId)
                POS_ScreenManager.replaceCurrent(screen.id)
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    else
        -- CALIBRATE button
        local capturedSiteId = siteId
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[ " .. W.safeGetText("UI_POS_Relay_Calibrate") .. " ]", nil,
            function()
                PhobosLib.safecall(
                    POS_StrategicRelayService.calibrateRemote, player, capturedSiteId)
                POS_ScreenManager.replaceCurrent(screen.id)
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    end

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 3: Bandwidth Allocation
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Relay_Bandwidth"), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    local currentMode = status.bandwidthMode or POS_Constants.RELAY_BW_BALANCED

    for _, mode in ipairs(POS_Constants.RELAY_BW_MODES) do
        local modeKey = POS_Constants.RELAY_BW_MODE_KEYS[mode]
            or ("UI_POS_Relay_BW_" .. mode)
        local modeMult = POS_Constants.RELAY_BW_POWER_MULT[mode] or 1.0
        local isSelected = (currentMode == mode)

        local label = W.safeGetText(modeKey)
            .. "  (x" .. string.format("%.1f", modeMult) .. " "
            .. W.safeGetText("UI_POS_Relay_PowerDraw") .. ")"

        if isSelected then
            W.createLabel(ctx.panel, 8, ctx.y,
                "> " .. label .. "  " .. W.safeGetText("UI_POS_Relay_Selected"), C.textBright)
            ctx.y = ctx.y + ctx.lineH + 2
        else
            local capturedSiteId = siteId
            local capturedMode = mode
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                "  " .. label, nil,
                function()
                    PhobosLib.safecall(
                        POS_StrategicRelayService.setBandwidthMode,
                        capturedSiteId, capturedMode)
                    POS_ScreenManager.replaceCurrent(screen.id)
                end)
            ctx.y = ctx.y + ctx.btnH + 2
        end
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 4: Status Summary
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Relay_Status"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Operational status
    local opsKey, opsColour = _getOperationalLabel(calState, C)
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Relay_Operational") .. ": "
        .. W.safeGetText(opsKey), opsColour)
    ctx.y = ctx.y + ctx.lineH

    -- Power breakdown
    local basePower = POS_Constants.RELAY_POWER_IDLE
    local modePower = status.powerDraw or POS_Constants.RELAY_POWER_IDLE
    W.createLabel(ctx.panel, 8, ctx.y,
        "  Base:  " .. string.format("%.2f kW/h", basePower), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  Mode:  " .. string.format("%.2f kW/h", modePower), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  Total: " .. string.format("%.2f kW/h", basePower + modePower), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Footer
    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------

function screen.destroy()
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------
-- ContextPanel
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}

    table.insert(data, { type = "header", text = "UI_POS_Relay_Title" })
    table.insert(data, { type = "separator" })

    local siteId = _getFirstRelaySiteId()
    if not siteId then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Relay_Status"),
            value = PhobosLib.safeGetText("UI_POS_Relay_NoRelay") })
        return data
    end

    local ok, status = PhobosLib.safecall(
        POS_StrategicRelayService.getRelayStatus, siteId)
    if not ok or not status then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Relay_Status"),
            value = PhobosLib.safeGetText("UI_POS_Relay_NoRelay") })
        return data
    end

    -- Calibration %
    local calPct = math.floor((status.calibrationState or 0) * 100)
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Relay_CalibrationState"),
        value = tostring(calPct) .. "%" })

    -- Bandwidth mode
    local modeKey = POS_Constants.RELAY_BW_MODE_KEYS[status.bandwidthMode]
        or "UI_POS_Relay_BW_Balanced"
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Relay_Bandwidth"),
        value = PhobosLib.safeGetText(modeKey) })

    -- Network health
    local healthVal = status.networkHealth or 0
    local healthKey = _getHealthLabel(healthVal, POS_TerminalWidgets.COLOURS)
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Relay_NetworkHealth"),
        value = PhobosLib.safeGetText(healthKey) })

    -- Power draw
    table.insert(data, { type = "kv",
        key = PhobosLib.safeGetText("UI_POS_Relay_PowerDraw"),
        value = string.format("%.2f kW/h", status.powerDraw or 0) })

    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
