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
-- POS_NotificationChannels.lua
-- Registers PhobosNotifications channels for POSnet so players
-- can mute notification categories independently.
--
-- 6 channels: agents, contracts, market, trade, intel, signal.
-- Registered on game start, guarded by PN availability check.
--
-- See design-guidelines.md §46.8.
---------------------------------------------------------------

require "POS_Constants"

POS_NotificationChannels = {}

local _registered = false

--- Register all POSnet notification channels with PhobosNotifications.
--- Safe to call multiple times (idempotent).
function POS_NotificationChannels.init()
    if _registered then return end
    _registered = true

    -- Guard: only register if PhobosNotifications is available
    if not PN_ChannelRegistry or not PN_ChannelRegistry.register then return end

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_AGENTS,
        name        = "POSnet Field Agents",
        description = "Agent deployment, transit, and settlement updates",
        defaultEnabled = true,
    })

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_CONTRACTS,
        name        = "POSnet Contracts",
        description = "Contract accept, fulfil, expire, and betrayal notifications",
        defaultEnabled = true,
    })

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_MARKET,
        name        = "POSnet Market Events",
        description = "Market disruptions, zone events, and economy alerts",
        defaultEnabled = true,
    })

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_TRADE,
        name        = "POSnet Trading",
        description = "Buy and sell confirmations, transaction receipts",
        defaultEnabled = true,
    })

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_INTEL,
        name        = "POSnet Intelligence",
        description = "Item discoveries, ambient intel observations",
        defaultEnabled = true,
    })

    PN_ChannelRegistry.register({
        id          = POS_Constants.PN_CHANNEL_SIGNAL,
        name        = "POSnet Signal Quality",
        description = "Receiver quality warnings and signal status",
        defaultEnabled = true,
    })
end

--- Register channels on game start.
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(POS_NotificationChannels.init)
end
