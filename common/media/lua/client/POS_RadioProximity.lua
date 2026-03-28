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
-- POS_RadioProximity.lua
-- POSnet wrapper over PhobosLib_Radio.findNearbyTunedRadio().
--
-- Checks whether the player is near a powered, unmuted radio
-- tuned to a POSnet data band (operations or tactical).
-- Used to gate intelligence intercept reception.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_RadioProximity = {}

local _TAG = "[POS:RadioProx]"

--- Check if the player is near a powered, audible radio tuned to a
--- POSnet data band. Delegates to PhobosLib_Radio.findNearbyTunedRadio()
--- with POSnet's AZAS frequency matcher.
---
--- A qualifying radio must be:
---   - Powered on (battery or grid)
---   - Volume above POS_Constants.RADIO_MIN_VOLUME_THRESHOLD
---   - Tuned to a POSnet data band (operations or tactical, not WBN broadcast)
---   - Within hearing range (inventory/vehicle = always; world = HasPlayerInRange())
---
---@param player any IsoPlayer
---@return boolean inRange True if at least one qualifying radio found
function POS_RadioProximity.isPlayerNearTunedRadio(player)
    if not player then return false end

    if not PhobosLib_Radio or not PhobosLib_Radio.findNearbyTunedRadio then
        PhobosLib.debug("POS", _TAG, "PhobosLib_Radio.findNearbyTunedRadio not available")
        return true -- graceful fallback: allow intercepts if API missing
    end

    local radio, _ = PhobosLib_Radio.findNearbyTunedRadio(player, {
        frequencyMatch = function(channel)
            local band = POS_AZASIntegration
                and POS_AZASIntegration.matchFrequency
                and POS_AZASIntegration.matchFrequency(channel)
            -- Only data bands (ops/tactical) deliver intercepts.
            -- WBN broadcast bands are receive-only atmosphere.
            if band and POS_AZASIntegration.isBroadcastBand
                    and POS_AZASIntegration.isBroadcastBand(band) then
                return nil
            end
            return band
        end,
        scanRadius = POS_Constants.WORLD_RADIO_SCAN_RADIUS,
        minVolume  = POS_Constants.RADIO_MIN_VOLUME_THRESHOLD,
    })

    return radio ~= nil
end
