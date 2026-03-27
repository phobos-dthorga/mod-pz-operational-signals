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
-- POS_Screen_SatelliteScan.lua
-- Active satellite scanning terminal screen.
-- Animated progress bars for scan cycles, signal download,
-- power draw, and rare discovery rolls.
-- Programmatic-only screen (no menu path).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Satellite"
require "POS_Constants_Signal"
require "POS_TerminalWidgets"
require "POS_ScreenManager"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:SatScan]"

-- Module-level state
local _scanning = false
local _cycleProgress = 0
local _chunksThisSession = 0
local _lastDiscovery = nil
local _sessionStartTime = 0
local _lastCycleTick = 0
local _drainSessionId = nil
local _tickRegistered = false

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- Build an ASCII bar string.
--- @param value  number  0.0-1.0
--- @param width  number  Character width of bar
--- @return string  Bar string like "[####............] 80%"
local function _buildBar(value, width)
    local barLen = width or 20
    local filled = math.floor((value or 0) * barLen)
    if filled > barLen then filled = barLen end
    if filled < 0 then filled = 0 end
    return "[" .. string.rep("#", filled) .. string.rep(".", barLen - filled) .. "]"
end

--- Calculate cycle duration in game seconds for current SIGINT level.
--- @param sigintLevel number
--- @return number  Cycle duration in game seconds
local function _getCycleDuration(sigintLevel)
    return math.max(
        POS_Constants.SAT_SCAN_CYCLE_MIN_SECONDS,
        POS_Constants.SAT_SCAN_CYCLE_SECONDS_BASE
            - ((sigintLevel or 0) * POS_Constants.SAT_SCAN_CYCLE_SIGINT_REDUCTION))
end

--- Get player SIGINT level via safecall.
--- @return number  SIGINT level (0 if unavailable)
local function _getSigintLevel()
    local player = getSpecificPlayer(0)
    if not player then return 0 end
    local ok, level = PhobosLib.safecall(POS_SIGINTSkill.getLevel, player)
    if ok and type(level) == "number" then return level end
    return 0
end

--- Get signal quality via safecall.
--- @return number  Signal quality 0.0-1.0
local function _getSignalQuality()
    local ok, quality = PhobosLib.safecall(POS_SignalEcologyService.getQuality)
    if ok and type(quality) == "number" then return quality end
    return 0
end

--- Get current zone ID from satellite status.
--- @return string  Zone ID or "unknown"
local function _getZoneId()
    local ok, status = PhobosLib.safecall(POS_SatelliteService.getStatus)
    if ok and status and status.zoneId then return status.zoneId end
    return "unknown"
end

--- Format elapsed game time into MM:SS string.
--- @param startTime number  Game world age hours at start
--- @return string
local function _formatDuration(startTime)
    local elapsed = getGameTime():getWorldAgeHours() - startTime
    local totalSecs = math.floor(elapsed * 3600)
    local mins = math.floor(totalSecs / 60)
    local secs = totalSecs % 60
    return string.format("%02d:%02d", mins, secs)
end

--- Compute rare discovery chance for given SIGINT level.
--- @param sigintLevel number
--- @return number  Chance 0.0-1.0
local function _getRareChance(sigintLevel)
    return math.min(
        POS_Constants.SAT_SCAN_RARE_MAX_CHANCE,
        POS_Constants.SAT_SCAN_RARE_BASE_CHANCE
            + ((sigintLevel or 0) * POS_Constants.SAT_SCAN_RARE_SIGINT_BONUS))
end

