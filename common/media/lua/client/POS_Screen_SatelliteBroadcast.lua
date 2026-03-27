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
-- POS_Screen_SatelliteBroadcast.lua
-- Satellite broadcast terminal screen (Tier IV).
-- Select broadcast mode, compiled intelligence artifact,
-- preview signal strength, and transmit via satellite dish.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Satellite"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_SatelliteService"
require "POS_SIGINTSkill"
require "POS_SignalEcologyService"
require "POS_Events"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:SatBroadcast]"

-- Refresh subscription tracking (§58 Screen Refresh Pattern)
local _refreshListeners = {}

local function _subscribe(event, fn)
    if event and event.addListener then
        event:addListener(fn)
        _refreshListeners[#_refreshListeners + 1] = { event = event, fn = fn }
    end
end

-- State tracking
local _selectedMode = nil
local _selectedArtifactIdx = nil
local _isTransmitting = false
local _transmitProgress = 0
local _transmitStartTime = 0

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Build the broadcast mode list with display data.
--- @return table Array of {id, labelKey, riskSuffix}
local function _getModeEntries()
    return {
        { id = POS_Constants.SAT_MODE_SCARCITY,      labelKey = "UI_POS_Satellite_Mode_Scarcity" },
        { id = POS_Constants.SAT_MODE_SURPLUS,        labelKey = "UI_POS_Satellite_Mode_Surplus" },
        { id = POS_Constants.SAT_MODE_ROUTE_WARNING,  labelKey = "UI_POS_Satellite_Mode_RouteWarning" },
        { id = POS_Constants.SAT_MODE_CONTACT,        labelKey = "UI_POS_Satellite_Mode_Contact" },
        { id = POS_Constants.SAT_MODE_RUMOUR,          labelKey = "UI_POS_Satellite_Mode_Rumour",
          riskSuffix = true },
    }
end

--- Find compiled intelligence artifacts in player inventory.
--- @param player IsoPlayer
--- @return table Array of InventoryItem with POS_Intelligence tag
-- Known artifact fullType strings (avoids hasTag which crashes on
-- Clothing/HandWeapon/etc in PZ Build 42's Kahlua bridge).
local ARTIFACT_TYPES = {
    ["PhobosOperationalSignals.CompiledSiteSurvey"]  = true,
    ["PhobosOperationalSignals.CompiledMarketReport"] = true,
    ["PhobosOperationalSignals.MarketBulletin"]       = true,
}

local function _findArtifacts(player)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end
    local items = inv:getItems()
    if not items then return {} end

    local result = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType then
            local fullType = item:getFullType()
            if fullType and ARTIFACT_TYPES[fullType] then
                result[#result + 1] = item
            end
        end
    end
    return result
end

--- Build an ASCII bar string.
--- @param value  number  0.0-1.0
--- @param width  number  Character width of bar
--- @return string  Bar string like "[####....]"
local function _buildBar(value, width)
    local barLen = width or 20
    local filled = math.floor((value or 0) * barLen)
    if filled > barLen then filled = barLen end
    if filled < 0 then filled = 0 end
    return "[" .. string.rep("#", filled) .. string.rep(".", barLen - filled) .. "]"
end

--- Get the gate reason why transmit is blocked, or nil if clear.
--- @param status  table  From POS_SatelliteService.getStatus()
--- @return string|nil  Translation key for the gate reason
local function _getTransmitGate(status)
    if not status then return "UI_POS_Satellite_NoDish" end
    if not status.calibrated then return "UI_POS_Satellite_NotCalibrated" end
    if not status.powered then return "UI_POS_Satellite_NoPower" end
    if status.onCooldown then return "UI_POS_Satellite_OnCooldown" end
    if not _selectedMode then return "UI_POS_Satellite_NoMode" end
    if not _selectedArtifactIdx then return "UI_POS_Satellite_NoArtifactSelected" end
    return nil
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_SATELLITE_BROADCAST
screen.menuPath = {"pos.network"}
screen.titleKey = "UI_POS_Satellite_Title"
screen.sortOrder = 10
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Restore state from params
    _selectedMode = (params and params.selectedMode) or _selectedMode
    _selectedArtifactIdx = (params and params.selectedArtifact) or _selectedArtifactIdx

    -- Header
    W.drawHeader(ctx, "UI_POS_Satellite_Title")

    local player = getSpecificPlayer(0)
    if not player then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_NoDish"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    local ok, status = PhobosLib.safecall(POS_SatelliteService.getStatus)
    if not ok or not status then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_NoDish"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -----------------------------------------------------------
    -- Transmitting view (replaces sections 2-5)
    -----------------------------------------------------------
    if _isTransmitting then
        -- Mode + artifact labels
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_Transmitting"), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        if _selectedMode then
            W.createLabel(ctx.panel, 8, ctx.y,
                W.safeGetText("UI_POS_Satellite_BroadcastMode") .. ": "
                .. W.safeGetText("UI_POS_Satellite_Mode_" .. _selectedMode), C.text)
            ctx.y = ctx.y + ctx.lineH
        end

        ctx.y = ctx.y + 4
        W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
        ctx.y = ctx.y + ctx.lineH

        -- Upload progress bar
        local elapsed = getGameTime():getWorldAgeHours() - _transmitStartTime
        local duration = POS_Constants.SATELLITE_BROADCAST_TIME_DEFAULT / 3600
        if duration > 0 then
            _transmitProgress = math.min(elapsed / duration, 1.0)
        end

        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_Progress") .. " "
            .. _buildBar(_transmitProgress, 30) .. " "
            .. string.format("%.0f%%", _transmitProgress * 100), C.textBright)
        ctx.y = ctx.y + ctx.lineH

        -- Signal quality bar
        local sigOk, sigQuality = PhobosLib.safecall(POS_SignalEcologyService.getQuality)
        local sigVal = (sigOk and type(sigQuality) == "number") and sigQuality or 0
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_Signal") .. "  "
            .. _buildBar(sigVal, 20) .. " "
            .. string.format("%.0f%%", sigVal * 100), C.text)
        ctx.y = ctx.y + ctx.lineH

        -- Time remaining
        local remaining = math.max(0, duration - elapsed)
        local remMin = math.floor(remaining * 60)
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_TimeRemaining") .. ": "
            .. tostring(remMin) .. " min", C.dim)
        ctx.y = ctx.y + ctx.lineH + 4

        -- Abort button
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            W.safeGetText("UI_POS_Satellite_Abort"), nil,
            function()
                _isTransmitting = false
                _transmitProgress = 0
                _transmitStartTime = 0
                POS_ScreenManager.replaceCurrent(screen.id,
                    { selectedMode = _selectedMode, selectedArtifact = _selectedArtifactIdx })
            end)
        ctx.y = ctx.y + ctx.btnH + 4

        W.drawFooter(ctx)
        return
    end

    -----------------------------------------------------------
    -- Section 1: Dish Status
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Satellite_DishStatus"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Calibrated
    local calText = status.calibrated
        and W.safeGetText("IGUI_Yes") or W.safeGetText("IGUI_No")
    local calColour = status.calibrated and C.success or C.error
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Calibrated") .. ": " .. calText, calColour)
    ctx.y = ctx.y + ctx.lineH

    -- Power
    local powerText = "NONE"
    if status.powerSource == "grid" then powerText = "GRID"
    elseif status.powerSource == "generator" then powerText = "GENERATOR"
    end
    local powerColour = (powerText ~= "NONE") and C.text or C.error
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Power") .. ": " .. powerText, powerColour)
    ctx.y = ctx.y + ctx.lineH

    -- Cooldown
    local cdText, cdColour
    if status.onCooldown then
        local cdHours = math.floor((status.cooldownRemaining or 0))
        local cdMins = math.floor(((status.cooldownRemaining or 0) - cdHours) * 60)
        cdText = tostring(cdHours) .. "h " .. tostring(cdMins) .. "m "
            .. W.safeGetText("UI_POS_Satellite_CooldownRemaining")
        cdColour = C.warning
    else
        cdText = W.safeGetText("UI_POS_Satellite_CooldownReady")
        cdColour = C.success
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Cooldown") .. ": " .. cdText, cdColour)
    ctx.y = ctx.y + ctx.lineH

    -- Link
    local linkText, linkColour
    if status.linkType == POS_Constants.SATELLITE_LINK_TYPE_WIRED then
        linkText = W.safeGetText("UI_POS_Satellite_LinkWired")
            .. " (" .. tostring(status.linkDistance or 0) .. " "
            .. W.safeGetText("UI_POS_Tiles") .. ")"
        linkColour = C.text
    elseif status.linkType == "wireless" then
        linkText = W.safeGetText("UI_POS_Satellite_LinkWireless")
        linkColour = C.text
    else
        linkText = W.safeGetText("UI_POS_Satellite_LinkNone")
        linkColour = C.error
    end
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Link") .. ": " .. linkText, linkColour)
    ctx.y = ctx.y + ctx.lineH

    -- Fuel
    local fuelOk = (status.fuel or 0) >= POS_Constants.SATELLITE_LOW_FUEL_THRESHOLD
    local fuelText = fuelOk
        and W.safeGetText("UI_POS_Satellite_FuelOK")
        or W.safeGetText("UI_POS_Satellite_FuelLow")
    local fuelColour = fuelOk and C.success or C.error
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Fuel") .. ": " .. fuelText, fuelColour)
    ctx.y = ctx.y + ctx.lineH

    -- Trust bar
    local trust = status.trust or 0
    local trustPct = math.floor(trust * 100)
    local trustColour = (trust >= 0.5) and C.success or C.warning
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_Trust") .. ": "
        .. _buildBar(trust, 20) .. " " .. tostring(trustPct) .. "%", trustColour)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 2: Broadcast Mode
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Satellite_BroadcastMode"), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    local modes = _getModeEntries()
    for _, mode in ipairs(modes) do
        local isSelected = (_selectedMode == mode.id)
        local prefix = isSelected and "> " or "  "
        local label = prefix .. W.safeGetText(mode.labelKey)
        if mode.riskSuffix then
            label = label .. " " .. W.safeGetText("UI_POS_Satellite_Mode_RumourRisk")
        end

        if isSelected then
            W.createLabel(ctx.panel, 8, ctx.y, label, C.textBright)
            ctx.y = ctx.y + ctx.lineH + 2
        else
            local modeId = mode.id
            W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                label, nil, function()
                    _selectedMode = modeId
                    POS_ScreenManager.replaceCurrent(screen.id,
                        { selectedMode = modeId, selectedArtifact = _selectedArtifactIdx })
                end)
            ctx.y = ctx.y + ctx.btnH + 2
        end
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 3: Artifact Selection
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Satellite_Artifact"), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    local artifacts = _findArtifacts(player)

    if #artifacts == 0 then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Satellite_NoArtifacts"), C.dim)
        ctx.y = ctx.y + ctx.lineH + 4
    else
        local maxShow = 5
        local showCount = math.min(#artifacts, maxShow)
        for idx = 1, showCount do
            local artifact = artifacts[idx]
            local displayName = artifact:getDisplayName() or "???"
            local md = PhobosLib.getModData(artifact)
            local category = md and md.POS_Category or ""
            local confidence = md and md.POS_Confidence or 0

            local isSelected = (_selectedArtifactIdx == idx)
            local prefix = isSelected and "> " or "  "
            local label = prefix .. displayName
            if category ~= "" then
                label = label .. " (" .. category .. ")"
            end
            label = label .. "  " .. string.format("%.0f%%", (confidence or 0) * 100)

            if isSelected then
                W.createLabel(ctx.panel, 8, ctx.y, label, C.textBright)
                ctx.y = ctx.y + ctx.lineH + 2
            else
                local capturedIdx = idx
                W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
                    label, nil, function()
                        _selectedArtifactIdx = capturedIdx
                        POS_ScreenManager.replaceCurrent(screen.id,
                            { selectedMode = _selectedMode, selectedArtifact = capturedIdx })
                    end)
                ctx.y = ctx.y + ctx.btnH + 2
            end
        end

        if #artifacts > maxShow then
            W.createLabel(ctx.panel, 8, ctx.y,
                "  +" .. tostring(#artifacts - maxShow) .. " more...", C.dim)
            ctx.y = ctx.y + ctx.lineH
        end
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 4: Broadcast Strength Preview
    -----------------------------------------------------------
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Satellite_Strength"), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 2

    local strOk, strength = PhobosLib.safecall(POS_SatelliteService.getStrengthBreakdown)
    local str = (strOk and type(strength) == "table") and strength or {}
    local baseStr = str.base or 0
    local sigintStr = str.sigint or 0
    local fuelStr = str.fuel or 0
    local trustStr = str.trust or 0
    local totalStr = math.min(baseStr + sigintStr + fuelStr + trustStr, 1.0)

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_StrengthBase") .. "   "
        .. _buildBar(baseStr, 15), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_StrengthSIGINT") .. " "
        .. _buildBar(sigintStr, 15), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_StrengthFuel") .. "   "
        .. _buildBar(fuelStr, 15), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_StrengthTrust") .. "  "
        .. _buildBar(trustStr, 15), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "=")
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_Satellite_StrengthTotal") .. "  "
        .. _buildBar(totalStr, 15) .. " "
        .. string.format("%.0f%%", totalStr * 100), C.textBright)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -----------------------------------------------------------
    -- Section 5: Transmit Button
    -----------------------------------------------------------
    local gateReason = _getTransmitGate(status)

    if gateReason then
        W.createDisabledButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH + 4,
            W.safeGetText("UI_POS_Satellite_Transmit")
            .. "  (" .. W.safeGetText(gateReason) .. ")")
        ctx.y = ctx.y + ctx.btnH + 8
    else
        local artifact = artifacts and artifacts[_selectedArtifactIdx]
        local mode = _selectedMode
        local zoneId = status.zoneId or ""

        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH + 4,
            "[ " .. W.safeGetText("UI_POS_Satellite_Transmit") .. " ]", nil,
            function()
                if artifact and mode then
                    local bOk, bErr = PhobosLib.safecall(
                        POS_SatelliteService.broadcast, artifact, mode, zoneId)
                    if bOk then
                        _isTransmitting = true
                        _transmitProgress = 0
                        _transmitStartTime = getGameTime():getWorldAgeHours()
                        POS_ScreenManager.replaceCurrent(screen.id,
                            { selectedMode = mode, selectedArtifact = _selectedArtifactIdx })
                    else
                        PhobosLib.debug("POS", _TAG,
                            "Broadcast failed: " .. tostring(bErr))
                    end
                end
            end)
        ctx.y = ctx.y + ctx.btnH + 8
    end

    -- Subscribe to live-update events (§58 Screen Refresh Pattern)
    _refreshListeners = {}
    local function _onRefresh()
        POS_ScreenManager.markDirty()
    end
    _subscribe(POS_Events.OnBackgroundProgressUpdated, _onRefresh)

    -- Footer
    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------

