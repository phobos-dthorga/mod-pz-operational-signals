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
-- POS_InvestmentLog.lua
-- Client-side investment tracking — persistence layer.
--
-- Stores two types of data in player modData:
--   POS_Constants.MODDATA_OPPORTUNITIES — available BBS investment posts
--   POS_Constants.MODDATA_INVESTMENTS   — player's personal investment records
--
-- Opportunities are transient (expire, replaced by new broadcasts).
-- Investments persist until resolved (matured or defaulted).
-- All business logic (funding, expiry, resolution) is in
-- POS_InvestmentService.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_InvestmentService"

POS_InvestmentLog = {}

local _TAG = "[POS:InvLog]"

---------------------------------------------------------------
-- ModData accessors
---------------------------------------------------------------

--- Get the player modData store for a given key.
---@param key string ModData key
---@return table Array stored under the key
local function getStore(key)
    local player = getSpecificPlayer(0)
    if not player then return {} end
    local md = PhobosLib.getModData(player)
    if not md then return {} end
    if not md[key] then
        md[key] = {}
    end
    return md[key]
end

--- Public accessor for opportunities store (used by POS_InvestmentService).
---@return table Array of opportunity tables
function POS_InvestmentLog.getOpportunitiesStore()
    return getStore(POS_Constants.MODDATA_OPPORTUNITIES)
end

---------------------------------------------------------------
-- Opportunities (available BBS posts)
---------------------------------------------------------------

--- Add an investment opportunity received from broadcast.
---@param opportunity table Opportunity data from InvestmentGenerator
---@return boolean True if added (not duplicate)
function POS_InvestmentLog.addOpportunity(opportunity)
    if not opportunity or not opportunity.id then return false end

    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)

    -- Check for duplicate (pairs() for ModData compatibility — # crashes on Java tables)
    for _, opp in pairs(opps) do
        if type(opp) == "table" and opp.id == opportunity.id then
            return false
        end
    end

    -- Append using explicit index (table.insert crashes on ModData)
    local nextIdx = 0
    for k, _ in pairs(opps) do
        if type(k) == "number" and k > nextIdx then nextIdx = k end
    end
    opps[nextIdx + 1] = opportunity
    POS_ScreenManager.markDirty()
    PhobosLib.debug("POS", _TAG, "[InvLog] Opportunity added: " .. opportunity.id)
    return true
end

--- Get all open (non-expired) opportunities.
---@return table Array of opportunity tables
function POS_InvestmentLog.getOpenOpportunities()
    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)
    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0
    local results = {}

    for _, opp in pairs(opps) do
        if type(opp) == "table"
                and opp.status == POS_Constants.OPP_STATUS_OPEN
                and (not opp.expiryDay or opp.expiryDay > currentDay) then
            results[#results + 1] = opp
        end
    end

    return results
end

--- Get a specific opportunity by ID.
---@param opportunityId string
---@return table|nil
function POS_InvestmentLog.getOpportunity(opportunityId)
    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)
    for _, opp in pairs(opps) do
        if type(opp) == "table" and opp.id == opportunityId then
            return opp
        end
    end
    return nil
end

--- Mark an opportunity as funded (invested).
--- Delegates to POS_InvestmentService.
---@param opportunityId string
---@param player IsoPlayer|nil Optional player for tutorial tracking
function POS_InvestmentLog.markOpportunityFunded(opportunityId, player)
    local opp = POS_InvestmentLog.getOpportunity(opportunityId)
    if opp then
        POS_InvestmentService.fundOpportunity(opp, player)
    end
end

--- Expire old opportunities.
--- Delegates to POS_InvestmentService.
function POS_InvestmentLog.expireOpportunities()
    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)
    local gameTime = getGameTime()
    if not gameTime then return end
    local currentDay = gameTime:getNightsSurvived()
    POS_InvestmentService.expireOpportunities(opps, currentDay)
end

