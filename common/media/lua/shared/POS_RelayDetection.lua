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
-- POS_RelayDetection.lua
-- Detects satellite dish sprites on civic buildings and
-- determines if they qualify as Tier V relay sites.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_Constants_Relay"

POS_RelayDetection = {}
local _TAG = "POS:RelayDetect"

---------------------------------------------------------------
-- Sprite Detection
---------------------------------------------------------------

--- Check if a world object is a satellite dish sprite matching
--- the Tier V relay dish sprite list.
---@param isoObject IsoObject
---@return boolean
function POS_RelayDetection.isRelayDish(isoObject)
    if not isoObject then return false end

    local sprites = POS_Constants.RELAY_DISH_SPRITES
    if not sprites or #sprites == 0 then return false end

    local ok, spriteName = PhobosLib.safecall(function()
        local sprite = isoObject:getSprite()
        return sprite and sprite:getName()
    end)
    if not ok or not spriteName then return false end

    for _, name in ipairs(sprites) do
        if spriteName == name then return true end
    end
    return false
end

---------------------------------------------------------------
-- Site Qualification
---------------------------------------------------------------

--- Check if a square qualifies as a Tier V relay site.
--- Uses a pragmatic heuristic: dishes at z > 0 (rooftop) are
--- considered permanent civic installations. Dishes at z == 0
--- are likely player-placed (Tier IV) and handled separately.
---@param sq IsoGridSquare
---@return boolean
function POS_RelayDetection.isRelaySite(sq)
    if not sq then return false end

    local ok, z = PhobosLib.safecall(function() return sq:getZ() end)
    if not ok then return false end

    -- Rooftop dish implies permanent installation (civic building)
    return z ~= nil and z > 0
end

---------------------------------------------------------------
-- Discovery State
---------------------------------------------------------------

--- Check if a relay site at the given square has already been
--- discovered and registered.
---@param sq IsoGridSquare
---@return boolean
function POS_RelayDetection.isAlreadyDiscovered(sq)
    if not sq then return false end

    local ok, siteId = PhobosLib.safecall(function()
        return "relay_" .. tostring(sq:getX()) .. "_" .. tostring(sq:getY()) .. "_" .. tostring(sq:getZ())
    end)
    if not ok or not siteId then return false end

    local relay = POS_StrategicRelayService.getRelay(siteId)
    return relay ~= nil
end

---------------------------------------------------------------
-- Full Validation
---------------------------------------------------------------

--- Full pre-discovery validation for a relay dish.
--- Checks sprite match, site qualification, discovery state,
--- and player proximity.
---@param player IsoPlayer
---@param sq IsoGridSquare
---@return boolean canDiscover
---@return string reason Human-readable reason key if cannot discover
function POS_RelayDetection.canDiscover(player, sq)
    if not player or not sq then
        return false, "invalid_args"
    end

    -- Check objects on the square for a relay dish
    local hasDish = false
    local ok, objCount = PhobosLib.safecall(function() return sq:getObjects():size() end)
    if ok and objCount then
        for i = 0, objCount - 1 do
            local ok2, obj = PhobosLib.safecall(function() return sq:getObjects():get(i) end)
            if ok2 and obj and POS_RelayDetection.isRelayDish(obj) then
                hasDish = true
                break
            end
        end
    end
    if not hasDish then
        return false, "UI_POS_Relay_NotARelay"
    end

    -- Check site qualification (rooftop heuristic)
    if not POS_RelayDetection.isRelaySite(sq) then
        return false, "UI_POS_Relay_NotARelay"
    end

    -- Check not already discovered
    if POS_RelayDetection.isAlreadyDiscovered(sq) then
        return false, "UI_POS_Relay_AlreadyDiscovered"
    end

    -- Check player proximity
    local ok3, dist = PhobosLib.safecall(function()
        local px = player:getX()
        local py = player:getY()
        local sx = sq:getX()
        local sy = sq:getY()
        return math.sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy))
    end)
    if not ok3 or not dist then
        return false, "invalid_args"
    end
    if dist > POS_Constants.RELAY_DISCOVERY_RANGE then
        return false, "UI_POS_Relay_TooFar"
    end

    return true, nil
end