--- Generate a satellite intercept chunk.
--- @param player IsoPlayer
--- @param day number
--- @param zoneId string
--- @param signalQuality number
--- @return table  Chunk data
local function _generateChunk(player, day, zoneId, signalQuality)
    -- Try POS_PassiveRecon.generateSatelliteChunk first
    if POS_PassiveRecon and POS_PassiveRecon.generateSatelliteChunk then
        local ok, chunk = PhobosLib.safecall(
            POS_PassiveRecon.generateSatelliteChunk, player, day)
        if ok and chunk then return chunk end
    end

    -- Inline fallback
    local ecologyBonus = signalQuality or 0
    return {
        type = POS_Constants.CHUNK_TYPE_SATELLITE_INTERCEPT,
        entityId = zoneId,
        category = "satellite",
        region = zoneId,
        day = day,
        confidence = POS_Constants.SAT_SCAN_CONFIDENCE_BASE + math.floor(ecologyBonus * 1000),
        signalMod = ecologyBonus,
        signalState = signalQuality,
        scanType = "satellite",
    }
end

--- Route a chunk to the data recorder if available.
--- @param chunk table
local function _appendChunk(chunk)
    if POS_DataRecorderService and POS_DataRecorderService.appendChunk then
        PhobosLib.safecall(POS_DataRecorderService.appendChunk, chunk)
    end
end

--- Roll for a rare discovery and return the discovery table or nil.
--- @param sigintLevel number
--- @param zoneId string
--- @param day number
--- @return table|nil  Discovery data
local function _rollRareDiscovery(sigintLevel, zoneId, day)
    local chance = _getRareChance(sigintLevel)
    if ZombRand(10000) >= math.floor(chance * 10000) then return nil end

    local types = POS_Constants.SAT_DISCOVERY_TYPES
    if not types or #types == 0 then return nil end
    local discoveryType = types[ZombRand(#types) + 1]

    -- Gate encrypted discoveries behind SIGINT level
    if discoveryType == POS_Constants.SAT_DISCOVERY_ENCRYPTED
       and sigintLevel < POS_Constants.SAT_DISCOVERY_ENCRYPTED_SIGINT_MIN then
        discoveryType = POS_Constants.SAT_DISCOVERY_CACHE
    end

    local discovery = {
        type = POS_Constants.CHUNK_TYPE_SATELLITE_DISCOVERY,
        discoveryType = discoveryType,
        zone = zoneId,
        day = day,
        confidence = POS_Constants.SAT_SCAN_CONFIDENCE_BASE,
        scanType = "satellite",
    }

    -- Route through recorder
    _appendChunk(discovery)

    -- Award SIGINT XP for discovery
    local player = getSpecificPlayer(0)
    if player and POS_SIGINTSkill and POS_SIGINTSkill.addXP then
        PhobosLib.safecall(POS_SIGINTSkill.addXP, player,
            POS_Constants.SIGINT_XP_SATELLITE_SCAN_DISCOVERY)
    end

    return discovery
end

--- Start power drain session.
local function _startPowerDrain()
    if PhobosLib.startDrainSession then
        local ok, sessionId = PhobosLib.safecall(
            PhobosLib.startDrainSession, POS_Constants.SAT_SCAN_POWER_DRAIN)
        if ok then _drainSessionId = sessionId end
    end
end

--- Stop power drain session.
local function _stopPowerDrain()
    if _drainSessionId and PhobosLib.stopDrainSession then
        PhobosLib.safecall(PhobosLib.stopDrainSession, _drainSessionId)
    end
    _drainSessionId = nil
end

--- Abort an active scan session.
local function _abortScan()
    _stopPowerDrain()
    _scanning = false
    _cycleProgress = 0
    _chunksThisSession = 0
    _sessionStartTime = 0
    _lastCycleTick = 0
    PhobosLib.debug("POS", _TAG, "Scan session aborted")
end

--- Start a new scan session.
local function _startScan()
    local now = getGameTime():getWorldAgeHours()
    _scanning = true
    _cycleProgress = 0
    _chunksThisSession = 0
    _lastDiscovery = nil
    _sessionStartTime = now
    _lastCycleTick = now
    _startPowerDrain()
    PhobosLib.debug("POS", _TAG, "Scan session started")
end

---------------------------------------------------------------
-- Tick handler (registered from create, unregistered in destroy)
---------------------------------------------------------------

local function _onScanTick()
    if not _scanning then return end

    local player = getSpecificPlayer(0)
    if not player then
        _abortScan()
        return
    end

    -- Check satellite still connected (Tier IV or Tier V)
    local stillCalibrated = false
    local ok, status = PhobosLib.safecall(POS_SatelliteService.getStatus)
    if ok and status and status.calibrated then
        stillCalibrated = true
    end
    if not stillCalibrated and POS_StrategicRelayService
            and POS_StrategicRelayService.getAllRelays then
        local okR, relays = PhobosLib.safecall(POS_StrategicRelayService.getAllRelays)
        if okR and relays then
            for _, relay in ipairs(relays) do
                local okS, rs = PhobosLib.safecall(
                    POS_StrategicRelayService.getRelayStatus, relay.siteId)
                if okS and rs and rs.isOperational then
                    stillCalibrated = true
                    break
                end
            end
        end
    end
    if not stillCalibrated then
        _abortScan()
        POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_SATELLITE_SCAN)
        return
    end

    -- Check power
    if status and status.powered == false then
        _abortScan()
        POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_SATELLITE_SCAN)
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local sigintLevel = _getSigintLevel()
    local cycleSecs = _getCycleDuration(sigintLevel)
    local cycleHours = cycleSecs / 3600
    local elapsed = now - _lastCycleTick

    _cycleProgress = math.min(elapsed / cycleHours, 1.0)

    -- Cycle complete
    if _cycleProgress >= 1.0 then
        local day = math.floor(getGameTime():getWorldAgeHours() / 24)
        local zoneId = _getZoneId()
        local signalQuality = _getSignalQuality()

        -- Generate intercept chunk
        local chunk = _generateChunk(player, day, zoneId, signalQuality)
        _appendChunk(chunk)
        _chunksThisSession = _chunksThisSession + 1

        -- Award SIGINT XP per chunk
        if POS_SIGINTSkill and POS_SIGINTSkill.addXP then
            PhobosLib.safecall(POS_SIGINTSkill.addXP, player,
                POS_Constants.SIGINT_XP_SATELLITE_SCAN_CHUNK)
        end

        -- Roll for rare discovery
        local discovery = _rollRareDiscovery(sigintLevel, zoneId, day)
        if discovery then
            _lastDiscovery = discovery
        end

        -- Reset cycle
        _lastCycleTick = now
        _cycleProgress = 0

        -- Buffer full check
        if _chunksThisSession >= POS_Constants.SAT_SCAN_BUFFER_MAX then
            PhobosLib.debug("POS", _TAG, "Buffer full, auto-aborting scan")
            _abortScan()
        end

        -- Refresh display
        POS_ScreenManager.replaceCurrent(POS_Constants.SCREEN_SATELLITE_SCAN)
    end
