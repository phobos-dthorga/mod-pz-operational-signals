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

--- POS_WBN_ClientListener — Client-side listener that captures received
--- WBN broadcasts into player ModData for history display on terminal
--- screens.
---
--- Hooks into the vanilla Events.OnDeviceText callback to intercept radio
--- text arriving on devices tuned to WBN frequencies. Captured broadcasts
--- are stored as indexed entries under the player's POSNET ModData table
--- with FIFO trimming to a configurable maximum.
---
--- @module POS_WBN_ClientListener

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_WBN"
require "POS_WBN_SchedulerService"

local _TAG = "WBN:Client"
POS_WBN_ClientListener = {}

-- PN notification throttle state
local _lastIntelNotifyMinute = 0
local _weakReceiverNotified = false  -- one-shot guard for poor receiver PN toast

--- Check if a device frequency belongs to a WBN channel.
--- Uses AZAS-resolved frequencies for accurate per-world matching.
--- @param freq number  The frequency to check
--- @return boolean     true if this is a WBN frequency
--- @return string|nil  The station class id, or nil
local function isWBNFrequency(freq)
    if not freq then return false, nil end
    local azas = POS_AZASIntegration
    if azas and azas.getWBNMarketFrequency
        and freq == azas.getWBNMarketFrequency() then
        return true, POS_Constants.WBN_STATION_CIVILIAN_MARKET
    end
    if azas and azas.getWBNEmergencyFrequency
        and freq == azas.getWBNEmergencyFrequency() then
        return true, POS_Constants.WBN_STATION_EMERGENCY
    end
    if azas and azas.getWBNOperationsFrequency
        and freq == azas.getWBNOperationsFrequency() then
        return true, POS_Constants.WBN_STATION_OPERATIONS
    end
    return false, nil
end

