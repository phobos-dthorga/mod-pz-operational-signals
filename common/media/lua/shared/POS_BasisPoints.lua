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
-- POS_BasisPoints.lua
-- BPS (basis points) to/from decimal conversion for integer
-- price storage.  1 BPS = 0.0001 (one hundredth of a percent).
---------------------------------------------------------------

require "POS_Constants"

POS_BasisPoints = {}

local BPS_DIVISOR = POS_Constants.BPS_DIVISOR  -- 10000

--- Convert a decimal value to basis points (integer).
--- @param decimal number e.g. 0.018
--- @return number e.g. 180
function POS_BasisPoints.toBps(decimal)
    if type(decimal) ~= "number" then return 0 end
    return math.floor(decimal * BPS_DIVISOR + 0.5)
end

--- Convert basis points to decimal.
--- @param bps number e.g. 180
--- @return number e.g. 0.018
function POS_BasisPoints.toDecimal(bps)
    if type(bps) ~= "number" then return 0 end
    return bps / BPS_DIVISOR
end

--- Convert basis points to a display-friendly price string.
--- @param bps number e.g. 1920
--- @return string e.g. "0.19"
function POS_BasisPoints.toDisplayPrice(bps)
    return string.format("%.2f", POS_BasisPoints.toDecimal(bps))
end

--- Apply a basis-point modifier to a base value.
--- @param baseValue number The base price/value
--- @param modifierBps number Modifier in basis points (e.g. 180 = +1.8%)
--- @return number The modified value
function POS_BasisPoints.applyBps(baseValue, modifierBps)
    if type(baseValue) ~= "number" then return 0 end
    if type(modifierBps) ~= "number" then return baseValue end
    return baseValue * (1 + modifierBps / BPS_DIVISOR)
end