end

---------------------------------------------------------------
-- Screen definition
---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_SATELLITE_SCAN
screen.menuPath = {"pos.network"}
screen.titleKey = "UI_POS_SatScan_Title"
screen.sortOrder = 20
screen.requires = { connected = true }

function screen.create(contentPanel, params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Header
    W.drawHeader(ctx, "UI_POS_SatScan_Title")

    local player = getSpecificPlayer(0)
    if not player then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_SatScan_NoDish"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Check satellite status (Tier IV portable dish OR Tier V strategic relay)
    local isCalibrated = false
    local hasDish = false

    -- Tier IV: portable satellite dish
    local ok, status = PhobosLib.safecall(POS_SatelliteService.getStatus)
    if ok and status then
        hasDish = true
        if status.calibrated then isCalibrated = true end
    end

    -- Tier V: strategic relay (calibrated = calibrationState >= operational threshold)
    if not isCalibrated and POS_StrategicRelayService and POS_StrategicRelayService.getAllRelays then
        local okR, relays = PhobosLib.safecall(POS_StrategicRelayService.getAllRelays)
        if okR and relays then
            for _, relay in ipairs(relays) do
                hasDish = true
                local okS, relayStatus = PhobosLib.safecall(
                    POS_StrategicRelayService.getRelayStatus, relay.siteId)
                if okS and relayStatus and relayStatus.isOperational then
                    isCalibrated = true
                    break
                end
            end
        end
    end

    if not hasDish then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_SatScan_NoDish"), C.error)
        ctx.y = ctx.y + ctx.lineH
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[0] " .. W.safeGetText("UI_POS_SatScan_Back"), nil,
            function() POS_ScreenManager.goBack() end)
        ctx.y = ctx.y + ctx.btnH + 4
        return
    end

    if not isCalibrated then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_SatScan_NotCalibrated"), C.warning)
        ctx.y = ctx.y + ctx.lineH
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[0] " .. W.safeGetText("UI_POS_SatScan_Back"), nil,
            function() POS_ScreenManager.goBack() end)
        ctx.y = ctx.y + ctx.btnH + 4
        return
    end

    -- Register tick handler
    if not _tickRegistered then
        Events.OnTick.Add(_onScanTick)
        _tickRegistered = true
    end

    local sigintLevel = _getSigintLevel()
    local signalQuality = _getSignalQuality()

    -----------------------------------------------------------
    -- Idle view (not scanning)
    -----------------------------------------------------------
    if not _scanning then
        -- Scan info
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_SatScan_Status_Idle"), C.dim)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_SigintLevel") .. ": "
            .. tostring(sigintLevel), C.text)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_Signal") .. ":  "
            .. _buildBar(signalQuality, 20) .. " "
            .. string.format("%.0f%%", signalQuality * 100), C.text)
        ctx.y = ctx.y + ctx.lineH

        local cycleSecs = _getCycleDuration(sigintLevel)
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_CycleTime") .. ": "
            .. tostring(cycleSecs) .. "s", C.text)
        ctx.y = ctx.y + ctx.lineH

        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_Buffer") .. ": 0/"
            .. tostring(POS_Constants.SAT_SCAN_BUFFER_MAX), C.text)
        ctx.y = ctx.y + ctx.lineH + 4

        W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
        ctx.y = ctx.y + ctx.lineH

        -- START SCAN button
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH + 4,
            "[ " .. W.safeGetText("UI_POS_SatScan_StartScan") .. " ]", nil,
            function()
                _startScan()
                POS_ScreenManager.replaceCurrent(screen.id)
            end)
        ctx.y = ctx.y + ctx.btnH + 8

        W.drawFooter(ctx)
        return
    end

    -----------------------------------------------------------
    -- Active scanning view
    -----------------------------------------------------------

    -- Section: SCAN STATUS
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_SatScan_Status_Active"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_SatScan_Duration") .. ": "
        .. _formatDuration(_sessionStartTime), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_SatScan_Chunks") .. ": "
        .. tostring(_chunksThisSession) .. "/"
        .. tostring(POS_Constants.SAT_SCAN_BUFFER_MAX), C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Section: SIGNAL DOWNLOAD
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_SatScan_Download"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Download bar (cycle progress)
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_SatScan_Download") .. "  "
        .. _buildBar(_cycleProgress, 25) .. " "
        .. string.format("%.0f%%", _cycleProgress * 100), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Signal quality bar
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_SatScan_Signal") .. "   "
        .. _buildBar(signalQuality, 25) .. " "
        .. string.format("%.0f%%", signalQuality * 100), C.text)
    ctx.y = ctx.y + ctx.lineH

    -- Buffer bar
    local bufferFill = _chunksThisSession / POS_Constants.SAT_SCAN_BUFFER_MAX
    local bufferColour = (bufferFill >= 0.9) and C.warning or C.text
    W.createLabel(ctx.panel, 8, ctx.y,
        "  " .. W.safeGetText("UI_POS_SatScan_Buffer") .. "   "
        .. _buildBar(bufferFill, 25) .. " "
        .. tostring(_chunksThisSession) .. "/"
        .. tostring(POS_Constants.SAT_SCAN_BUFFER_MAX), bufferColour)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Section: POWER DRAW
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_SatScan_PowerDraw"), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    local baseDrain = POS_Constants.SATELLITE_FUEL_DRAIN_BROADCAST or 0.10
    local scanDrain = POS_Constants.SAT_SCAN_POWER_DRAIN or 1.2
    local totalDrain = baseDrain + scanDrain

    W.createLabel(ctx.panel, 8, ctx.y,
        "  Base:  " .. string.format("%.2f kW", baseDrain), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  Scan:  " .. string.format("%.2f kW", scanDrain), C.text)
    ctx.y = ctx.y + ctx.lineH

    W.createLabel(ctx.panel, 8, ctx.y,
        "  Total: " .. string.format("%.2f kW", totalDrain), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    -- Fuel remaining bar
    local fuelRemaining = (status.fuel or 0)
    local fuelColour = (fuelRemaining >= POS_Constants.SATELLITE_LOW_FUEL_THRESHOLD)
        and C.success or C.error
    W.createLabel(ctx.panel, 8, ctx.y,
        "  Fuel:  " .. _buildBar(fuelRemaining, 20) .. " "
        .. string.format("%.0f%%", fuelRemaining * 100), fuelColour)
    ctx.y = ctx.y + ctx.lineH + 4

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- Section: RARE DISCOVERY
    local rareChance = _getRareChance(sigintLevel)
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_SatScan_RareChance") .. ": "
        .. string.format("%.1f%%", rareChance * 100), C.textBright)
    ctx.y = ctx.y + ctx.lineH

    if _lastDiscovery and _lastDiscovery.discoveryType then
        local discoveryKey = POS_Constants.SAT_DISCOVERY_KEYS[_lastDiscovery.discoveryType]
            or "UI_POS_SatScan_NoDiscovery"
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_LastDiscovery") .. ": "
            .. W.safeGetText(discoveryKey), C.success)
        ctx.y = ctx.y + ctx.lineH
    else
        W.createLabel(ctx.panel, 8, ctx.y,
            "  " .. W.safeGetText("UI_POS_SatScan_NoDiscovery"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- ABORT SCAN button
    W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH + 4,
        "[ " .. W.safeGetText("UI_POS_SatScan_AbortScan") .. " ]", nil,
        function()
            _abortScan()
            POS_ScreenManager.replaceCurrent(screen.id)
        end)
    ctx.y = ctx.y + ctx.btnH + 8

    W.drawFooter(ctx)
end

---------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------

function screen.destroy()
    if _scanning then
        _abortScan()
    end
    if _tickRegistered then
        Events.OnTick.Remove(_onScanTick)
        _tickRegistered = false
    end
    _lastDiscovery = nil
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

    table.insert(data, { type = "header", text = "UI_POS_SatScan_Title" })
    table.insert(data, { type = "separator" })

    if _scanning then
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_SatScan_Chunks"),
            value = tostring(_chunksThisSession) .. "/"
                .. tostring(POS_Constants.SAT_SCAN_BUFFER_MAX) })

        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_SatScan_Duration"),
            value = _formatDuration(_sessionStartTime) })
    end

    -- Recent discoveries
    if _lastDiscovery then
        table.insert(data, { type = "separator" })
        local discoveryKey = POS_Constants.SAT_DISCOVERY_KEYS[_lastDiscovery.discoveryType]
            or "UI_POS_SatScan_NoDiscovery"
        table.insert(data, { type = "kv",
            key = PhobosLib.safeGetText("UI_POS_SatScan_LastDiscovery"),
            value = PhobosLib.safeGetText(discoveryKey) })

        if _lastDiscovery.zone then
            table.insert(data, { type = "kv",
                key = "Zone",
                value = tostring(_lastDiscovery.zone) })
        end

        if _lastDiscovery.day then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Fragments_Day"),
                value = tostring(_lastDiscovery.day) })
        end

        if _lastDiscovery.confidence then
            table.insert(data, { type = "kv",
                key = "Confidence",
                value = tostring(_lastDiscovery.confidence) })
        end
    end

    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
