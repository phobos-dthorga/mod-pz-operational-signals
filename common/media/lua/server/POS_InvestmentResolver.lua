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

POS_InvestmentResolver = {}

local PENDING_KEY = "POS_PendingResolutions"

---------------------------------------------------------------
-- World modData accessors
---------------------------------------------------------------

--- Get the pending resolutions array from world modData.
---@return table Array of pending investment records
local function getPendingResolutions()
    local gmd = ModData.getOrCreate(PENDING_KEY)
    if not gmd.entries then
        gmd.entries = {}
    end
    return gmd.entries
end

--- Get the pending payouts array for a specific player.
---@param username string Player username
---@return table Array of payout records
local function getPendingPayouts(username)
    local key = "POS_PendingPayouts_" .. username
    local gmd = ModData.getOrCreate(key)
    if not gmd.entries then
        gmd.entries = {}
    end
    return gmd.entries
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
    table.insert(pending, {
        investmentId = investmentId,
        username = username,
        principalAmount = principalAmount,
        returnAmount = returnAmount,
        maturityDay = maturityDay,
        actualRisk = actualRisk,
        status = "pending",
    })

    PhobosLib.debug("POS", "[InvResolver] Registered investment: " .. investmentId
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
    local resolved = {}

    for i = #pending, 1, -1 do
        local entry = pending[i]
        if entry.status == "pending" and entry.maturityDay <= currentDay then
            -- Roll against actualRisk
            local roll = ZombRand(10000) / 10000  -- [0, 1)
            local status
            local returnAmount = 0

            if roll < entry.actualRisk then
                status = "defaulted"
                PhobosLib.debug("POS", "[InvResolver] DEFAULTED: " .. entry.investmentId
                    .. " (roll=" .. string.format("%.3f", roll)
                    .. " < risk=" .. string.format("%.3f", entry.actualRisk) .. ")")
            else
                status = "matured"
                returnAmount = entry.returnAmount
                PhobosLib.debug("POS", "[InvResolver] MATURED: " .. entry.investmentId
                    .. " (roll=" .. string.format("%.3f", roll)
                    .. " >= risk=" .. string.format("%.3f", entry.actualRisk)
                    .. ", payout=$" .. returnAmount .. ")")
            end

            -- Try to send to online player
            local sent = false
            local players = getOnlinePlayers()
            if players then
                for j = 0, players:size() - 1 do
                    local p = players:get(j)
                    if p and p:getUsername() == entry.username then
                        sendServerCommand(p, "POS", "InvestmentResolved", {
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
            if not sent then
                local payouts = getPendingPayouts(entry.username)
                table.insert(payouts, {
                    investmentId = entry.investmentId,
                    status = status,
                    returnAmount = returnAmount,
                })
                PhobosLib.debug("POS", "[InvResolver] Player " .. entry.username
                    .. " offline — queued payout for " .. entry.investmentId)
            end

            table.insert(resolved, i)
        end
    end

    -- Remove resolved entries (reverse order to maintain indices)
    for _, idx in ipairs(resolved) do
        table.remove(pending, idx)
    end
end

---------------------------------------------------------------
-- Offline payout delivery
---------------------------------------------------------------

--- Check and deliver pending payouts for a player who just logged in.
--- Called via client command when player connects.
---@param player IsoPlayer
function POS_InvestmentResolver.deliverPendingPayouts(player)
    if not player then return end
    local username = player:getUsername()
    if not username then return end

    local key = "POS_PendingPayouts_" .. username
    local gmd = ModData.getOrCreate(key)
    if not gmd.entries or #gmd.entries == 0 then return end

    for _, payout in ipairs(gmd.entries) do
        sendServerCommand(player, "POS", "InvestmentResolved", {
            investmentId = payout.investmentId,
            status = payout.status,
            returnAmount = payout.returnAmount,
        })
        PhobosLib.debug("POS", "[InvResolver] Delivered pending payout to "
            .. username .. ": " .. payout.investmentId)
    end

    -- Clear delivered payouts
    gmd.entries = {}
end

---------------------------------------------------------------
-- Client command handling
---------------------------------------------------------------

--- Handle PlayerInvested command from client.
---@param player IsoPlayer
---@param args table { investmentId, principalAmount, returnAmount, maturityDay, actualRisk }
function POS_InvestmentResolver.onPlayerInvested(player, args)
    if not player or not args then return end
    local username = player:getUsername()
    if not username then return end

    POS_InvestmentResolver.registerInvestment(
        username,
        args.investmentId,
        args.principalAmount,
        args.returnAmount,
        args.maturityDay,
        args.actualRisk
    )

    -- Acknowledge back to client
    sendServerCommand(player, "POS", "InvestmentAcknowledged", {
        investmentId = args.investmentId,
    })
end

--- Handle RequestPendingPayouts command from client (on game start).
---@param player IsoPlayer
function POS_InvestmentResolver.onRequestPendingPayouts(player)
    POS_InvestmentResolver.deliverPendingPayouts(player)
end
