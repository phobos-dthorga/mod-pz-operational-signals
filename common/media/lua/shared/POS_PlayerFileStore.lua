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
-- POS_PlayerFileStore.lua
-- Username sanitisation utility (retained for POS_InvestmentResolver).
--
-- Historical note: this module formerly provided per-player
-- file-backed storage for watchlist/alerts/orders/holdings.
-- That functionality has been migrated to player modData
-- (see POS_PlayerState.lua) because getFileReader caused
-- silent JVM crashes in multiple PZ lifecycle contexts.
---------------------------------------------------------------

require "PhobosLib"

POS_PlayerFileStore = {}

--- Sanitise a raw PZ username for use as a modData key or filename.
--- Delegates to PhobosLib.sanitiseUsername.
---@param raw string Raw username from player:getUsername()
---@return string Sanitised username
function POS_PlayerFileStore.sanitiseUsername(raw)
    return PhobosLib.sanitiseUsername(raw, "singleplayer")
end