local _origDestroy = POS_TerminalWidgets.defaultDestroy
function screen.destroy()
    for _, entry in ipairs(_refreshListeners) do
        if entry.event and entry.event.removeListener then
            entry.event:removeListener(entry.fn)
        end
    end
    _refreshListeners = {}
    _selectedMode = nil
    _selectedArtifactIdx = nil
    _isTransmitting = false
    _transmitProgress = 0
    _transmitStartTime = 0
    _origDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

---------------------------------------------------------------
-- ContextPanel
---------------------------------------------------------------

screen.getContextData = function(_params)
    local data = {}

    if _isTransmitting then
        -- Transmitting: show signal ecology pillar breakdown
        table.insert(data, { type = "header", text = "UI_POS_Satellite_Transmitting" })
        table.insert(data, { type = "separator" })

        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_Satellite_Progress"),
            value = string.format("%.0f%%", (_transmitProgress or 0) * 100) })

        local sigOk, sigData = PhobosLib.safecall(POS_SignalEcologyService.getPillarBreakdown)
        if sigOk and type(sigData) == "table" then
            for _, pillar in ipairs(sigData) do
                table.insert(data, { type = "kv",
                    key = pillar.name or "?",
                    value = string.format("%.0f%%", (pillar.value or 0) * 100) })
            end
        end

        return data
    end

    -- Default: trust per zone + broadcast history
    table.insert(data, { type = "header", text = "UI_POS_Satellite_Title" })
    table.insert(data, { type = "separator" })

    -- Trust per zone from world modData
    local player = getSpecificPlayer(0)
    if player then
        local md = player:getModData()
        local posData = md and md.POSNET
        local trustRecords = posData and posData.SatelliteTrust
        if trustRecords then
            for zoneId, trustVal in pairs(trustRecords) do
                if type(trustVal) == "number" then
                    table.insert(data, { type = "kv",
                        key = tostring(zoneId),
                        value = string.format("%.0f%%", trustVal * 100) })
                end
            end
        end

        -- Last 5 broadcasts from history
        local history = posData and posData.SatelliteHistory
        if history then
            table.insert(data, { type = "separator" })
            local count = 0
            for i = #history, 1, -1 do
                if count >= 5 then break end
                local entry = history[i]
                if type(entry) == "table" then
                    table.insert(data, { type = "kv",
                        key = PhobosLib.safeGetText("UI_POS_Fragments_Day")
                            .. " " .. tostring(entry.day or "?"),
                        value = tostring(entry.mode or "?") })
                    count = count + 1
                end
            end
        end
    end

    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
