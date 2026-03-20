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
-- POS_InvestmentService.lua
-- Shared service for investment lifecycle management.
-- Encapsulates opportunity funding, expiry, investment record
-- creation, and resolution. POS_InvestmentLog delegates all
-- status mutations here.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"

POS_InvestmentService = {}

---------------------------------------------------------------
-- Opportunity lifecycle
---------------------------------------------------------------

--- Mark an opportunity as funded (player has invested).
---@param opportunity table The opportunity to mark
function POS_InvestmentService.fundOpportunity(opportunity, player)
    if not opportunity then return end
    opportunity.status = POS_Constants.OPP_STATUS_FUNDED

    -- Tutorial: first investment milestone
    if player and POS_TutorialService and POS_TutorialService.tryAward then
        POS_TutorialService.tryAward(player, POS_Constants.TUTORIAL_FIRST_INVESTMENT)
    end
end

--- Expire opportunities whose deadline has passed.
---@param opportunities table Array of opportunity tables
---@param currentDay number Current game day (nightsSurvived)
function POS_InvestmentService.expireOpportunities(opportunities, currentDay)
    if not opportunities or not currentDay then return end
    for i = 1, #opportunities do
        local opp = opportunities[i]
        if opp.status == POS_Constants.OPP_STATUS_OPEN
           and opp.expiryDay and opp.expiryDay <= currentDay then
            opp.status = POS_Constants.OPP_STATUS_EXPIRED
        end
    end
end

---------------------------------------------------------------
-- Investment records
---------------------------------------------------------------

--- Create an investment record table.
---@param opportunityId string The opportunity being invested in
---@param principalAmount number Amount invested
---@param returnAmount number Expected return on success
---@param maturityDay number Game day when investment matures
---@param actualRisk number True risk (frozen from opportunity)
---@param posterName string Display name of the poster
---@param currentDay number Current game day
---@return table Investment record
function POS_InvestmentService.createInvestmentRecord(
    opportunityId, principalAmount, returnAmount,
    maturityDay, actualRisk, posterName, currentDay)

    return {
        investmentId = opportunityId,
        posterName = posterName or "Unknown",
        principalAmount = principalAmount,
        returnAmount = returnAmount,
        investedDay = currentDay or 0,
        maturityDay = maturityDay,
        actualRisk = actualRisk,
        status = POS_Constants.INV_STATUS_ACTIVE,
    }
end

--- Resolve an investment (matured or defaulted).
---@param investment table The investment record
---@param status string POS_Constants.INV_STATUS_MATURED or INV_STATUS_DEFAULTED
function POS_InvestmentService.resolveInvestment(investment, status)
    if not investment then return end
    investment.status = status
end

---------------------------------------------------------------
-- Tick handler
---------------------------------------------------------------

local lastCheckHour = -1

--- Periodic housekeeping — expire old opportunities.
--- Should be called from EveryOneMinute (hourly gated).
function POS_InvestmentService.onEveryOneMinute()
    local gameTime = getGameTime()
    if not gameTime then return end
    local hour = gameTime:getHour()
    if hour == lastCheckHour then return end
    lastCheckHour = hour

    if POS_InvestmentLog and POS_InvestmentLog.getOpportunitiesStore then
        local opps = POS_InvestmentLog.getOpportunitiesStore()
        local currentDay = gameTime:getNightsSurvived()
        POS_InvestmentService.expireOpportunities(opps, currentDay)
    end
end

--- Initialise the investment service tick handler.
function POS_InvestmentService.init()
    Events.EveryOneMinute.Add(POS_InvestmentService.onEveryOneMinute)
    PhobosLib.debug("POS", "Investment service initialised")
end
