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

    -- Check for duplicate
    for i = 1, #opps do
        if opps[i].id == opportunity.id then
            return false
        end
    end

    table.insert(opps, opportunity)
    POS_ScreenManager.markDirty()
    PhobosLib.debug("POS", "[InvLog] Opportunity added: " .. opportunity.id)
    return true
end

--- Get all open (non-expired) opportunities.
---@return table Array of opportunity tables
function POS_InvestmentLog.getOpenOpportunities()
    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)
    local gameTime = getGameTime()
    local currentDay = gameTime and gameTime:getNightsSurvived() or 0
    local results = {}

    for i = 1, #opps do
        local opp = opps[i]
        if opp.status == POS_Constants.OPP_STATUS_OPEN
           and (not opp.expiryDay or opp.expiryDay > currentDay) then
            table.insert(results, opp)
        end
    end

    return results
end

--- Get a specific opportunity by ID.
---@param opportunityId string
---@return table|nil
function POS_InvestmentLog.getOpportunity(opportunityId)
    local opps = getStore(POS_Constants.MODDATA_OPPORTUNITIES)
    for i = 1, #opps do
        if opps[i].id == opportunityId then
            return opps[i]
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

    table.insert(investments, record)
    POS_ScreenManager.markDirty()
    PhobosLib.debug("POS", "[InvLog] Investment recorded: " .. opportunityId
        .. " ($" .. principalAmount .. " → $" .. returnAmount .. ")")
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
    for i = 1, #all do
        if all[i].status == status then
            table.insert(results, all[i])
        end
    end
    return results
end

--- Count active investments.
---@return number
function POS_InvestmentLog.countActiveInvestments()
    local all = POS_InvestmentLog.getAllInvestments()
    local count = 0
    for i = 1, #all do
        if all[i].status == POS_Constants.INV_STATUS_ACTIVE then
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
    for i = 1, #all do
        if all[i].investmentId == investmentId
           and all[i].status == POS_Constants.INV_STATUS_ACTIVE then
            POS_InvestmentService.resolveInvestment(all[i], status)
            POS_ScreenManager.markDirty()
            PhobosLib.debug("POS", "[InvLog] Investment resolved: " .. investmentId
                .. " → " .. status)
            return all[i]
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

    -- Request any pending payouts from server (offline resolution)
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, POS_Constants.CMD_MODULE, POS_Constants.CMD_REQUEST_PAYOUTS, {})
    end

    PhobosLib.debug("POS", "Investment log initialised")
end

Events.OnGameStart.Add(POS_InvestmentLog.init)