---------------------------------------------------------------
-- Player investments
---------------------------------------------------------------

--- Record a player's investment.
--- Uses POS_InvestmentService to create the record.
---@param opportunityId string The opportunity being invested in
---@param principalAmount number Amount invested
---@param returnAmount number Expected return on success
---@param maturityDay number Game day when investment matures
---@param actualRisk number True risk (frozen from opportunity)
---@param posterName string Display name of the poster
function POS_InvestmentLog.recordInvestment(opportunityId, principalAmount,
    returnAmount, maturityDay, actualRisk, posterName)

    local investments = getStore(POS_Constants.MODDATA_INVESTMENTS)

    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0

    local record = POS_InvestmentService.createInvestmentRecord(
        opportunityId, principalAmount, returnAmount,
        maturityDay, actualRisk, posterName, currentDay)

    -- Append using explicit index (table.insert crashes on Java ModData)
    local nextIdx = 0
    for k, _ in pairs(investments) do
        if type(k) == "number" and k > nextIdx then nextIdx = k end
    end
    investments[nextIdx + 1] = record
    POS_ScreenManager.markDirty()
    PhobosLib.debug("POS", _TAG, "[InvLog] Investment recorded: " .. opportunityId
        .. " ($" .. principalAmount .. " -> $" .. returnAmount .. ")")
end

--- Get all player investments.
---@return table Array of investment records
function POS_InvestmentLog.getAllInvestments()
    return getStore(POS_Constants.MODDATA_INVESTMENTS)
end

--- Get investments filtered by status.
---@param status string "active", "matured", or "defaulted"
---@return table Array of matching investment records
function POS_InvestmentLog.getInvestmentsByStatus(status)
    local all = POS_InvestmentLog.getAllInvestments()
    local results = {}
    for _, inv in pairs(all) do
        if type(inv) == "table" and inv.status == status then
            results[#results + 1] = inv
        end
    end
    return results
end

--- Count active investments.
---@return number
function POS_InvestmentLog.countActiveInvestments()
    local all = POS_InvestmentLog.getAllInvestments()
    local count = 0
    for _, inv in pairs(all) do
        if type(inv) == "table" and inv.status == POS_Constants.INV_STATUS_ACTIVE then
            count = count + 1
        end
    end
    return count
end

--- Resolve an investment (called when server sends InvestmentResolved).
--- Delegates status mutation to POS_InvestmentService.
---@param investmentId string
---@param status string POS_Constants.INV_STATUS_MATURED or INV_STATUS_DEFAULTED
---@return table|nil The resolved investment record
function POS_InvestmentLog.resolveInvestment(investmentId, status)
    local all = POS_InvestmentLog.getAllInvestments()
    for _, inv in pairs(all) do
        if type(inv) == "table" and inv.investmentId == investmentId
                and inv.status == POS_Constants.INV_STATUS_ACTIVE then
            POS_InvestmentService.resolveInvestment(inv, status)
            POS_ScreenManager.markDirty()
            PhobosLib.debug("POS", _TAG, "[InvLog] Investment resolved: " .. investmentId
                .. " -> " .. status)
            return inv
        end
    end
    return nil
end

---------------------------------------------------------------
-- Tick handler
---------------------------------------------------------------

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------

function POS_InvestmentLog.init()
    POS_InvestmentService.init()
    PhobosLib.debug("POS", _TAG, "Investment log initialised")
end

--- Deferred payout request — sendClientCommand during init can crash
--- the JVM in SP. Runs once on first EveryOneMinute tick.
local payoutRequested = false
local function onDeferredPayoutRequest()
    if payoutRequested then return end
    payoutRequested = true
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_REQUEST_PAYOUTS, {})
        PhobosLib.debug("POS", _TAG, "Deferred payout request sent")
    end
end

Events.OnGameStart.Add(function()
    POS_InvestmentLog.init()
    Events.EveryOneMinute.Add(onDeferredPayoutRequest)
end)