--- Add a bulletin to the broadcast history log in player ModData.
--- Entries are stored with string keys under POSNET.[historyKey] for
--- Java table compatibility. Oldest entries are trimmed via FIFO when
--- the maximum is exceeded.
--- @param text           string  The broadcast text content
--- @param stationClassId string  Station class from POS_Constants.WBN_STATION_*
local function addToHistory(text, stationClassId)
    local player = getPlayer()
    if not player then return end

    local md = player:getModData()
    if not md then return end

    local posData = md.POSNET
    if not posData then
        md.POSNET = {}
        posData = md.POSNET
    end

    local history = posData[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    if not history then
        posData[POS_Constants.WBN_HISTORY_MODDATA_KEY] = {}
        history = posData[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    end

    -- Determine next entry index (string keys for Java table safety)
    local worldHours = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local entryIdx = 0
    for _ in pairs(history) do entryIdx = entryIdx + 1 end
    entryIdx = entryIdx + 1

    history[tostring(entryIdx)] = {
        text         = text or "",
        stationClass = stationClassId or "",
        day          = day,
        gameHours    = worldHours,
    }

    -- Trim to max entries (FIFO — remove oldest by lowest index)
    local maxEntries = POS_Constants.WBN_HISTORY_MAX_ENTRIES
    local count = 0
    for _ in pairs(history) do count = count + 1 end
    if count > maxEntries then
        local minIdx = nil
        for k, _ in pairs(history) do
            local n = tonumber(k)
            if n and (not minIdx or n < minIdx) then minIdx = n end
        end
        if minIdx then history[tostring(minIdx)] = nil end
    end
end

---------------------------------------------------------------
-- Signal fragment generation
---------------------------------------------------------------

--- Generate a signal fragment from broadcast candidate metadata.
--- Only data-bearing domains produce fragments (not flavour/colour).
--- @param candidate table Candidate metadata from scheduler cache
--- @param stationClassId string Station class
--- @param currentDay number Current game day
--- @param receiverQualityFactor number|nil Receiver quality (0.20-0.95, nil=no scaling)
--- @return table|nil Fragment table or nil
local function generateSignalFragment(candidate, stationClassId, currentDay, receiverQualityFactor)
    if not candidate then return nil end
    -- Only generate fragments for data-bearing domains (not flavour)
    local domain = candidate.domain
    if domain == POS_Constants.WBN_DOMAIN_COLOUR then return nil end

    local fragmentType = "market_fragment"
    if domain == POS_Constants.WBN_DOMAIN_WEATHER then
        fragmentType = "weather_fragment"
    elseif domain == POS_Constants.WBN_DOMAIN_POWER then
        fragmentType = "infrastructure_fragment"
    elseif domain == POS_Constants.WBN_DOMAIN_INFRASTRUCTURE then
        fragmentType = "infrastructure_fragment"
    end

    local rawConf = (candidate.confidence or 0.5) * POS_Constants.WBN_FRAGMENT_CONF_SCALE
    local conf = PhobosLib.clamp
        and PhobosLib.clamp(rawConf, POS_Constants.WBN_FRAGMENT_CONF_MIN, POS_Constants.WBN_FRAGMENT_CONF_MAX)
        or rawConf

    -- Phase 3: Information shadow degrades broadcast fragment confidence
    if candidate.zoneId and POS_EntropyService
            and POS_EntropyService.getIntelState then
        local intelState = POS_EntropyService.getIntelState(
            candidate.zoneId, candidate.categoryId)
        if intelState and (intelState.shadowState or 0)
                > POS_Constants.ENTROPY_SHADOW_LABEL_THRESHOLD then
            conf = conf * (1.0 - intelState.shadowState
                * POS_Constants.ENTROPY_SHADOW_BROADCAST_DEGRADE)
            conf = math.max(conf, POS_Constants.WBN_FRAGMENT_CONF_MIN)
        end
    end

    -- Receiver quality degrades fragment confidence (poor radio = less reliable intel)
    if receiverQualityFactor and receiverQualityFactor > 0 then
        local confScale = POS_Constants.RECEIVER_CONFIDENCE_SCALE or 0.30
        conf = conf * (1.0 - receiverQualityFactor * confScale)
        conf = math.max(conf, POS_Constants.WBN_FRAGMENT_CONF_MIN)
    end

    return {
        type            = fragmentType,
        zoneId          = candidate.zoneId,
        categoryId      = candidate.categoryId,
        direction       = candidate.direction,
        estimatedChange = candidate.percentChange,
        confidence      = conf,
        freshness       = 1.0,
        source          = POS_Constants.WBN_FRAGMENT_SOURCE,
        verified        = false,
        receivedDay     = currentDay,
        stationClassId  = stationClassId,
    }
end

--- Store a signal fragment in player ModData (Java table safe).
--- Uses string keys and pairs() iteration — never # or table.insert.
--- @param fragment table Fragment to store
local function storeFragment(fragment)
    if not fragment then return end
    local player = getPlayer()
    if not player then return end

    local md = PhobosLib.getPlayerModData and PhobosLib.getPlayerModData(player, "POSNET") or nil
    if not md then return end

    md[POS_Constants.WBN_FRAGMENT_MODDATA_KEY] = md[POS_Constants.WBN_FRAGMENT_MODDATA_KEY] or {}
    local store = md[POS_Constants.WBN_FRAGMENT_MODDATA_KEY]

    -- Find next index (Java ModData safe — no #, no table.insert)
    local nextIdx = 0
    for k, _ in pairs(store) do
        local n = tonumber(k)
        if n and n > nextIdx then nextIdx = n end
    end
    nextIdx = nextIdx + 1

    store[tostring(nextIdx)] = fragment

    -- Trim oldest if over cap
    local count = 0
    local oldest = nil
    local oldestKey = nil
    for k, v in pairs(store) do
        if type(v) == "table" then
            count = count + 1
            if not oldest or (v.receivedDay or 0) < (oldest.receivedDay or 0) then
                oldest = v
                oldestKey = k
            end
        end
    end
    if count > POS_Constants.WBN_FRAGMENT_MAX_STORED and oldestKey then
        store[oldestKey] = nil
    end

    PhobosLib.debug("POS", _TAG, "fragment stored: " .. tostring(fragment.type)
        .. " (conf: " .. string.format("%.2f", fragment.confidence) .. ")")
end

--- Reinforce or contradict existing rumours based on a received fragment.
--- Matching rumours in the same zone/category with compatible direction get
--- a confidence boost; contradicting rumours get a confidence penalty.
--- @param fragment table Signal fragment with zoneId, categoryId, direction
local function reinforceRumours(fragment)
    if not fragment or not fragment.zoneId or not fragment.categoryId then return end
    if not fragment.direction then return end

    local ok, POS_WorldState = PhobosLib.safecall(require, "POS_WorldState")
    if not ok or not POS_WorldState or not POS_WorldState.getRumours then return end

    local rumours = POS_WorldState.getRumours()
    if not rumours then return end

    for _, r in pairs(rumours) do
        if type(r) == "table" and r.regionId == fragment.zoneId then
            -- Check category overlap
            local catMatch = false
            if r.categoryIds then
                for _, cId in pairs(r.categoryIds) do
                    if cId == fragment.categoryId then catMatch = true; break end
                end
            end

            if catMatch then
                local sameDirection = false
                if fragment.direction == POS_Constants.WBN_DIR_UP and r.impactHint == "shortage" then
                    sameDirection = true
                elseif fragment.direction == POS_Constants.WBN_DIR_DOWN and r.impactHint == "surplus" then
                    sameDirection = true
                end

                -- Initialise numeric confidence if absent
                if not r.confidenceNumeric then r.confidenceNumeric = 0.30 end

                -- Phase 3: Desperation amplifies rumour confidence swings
                local desperationMult = 1.0
                if fragment.zoneId and fragment.categoryId
                        and POS_EntropyService and POS_EntropyService.getDesperationIndex then
                    local desp = POS_EntropyService.getDesperationIndex(
                        fragment.zoneId, fragment.categoryId) or 0
                    desperationMult = 1.0 + desp * POS_Constants.ENTROPY_DESPERATION_RUMOUR_BOOST_MULT
                end

                if sameDirection then
                    r.confidenceNumeric = math.min(
                        r.confidenceNumeric + POS_Constants.WBN_RUMOUR_REINFORCE_BOOST * desperationMult,
                        POS_Constants.WBN_FRAGMENT_CONF_MAX)
                    PhobosLib.debug("POS", _TAG, "rumour reinforced: " .. tostring(r.id)
                        .. " -> " .. string.format("%.2f", r.confidenceNumeric))
                else
                    r.confidenceNumeric = math.max(
                        r.confidenceNumeric - POS_Constants.WBN_RUMOUR_CONTRADICT_DROP * desperationMult,
                        POS_Constants.WBN_RUMOUR_CONF_FLOOR)
                    PhobosLib.debug("POS", _TAG, "rumour contradicted: " .. tostring(r.id)
                        .. " -> " .. string.format("%.2f", r.confidenceNumeric))
                    -- Write contradiction to fog-of-market entropy state
                    if fragment.zoneId and fragment.categoryId
                            and POS_EntropyService and POS_EntropyService.addContradiction then
                        POS_EntropyService.addContradiction(
                            fragment.zoneId, fragment.categoryId,
                            POS_Constants.WBN_RUMOUR_CONTRADICT_DROP)
                    end
                end
            end
        end
    end
end

--- Send a PN toast notification for an intel fragment discovery.
--- Throttled to one notification per WBN_PN_INTEL_THROTTLE_MIN game-minutes.
--- @param fragment table Signal fragment
local function notifyIntelDiscovery(fragment)
    if not fragment then return end
    local player = getPlayer()
    if not player then return end

    -- Throttle: one notification per WBN_PN_INTEL_THROTTLE_MIN game-minutes
    local currentMinute = getGameTime and getGameTime():getMinutes() or 0
    if (currentMinute - _lastIntelNotifyMinute) < POS_Constants.WBN_PN_INTEL_THROTTLE_MIN then
        return
    end
    _lastIntelNotifyMinute = currentMinute

    local messageKey = nil
    if fragment.type == "market_fragment" then
        messageKey = "UI_POS_PN_Fragment_Market"
    elseif fragment.type == "infrastructure_fragment" then
        messageKey = "UI_POS_PN_Fragment_Infrastructure"
    elseif fragment.type == "weather_fragment" then
        messageKey = "UI_POS_PN_Fragment_Weather"
    end

    if not messageKey then return end

    local message = PhobosLib.safeGetText(messageKey)
    if fragment.categoryId then
        local catName = PhobosLib.safeGetText("UI_POS_Category_" .. tostring(fragment.categoryId))
        if catName and catName ~= ("UI_POS_Category_" .. tostring(fragment.categoryId)) then
            message = string.gsub(message, "{category}", catName)
        else
            message = string.gsub(message, "{category}", tostring(fragment.categoryId))
        end
    end
    if fragment.zoneId then
        local keySuffix = POS_Constants.ZONE_DISPLAY_KEY
            and POS_Constants.ZONE_DISPLAY_KEY[fragment.zoneId]
        local zoneName = keySuffix
            and PhobosLib.safeGetText("UI_POS_Zone_" .. keySuffix)
            or tostring(fragment.zoneId)
        message = string.gsub(message, "{zone}", zoneName)
    end

    PhobosLib.safecall(PhobosLib.notifyOrSay, player, {
        title   = PhobosLib.safeGetText("UI_POS_PN_FragmentDiscovered_Title"),
        message = message,
        colour  = "tutorial",
        channel = POS_Constants.PN_CHANNEL_INTEL,
    })
end

--- Process a received WBN broadcast: generate fragment, reinforce rumours,
--- send PN notification, and fire Starlit events.
--- @param lineText string The broadcast text
--- @param stationClassId string Station class
--- @param currentDay number Current game day
local function processIntelFromBroadcast(lineText, stationClassId, currentDay, receiverQualityFactor, effectiveDropout)
    -- Look up candidate metadata from the scheduler's shared cache
    local candidateData = nil
    if POS_WBN_SchedulerService and POS_WBN_SchedulerService.consumeBulletinMeta then
        candidateData = POS_WBN_SchedulerService.consumeBulletinMeta(lineText)
    end
    if not candidateData then return end

    -- Generate and store signal fragment (receiver quality scales confidence)
    local fragment = generateSignalFragment(candidateData, stationClassId, currentDay, receiverQualityFactor)
    if fragment then
        storeFragment(fragment)

        -- Feed market fragments into MarketDatabase as radio-sourced
        -- observations (direction + confidence, no exact price).
        -- In SP the client is authority so addRecord() succeeds directly.
        if fragment.categoryId and fragment.zoneId
                and POS_MarketDatabase and POS_MarketDatabase.addRecord then
            PhobosLib.safecall(POS_MarketDatabase.addRecord, {
                categoryId  = fragment.categoryId,
                zoneId      = fragment.zoneId,
                direction   = fragment.direction,
                confidence  = fragment.confidence,
                source      = POS_Constants.WBN_FRAGMENT_SOURCE,
                sourceTier  = POS_Constants.SOURCE_TIER_BROADCAST,
                day         = fragment.receivedDay,
            })
        end

        PhobosLib.safecall(reinforceRumours, fragment)
        PhobosLib.safecall(notifyIntelDiscovery, fragment)

        -- Fire Starlit events (enriched with receiver quality data)
        local ok_events, POS_Events = PhobosLib.safecall(require, "POS_Events")
        if ok_events and POS_Events then
            if POS_Events.OnBroadcastReceived then
                PhobosLib.safecall(POS_Events.OnBroadcastReceived.trigger,
                    POS_Events.OnBroadcastReceived, {
                        text                 = lineText,
                        stationClassId       = stationClassId,
                        day                  = currentDay,
                        receiverQualityFactor = receiverQualityFactor,
                        effectiveDropoutRate = effectiveDropout,
                    })
            end
            if POS_Events.OnSignalFragmentGenerated then
                PhobosLib.safecall(POS_Events.OnSignalFragmentGenerated.trigger,
                    POS_Events.OnSignalFragmentGenerated, fragment)
            end
        end
    end
end

--- Vanilla PZ OnDeviceText callback. Fires when a radio device receives
--- text. Checks if the device is tuned to a WBN frequency and captures
--- the text into player ModData history.
--- @param guid   string         Device GUID
--- @param codes  userdata       Message codes
--- @param x      number         World X coordinate
--- @param y      number         World Y coordinate
--- @param z      number         World Z coordinate
--- @param text   string|userdata  The broadcast text or RadioLine object
--- @param device userdata       The radio device instance
local function onDeviceText(guid, codes, x, y, z, text, device)
    if not device then return end

    local data = nil
    if device.getDeviceData then
        data = device:getDeviceData()
    end
    if not data then return end

    -- Device must be turned on
    if data.getIsTurnedOn and data:getIsTurnedOn() ~= true then return end

    -- Check if tuned to a WBN frequency
    local freq = 0
    if data.getChannel then freq = data:getChannel() end
    local isWBN, stationId = isWBNFrequency(freq)
    if not isWBN then return end

    -- Proximity gate: only accept broadcasts from devices within hearing range.
    -- OnDeviceText fires globally for ALL radios in the world tuned to the
    -- frequency. Without this check, a radio thousands of tiles away would
    -- deliver intel to the player.
    local player = getPlayer and getPlayer()
    if player and x and y then
        local px, py = player:getX(), player:getY()
        local dx, dy = x - px, y - py
        local distSq = dx * dx + dy * dy
        if distSq > (POS_Constants.WBN_HEARING_RANGE_SQ or 400) then
            return  -- device too far from player
        end
    end

    -- Extract text from either a plain string or a RadioLine object
    local lineText = ""
    if type(text) == "string" then
        lineText = text
    elseif text and text.getText then
        lineText = text:getText() or ""
    end

    if lineText ~= "" then
        -- Compute receiver quality factor from the receiving device
        local qualityFactor = POS_Constants.RECEIVER_FACTOR_FALLBACK
        if PhobosLib_Radio and PhobosLib_Radio.getReceiverQualityFactor then
            local profileLookup = POS_ReceiverProfileRegistry
                and POS_ReceiverProfileRegistry.getByFullType or nil
            local qfOk, qf = PhobosLib.safecall(
                PhobosLib_Radio.getReceiverQualityFactor, device, {
                    profileLookup    = profileLookup,
                    rangeNormaliser  = POS_Constants.RECEIVER_RANGE_NORMALISER,
                    rangeWeight      = POS_Constants.RECEIVER_RANGE_WEIGHT,
                    hamBonus         = POS_Constants.RECEIVER_HAM_BONUS,
                    makeshiftPenalty = POS_Constants.RECEIVER_MAKESHIFT_PENALTY,
                    commercialBase   = POS_Constants.RECEIVER_COMMERCIAL_BASE,
                    factorMin        = POS_Constants.RECEIVER_FACTOR_MIN,
                    factorMax        = POS_Constants.RECEIVER_FACTOR_MAX,
                    conditionWeight  = POS_Constants.RECEIVER_CONDITION_WEIGHT,
                })
            if qfOk and type(qf) == "number" then
                qualityFactor = qf
            end
        end

        -- One-shot notification for poor receiver quality (factor ≥ 0.80)
        if qualityFactor >= 0.80 and not _weakReceiverNotified then
            _weakReceiverNotified = true
            local tPlayer = getPlayer and getPlayer()
            if tPlayer then
                PhobosLib.notifyOrSay(tPlayer, {
                    title   = PhobosLib.safeGetText("UI_POS_Signal_ReceiverWeak_Title"),
                    message = PhobosLib.safeGetText("UI_POS_Signal_ReceiverWeak_Msg"),
                    colour  = "warning",
                    channel = POS_Constants.PN_CHANNEL_SIGNAL,
                })
            end
        end

        -- Apply client-side text degradation (ecology × receiver quality)
        local ecologyState = "clear"
        if POS_SignalEcologyService and POS_SignalEcologyService.getQualitativeState then
            ecologyState = POS_SignalEcologyService.getQualitativeState() or "clear"
        end
        local baseDropout = 0
        if POS_WBN_CompositionService and POS_WBN_CompositionService.getDropoutRate then
            baseDropout = POS_WBN_CompositionService.getDropoutRate(ecologyState)
        end
        local effectiveDropout = baseDropout * qualityFactor
        local degradedText = lineText
        if effectiveDropout > 0 and POS_WBN_CompositionService
                and POS_WBN_CompositionService.degradeTextString then
            degradedText = POS_WBN_CompositionService.degradeTextString(
                lineText, effectiveDropout, ecologyState)
        end

        -- Store degraded text in history (what the player reads)
        addToHistory(degradedText, stationId)

        -- Process intel using CLEAN text (metadata cache keys on undegraded text)
        local currentDay = getGameTime and getGameTime():getNightsSurvived() or 0
        PhobosLib.safecall(processIntelFromBroadcast,
            lineText, stationId, currentDay, qualityFactor, effectiveDropout)

        PhobosLib.debug("POS", _TAG,
            "captured broadcast on " .. tostring(stationId)
            .. " (receiver=" .. string.format("%.2f", qualityFactor)
            .. " dropout=" .. string.format("%.2f", effectiveDropout)
            .. "): " .. degradedText:sub(1, 50))
    end
end

-- Register with vanilla PZ event system
if Events and Events.OnDeviceText then
    Events.OnDeviceText.Add(onDeviceText)
    PhobosLib.debug("POS", _TAG, "registered OnDeviceText listener")
end

-- Inject Signal Ecology power callback on game start (client-side only).
-- The callback checks grid power at the player's current position.
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if POS_SignalEcologyService and POS_SignalEcologyService.setPowerCallback then
            POS_SignalEcologyService.setPowerCallback(function()
                local player = getPlayer()
                if not player then return false end
                local sq = player:getCurrentSquare()
                if not sq then return false end
                if PhobosLib and PhobosLib.hasPower then
                    return PhobosLib.hasPower(sq)
                end
                return false
            end)
            PhobosLib.debug("POS", _TAG, "injected Signal Ecology power callback")
        end
    end)
end

--- Get all stored signal fragments for display on terminal screens.
--- Returns an array of fragment records sorted newest-first (by receivedDay).
--- Uses pairs() iteration for Java ModData safety.
--- @return table  Array of fragment records
function POS_WBN_ClientListener.getAllFragments()
    local player = getPlayer()
    if not player then return {} end
    local md = player:getModData()
    if not md or not md.POSNET then return {} end
    local store = md.POSNET[POS_Constants.WBN_FRAGMENT_MODDATA_KEY]
    if not store then return {} end

    local result = {}
    for k, v in pairs(store) do
        if type(v) == "table" and v.type then
            v._sortIdx = tonumber(k) or 0
            result[#result + 1] = v
        end
    end
    table.sort(result, function(a, b) return (a._sortIdx or 0) > (b._sortIdx or 0) end)
    return result
end

--- Get broadcast history for display on terminal screens.
--- Returns an array of history entries sorted newest-first.
--- @return table  Array of { text, stationClass, day, gameHours }
function POS_WBN_ClientListener.getHistory()
    local player = getPlayer()
    if not player then return {} end
    local md = player:getModData()
    if not md or not md.POSNET then return {} end
    local history = md.POSNET[POS_Constants.WBN_HISTORY_MODDATA_KEY]
    if not history then return {} end

    -- Collect and sort by index descending (newest first)
    local result = {}
    for k, v in pairs(history) do
        if type(v) == "table" then
            v._sortIdx = tonumber(k) or 0
            result[#result + 1] = v
        end
    end
    table.sort(result, function(a, b) return (a._sortIdx or 0) > (b._sortIdx or 0) end)
    return result
end
