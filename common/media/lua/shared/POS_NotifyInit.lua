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
-- POS_NotifyInit.lua
-- Registers the POSnet notification channel with
-- PhobosNotifications (if installed) on game start.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

local function onGameStart()
    if not PhobosNotifications or not PhobosNotifications.registerChannel then
        PhobosLib.debug("POS", "[NotifyInit]",
            "PhobosNotifications not available — skipping channel registration")
        return
    end

    PhobosNotifications.registerChannel({
        id = POS_Constants.PN_CHANNEL_ID,
        labelKey = POS_Constants.PN_CHANNEL_LABEL_KEY,
        defaultEnabled = true,
    })

    PhobosLib.debug("POS", "[NotifyInit]",
        "Registered PN channel: " .. POS_Constants.PN_CHANNEL_ID)
end

Events.OnGameStart.Add(onGameStart)
