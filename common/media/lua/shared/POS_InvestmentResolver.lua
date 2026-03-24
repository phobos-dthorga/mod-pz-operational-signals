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
-- POS_InvestmentResolver.lua
-- Server-side investment maturity resolution.
--
-- Checks pending investments for maturity and resolves them
-- by rolling against actualRisk. Successful investments pay
-- out returnAmount; defaults result in loss of principal.
--
-- Pending investments stored in world modData:
--   POS_PendingResolutions = { { investmentId, username, principalAmount,
--     returnAmount, maturityDay, actualRisk } }
--
-- Offline payouts stored in world modData:
--   POS_PendingPayouts_{username} = { { investmentId, returnAmount, status } }
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_PlayerFileStore"

POS_InvestmentResolver = {}

local _TAG = "[POS:InvResolver]"

local PENDING_KEY = "POS_PendingResolutions"

--- Precision for ZombRand-based probability rolls.
local RESOLUTION_PRECISION = 10000

--- ModData key prefix for per-player pending payouts.
local PAYOUT_KEY_PREFIX = "POS_PendingPayouts_"

---------------------------------------------------------------
-- World modData accessors
---------------------------------------------------------------

--- Get the pending resolutions array from world modData.
---@return table Array of pending investment records
local function getPendingResolutions()
    return PhobosLib.getWorldModDataTable(PENDING_KEY, "entries")
end

--- Get the pending payouts array for a specific player.
---@param username string Player username
---@return table Array of payout records
local function getPendingPayouts(username)
    local key = PAYOUT_KEY_PREFIX .. username
    return PhobosLib.getWorldModDataTable(key, "entries")
end

---------------------------------------------------------------
-- Registration
---------------------------------------------------------------

--- Register a player's investment for server-side resolution tracking.
---@param username string Player username
---@param investmentId string Investment opportunity ID
---@param principalAmount number Amount invested
---@param returnAmount number Amount to return on success
---@param maturityDay number Game day when investment matures
---@param actualRisk number True default probability (0–1)
function POS_InvestmentResolver.registerInvestment(username, investmentId,
    principalAmount, returnAmount, maturityDay, actualRisk)

    local pending = getPendingResolutions()
    -- Append using explicit index (table.insert crashes on Java ModData)
    local nextIdx = 0
    for k, _ in pairs(pending) do
        if type(k) == "number" and k > nextIdx then nextIdx = k end
    end
    pending[nextIdx + 1] = {
        investmentId = investmentId,
        username = username,
        principalAmount = principalAmount,
        returnAmount = returnAmount,
        maturityDay = maturityDay,
        actualRisk = actualRisk,
        status = "pending",
    }

    PhobosLib.debug("POS", _TAG, "[InvResolver] Registered investment: " .. investmentId
        .. " for " .. username .. " (maturity day " .. maturityDay .. ")")
end

---------------------------------------------------------------
-- Resolution
---------------------------------------------------------------

