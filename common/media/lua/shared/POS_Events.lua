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
-- POS_Events.lua
-- POSnet internal event bus built on Starlit's LuaEvent.
-- Provides named events that subsystems emit and UI/extensions
-- subscribe to, enabling loose coupling across the mod.
--
-- Usage:
--   Emit:      POS_Events.OnMarketSnapshotUpdated:trigger({ categoryId = "fuel" })
--   Subscribe: POS_Events.OnMarketSnapshotUpdated:addListener(function(data) ... end)
--   Remove:    POS_Events.OnMarketSnapshotUpdated:removeListener(myFn)
--
-- See design-guidelines.md §40 for integration roadmap.
---------------------------------------------------------------

local LuaEvent = require("Starlit/LuaEvent")

POS_Events = {}

---------------------------------------------------------------
-- Connection & Signal
---------------------------------------------------------------

--- Fired when the radio link state changes (connected/disconnected).
--- Payload: { connected = boolean, signalStrength = number }
POS_Events.OnConnectionStateChanged = LuaEvent.new("POS.OnConnectionStateChanged")

--- Fired when the active band changes (tactical/operations).
--- Payload: { band = string }
POS_Events.OnBandChanged = LuaEvent.new("POS.OnBandChanged")

--- Fired when signal strength changes significantly.
--- Payload: { signalStrength = number, quality = string }
POS_Events.OnSignalStateChanged = LuaEvent.new("POS.OnSignalStateChanged")

---------------------------------------------------------------
-- Market & Economy
---------------------------------------------------------------

--- Fired when a new market observation is ingested (ambient, recon, agent).
--- Payload: { categoryId = string, sourceType = string, recordId = string }
POS_Events.OnMarketSnapshotUpdated = LuaEvent.new("POS.OnMarketSnapshotUpdated")

--- Fired when the daily economy tick completes.
--- Payload: { day = number }
POS_Events.OnStockTickClosed = LuaEvent.new("POS.OnStockTickClosed")

--- Fired when a market event fires in a zone (bulk arrival, convoy delay, etc.).
--- Payload: { eventId = string, zoneId = string, signalClass = string,
---            pressure = number, categories = table }
POS_Events.OnMarketEvent = LuaEvent.new("POS.OnMarketEvent")

--- Fired when a buy/sell trade transaction completes.
--- Payload: { fullType = string, quantity = number, totalPrice = number, isBuy = boolean }
POS_Events.OnTradeCompleted = LuaEvent.new("POS.OnTradeCompleted")

---------------------------------------------------------------
-- Intelligence & Discovery
---------------------------------------------------------------

--- Fired when ambient intel generates new observations.
--- Payload: { count = number, categories = table }
POS_Events.OnAmbientIntelReceived = LuaEvent.new("POS.OnAmbientIntelReceived")

--- Fired when a new item is discovered in the trade catalog.
--- Payload: { fullType = string, categoryId = string }
POS_Events.OnItemDiscovered = LuaEvent.new("POS.OnItemDiscovered")

---------------------------------------------------------------
-- Missions & Operations
---------------------------------------------------------------

--- Fired when a new mission/operation is generated and available.
--- Payload: { missionId = string, category = string, difficulty = number }
POS_Events.OnMissionGenerated = LuaEvent.new("POS.OnMissionGenerated")

--- Fired when a mission/operation is completed.
--- Payload: { missionId = string, success = boolean, rewardCash = number }
POS_Events.OnMissionCompleted = LuaEvent.new("POS.OnMissionCompleted")

---------------------------------------------------------------
-- Contracts (§43)
---------------------------------------------------------------

--- Fired when a new sell-side contract is posted (available).
--- Payload: { contractId = string, kind = string }
POS_Events.OnContractPosted = LuaEvent.new("POS.OnContractPosted")

--- Fired when a player accepts a contract.
--- Payload: { contractId = string }
POS_Events.OnContractAccepted = LuaEvent.new("POS.OnContractAccepted")

--- Fired when a contract is fulfilled and settled.
--- Payload: { contractId = string, fullType = string, quantity = number, payout = number }
POS_Events.OnContractFulfilled = LuaEvent.new("POS.OnContractFulfilled")

--- Fired when a grey-market contract results in betrayal.
--- Payload: { contractId = string }
POS_Events.OnContractBetrayted = LuaEvent.new("POS.OnContractBetrayted")

---------------------------------------------------------------
-- Free Agent System (§46)
---------------------------------------------------------------

--- Fired when a free agent is deployed into the field.
--- Payload: { agentId = string, archetype = string, zoneId = string }
POS_Events.OnFreeAgentDeployed = LuaEvent.new("POS.OnFreeAgentDeployed")

--- Fired when a free agent's state changes (transit, delayed, etc.).
--- Payload: { agentId = string, prevState = string, newState = string, agentName = string }
POS_Events.OnFreeAgentStateChanged = LuaEvent.new("POS.OnFreeAgentStateChanged")

---------------------------------------------------------------
-- UI & Screen Events
---------------------------------------------------------------

--- Fired when any system needs the terminal screen to refresh.
--- Payload: nil (no data; subscribers call refreshCurrentScreen)
POS_Events.OnScreenRefreshRequested = LuaEvent.new("POS.OnScreenRefreshRequested")

--- Fired when a quantity changes on a buy/sell screen (+/- buttons).
--- Payload: { fullType = string, newQuantity = number }
POS_Events.OnQuantityChanged = LuaEvent.new("POS.OnQuantityChanged")

---------------------------------------------------------------
-- UI & Background
---------------------------------------------------------------

--- Fired to request a screen refresh (e.g. after data changes).
--- Payload: { screenId = string? } (nil = refresh all)
POS_Events.OnScreenInvalidationRequested = LuaEvent.new("POS.OnScreenInvalidationRequested")

--- Fired when a background process starts, progresses, or completes.
--- Payload: { processId = string, label = string, progress = number (0-100), complete = boolean }
POS_Events.OnBackgroundProcessChanged = LuaEvent.new("POS.OnBackgroundProcessChanged")

---------------------------------------------------------------
-- World Broadcast Network (WBN)
---------------------------------------------------------------

--- Fired when a WBN broadcast is received and processed.
--- Payload: { domain = string, eventType = string, severity = number,
---            confidence = number, zoneId = string?, data = table }
POS_Events.OnBroadcastReceived = LuaEvent.new("POS.OnBroadcastReceived")

--- Fired when a signal fragment is generated from a broadcast.
--- Payload: { fragmentId = string, domain = string, confidence = number,
---            sourceEventType = string }
POS_Events.OnSignalFragmentGenerated = LuaEvent.new("POS.OnSignalFragmentGenerated")