--- Resolve all matured investments for the current game day.
--- Called by POS_BroadcastSystem.onEveryOneMinute().
function POS_InvestmentResolver.resolveMatured()
    local gameTime = getGameTime()
    if not gameTime then return end
    local currentDay = gameTime:getNightsSurvived()

    local pending = getPendingResolutions()

    -- Build surviving entries into a new table (rebuild approach —
    -- #, table.insert, table.remove all crash on Java ModData)
    local surviving = {}
    local survivingIdx = 1

    for _, entry in pairs(pending) do
        if type(entry) ~= "table" then
            -- skip non-table entries (ModData metadata)
        elseif entry.status == "pending" and entry.maturityDay and entry.maturityDay <= currentDay then
            -- Roll against actualRisk
            local roll = ZombRand(RESOLUTION_PRECISION) / RESOLUTION_PRECISION  -- [0, 1)
            local status
            local returnAmount = 0

            if roll < (entry.actualRisk or 0) then
                status = POS_Constants.INV_STATUS_DEFAULTED
                PhobosLib.debug("POS", _TAG, "[InvResolver] DEFAULTED: " .. (entry.investmentId or "?")
                    .. " (roll=" .. string.format("%.3f", roll)
                    .. " < risk=" .. string.format("%.3f", entry.actualRisk or 0) .. ")")
            else
                status = POS_Constants.INV_STATUS_MATURED
                returnAmount = entry.returnAmount or 0
                PhobosLib.debug("POS", _TAG, "[InvResolver] MATURED: " .. (entry.investmentId or "?")
                    .. " (roll=" .. string.format("%.3f", roll)
                    .. " >= risk=" .. string.format("%.3f", entry.actualRisk or 0)
                    .. ", payout=$" .. returnAmount .. ")")
            end

            -- Try to send to online player
            local sent = false
            local players = getOnlinePlayers and getOnlinePlayers()
            if players then
                for j = 0, players:size() - 1 do
                    local p = players:get(j)
                    if p and POS_PlayerFileStore.sanitiseUsername(p:getUsername()) == entry.username then
                        sendServerCommand(p, POS_Constants.CMD_MODULE, POS_Constants.CMD_INVESTMENT_RESOLVED, {
                            investmentId = entry.investmentId,
                            status = status,
                            returnAmount = returnAmount,
                        })
                        sent = true
                        break
                    end
                end
            end

            -- If player is offline, queue payout for later
            if not sent and entry.username then
                local payouts = getPendingPayouts(entry.username)
                -- Append using explicit index (table.insert crashes on Java ModData)
                local payNextIdx = 0
                for k, _ in pairs(payouts) do
                    if type(k) == "number" and k > payNextIdx then payNextIdx = k end
                end
                payouts[payNextIdx + 1] = {
                    investmentId = entry.investmentId,
                    status = status,
                    returnAmount = returnAmount,
                }
                PhobosLib.debug("POS", _TAG, "[InvResolver] Player " .. entry.username
                    .. " offline -- queued payout for " .. (entry.investmentId or "?"))
            end

            -- Don't add to surviving (it's resolved)
        else
            -- Not yet matured — keep in pending
            surviving[survivingIdx] = entry
            survivingIdx = survivingIdx + 1
        end
    end

    -- Replace the pending store with surviving entries only
    PhobosLib.setWorldModDataTable(PENDING_KEY, "entries", surviving)
end

---------------------------------------------------------------
-- Offline payout delivery
---------------------------------------------------------------

--- Check and deliver pending payouts for a player who just logged in.
--- Called via client command when player connects.
---@param player IsoPlayer
function POS_InvestmentResolver.deliverPendingPayouts(player)
    if not player then return end
    local username = POS_PlayerFileStore.sanitiseUsername(player:getUsername())

    local key = PAYOUT_KEY_PREFIX .. username
    local entries = PhobosLib.getWorldModDataTable(key, "entries")
    if not entries or #entries == 0 then return end

    for _, payout in ipairs(entries) do
        sendServerCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_INVESTMENT_RESOLVED, {
            investmentId = payout.investmentId,
            status = payout.status,
            returnAmount = payout.returnAmount,
        })
        PhobosLib.debug("POS", _TAG, "[InvResolver] Delivered pending payout to "
            .. username .. ": " .. payout.investmentId)
    end

    -- Clear delivered payouts
    local md = PhobosLib.getWorldModData(key)
    md.entries = {}
end

---------------------------------------------------------------
-- Client command handling
---------------------------------------------------------------

--- Handle PlayerInvested command from client.
---@param player IsoPlayer
---@param args table { investmentId, principalAmount, returnAmount, maturityDay, actualRisk }
function POS_InvestmentResolver.onPlayerInvested(player, args)
    if not player or not args then return end
    local username = POS_PlayerFileStore.sanitiseUsername(player:getUsername())

    POS_InvestmentResolver.registerInvestment(
        username,
        args.investmentId,
        args.principalAmount,
        args.returnAmount,
        args.maturityDay,
        args.actualRisk
    )

    -- Acknowledge back to client
    sendServerCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_INVESTMENT_ACK, {
        investmentId = args.investmentId,
    })
end

--- Handle RequestPendingPayouts command from client (on game start).
---@param player IsoPlayer
function POS_InvestmentResolver.onRequestPendingPayouts(player)
    POS_InvestmentResolver.deliverPendingPayouts(player)
end
