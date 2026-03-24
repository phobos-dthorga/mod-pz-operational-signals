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
-- POS_Screen_Assignments.lua
-- Consolidated tabbed mission view combining recon operations
-- and courier deliveries into a single screen with three tabs:
-- Active, Available, and History.
-- Replaces: POS_Screen_Operations + POS_Screen_Deliveries
---------------------------------------------------------------

require "PhobosLib"
require "PhobosLib_DualTab"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_Reputation"
require "POS_ReconGenerator"
require "POS_DeliveryGenerator"
require "POS_RewardCalculator"
require "POS_BuildingCache"
require "POS_MapMarkers"
require "POS_OperationLog"
require "POS_OperationService"
require "POS_PathTracker"
require "PhobosLib_Pagination"
require "PhobosLib_Address"
require "POS_API"

---------------------------------------------------------------

local _TAG = "[POS:Assignments]"

--- Tier colour coding (recon tiers I-IV).
local TIER_COLOURS

--- Resolve address or fall back to coordinates.
---@param x number
---@param y number
---@return string
local function formatLocation(x, y)
    if PhobosLib_Address and PhobosLib_Address.resolveAddress then
        local addr = PhobosLib_Address.resolveAddress(x, y)
        if addr and addr.street then
            return PhobosLib_Address.formatAddress(addr)
        end
    end
    return math.floor(x) .. ", " .. math.floor(y)
end

---------------------------------------------------------------
-- Data helpers
---------------------------------------------------------------

--- Find the active recon operation.
---@return table|nil
local function getActiveRecon()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_ACTIVE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.MISSION_TYPE_RECON then
            return op
        end
    end
    return nil
end

--- Find the active delivery operation.
---@return table|nil
local function getActiveDelivery()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_ACTIVE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            return op
        end
    end
    return nil
end

--- Get available recon operations (tier-filtered by connected band).
---@return table[]
local function getAvailableRecons()
    if not POS_OperationLog then return {} end

    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or "operations"
    local minTier = band == "tactical" and 3 or 1
    local maxTier = band == "tactical" and 4 or 2

    local results = {}
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_AVAILABLE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.MISSION_TYPE_RECON then
            local tier = op.tier or 1
            if tier >= minTier and tier <= maxTier then
                table.insert(results, op)
            end
        end
    end

    -- On-demand generation if none available
    if #results == 0 then
        local player = getSpecificPlayer(0)
        if player then
            local op = POS_OperationService.generateAndRegister(player, minTier, maxTier)
            if op then
                table.insert(results, op)
            end
        end
    end

    return results
end

--- Get available delivery operations with on-demand generation.
---@return table[]
local function getAvailableDeliveries()
    if not POS_OperationLog then return {} end

    local results = {}
    local ops = POS_OperationLog.getByStatus(POS_Constants.STATUS_AVAILABLE)
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            table.insert(results, op)
        end
    end

    -- On-demand generation
    if #results == 0 then
        local player = getSpecificPlayer(0)
        if player then
            local delivery = POS_DeliveryGenerator.generate(player)
            if delivery then
                POS_OperationLog.addOperation(delivery)
                table.insert(results, delivery)
            end
        end
    end

    return results
end

--- Get recently completed/expired/cancelled operations (recons + deliveries).
---@return table[]
local function getHistoryEntries()
    if not POS_OperationLog then return {} end
    local results = {}

    local statuses = {
        POS_Constants.STATUS_COMPLETED,
        POS_Constants.STATUS_EXPIRED,
        POS_Constants.STATUS_CANCELLED,
    }

    for _, status in ipairs(statuses) do
        local ops = POS_OperationLog.getByStatus(status)
        for _, op in ipairs(ops) do
            table.insert(results, op)
        end
    end

    -- Sort by completion day descending
    table.sort(results, function(a, b)
        return (a.completedDay or a.day or 0) > (b.completedDay or b.day or 0)
    end)

    -- Return only the last N
    local limit = POS_Constants.OPERATIONS_COMPLETED_DISPLAY
    if #results > limit then
        local trimmed = {}
        for i = 1, limit do
            trimmed[i] = results[i]
        end
        return trimmed
    end

    return results
end

--- Determine the type badge text and colour for an operation.
---@param op table  Operation record
---@param C table   COLOURS table
---@return string badgeText, table badgeColour
local function getTypeBadge(op, C)
    if op.objectives and op.objectives[1] then
        local objType = op.objectives[1].type
        if objType == POS_Constants.MISSION_TYPE_RECON then
            return "UI_POS_Assignments_TypeRecon", C.textBright
        elseif objType == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
            return "UI_POS_Assignments_TypeDelivery", C.warn
        end
    end
    return "UI_POS_Assignments_TypeUnknown", C.dim
end

--- Determine the status badge text and colour for a history entry.
---@param op table  Operation record
---@param C table   COLOURS table
---@return string badgeText, table badgeColour
local function getStatusBadge(op, C)
    local status = op.status or POS_Constants.STATUS_COMPLETED
    if status == POS_Constants.STATUS_COMPLETED then
        return "UI_POS_Assignments_StatusComplete", C.success
    elseif status == POS_Constants.STATUS_EXPIRED then
        return "UI_POS_Assignments_StatusExpired", C.error
    elseif status == POS_Constants.STATUS_CANCELLED then
        return "UI_POS_Assignments_StatusCancelled", C.dim
    end
    return "UI_POS_Assignments_StatusUnknown", C.dim
end

---------------------------------------------------------------
-- Tab rendering functions
---------------------------------------------------------------

--- Render the Active tab: current recon or delivery with full details.
---@param contentPanel table  ISPanel from createTabbedView
---@param startY number       Starting Y offset inside content panel
local function renderActiveTab(contentPanel, startY)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    -- Lazy-init tier colours (needs C to be available)
    if not TIER_COLOURS then
        TIER_COLOURS = {
            C.text,
            C.warn,
            { r = 1.00, g = 0.50, b = 0.20, a = 1.0 },
            C.error,
        }
    end

    local y = startY

    -- Check for active recon
    local activeRecon = getActiveRecon()
    -- Check for active delivery
    local activeDelivery = getActiveDelivery()

    if not activeRecon and not activeDelivery then
        W.createLabel(contentPanel, 8, y,
            W.safeGetText("UI_POS_Assignments_NoActive"), C.dim)
        return
    end

    -- ── Active recon ──
    if activeRecon then
        local op = activeRecon
        local tierColour = TIER_COLOURS[op.tier or 1] or C.text
        local obj = op.objectives[1]

        -- Type badge
        local badgeKey, badgeColour = getTypeBadge(op, C)
        PhobosLib.createStatusBadge(contentPanel, 8, y,
            "[" .. W.safeGetText(badgeKey) .. "]", badgeColour)
        W.createLabel(contentPanel, 120, y,
            W.safeGetText(op.nameKey or "???"), tierColour)
        y = y + 20

        -- Target location
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Ops_Target") .. ": "
            .. formatLocation(obj.targetBuildingX, obj.targetBuildingY), C.text)
        y = y + 20

        -- Show on Map button
        local mapTargetX = obj.targetBuildingX
        local mapTargetY = obj.targetBuildingY
        local btnW = contentPanel:getWidth() - 16
        local btnH = 25
        W.createButton(contentPanel, 8, y, btnW, btnH,
            W.safeGetText("UI_POS_Ops_ShowOnMap"), nil,
            function()
                PhobosLib.showOnWorldMap(0, mapTargetX, mapTargetY, 20.0)
            end)
        y = y + btnH + 4

        -- Multi-step status
        local status
        if obj.notesWritten then
            status = W.safeGetText("UI_POS_Ops_Status_ReturnToTerminal")
        elseif obj.photographed then
            status = W.safeGetText("UI_POS_Ops_Status_NotesNeeded")
        elseif obj.entered then
            status = W.safeGetText("UI_POS_Ops_Status_Photographed")
        else
            status = W.safeGetText("UI_POS_Ops_Status_Pending")
        end
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Ops_Status") .. ": " .. status, C.text)
        y = y + 20

        -- Reward + rep
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Reward") .. ": $"
            .. (op.scaledReward or "???"), C.warn)
        y = y + 20

        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Ops_Reputation") .. ": +"
            .. POS_RewardCalculator.scaleReputation(op.baseReputation or 0), C.dim)
        y = y + 20

        -- Turn In Report button (when player has matching FieldReport)
        if obj.notesWritten then
            local hasReport = false
            local player = getSpecificPlayer(0)
            if player then
                local inv = player:getInventory()
                if inv then
                    PhobosLib.safecall(function()
                        local items = inv:getItemsFromFullType(POS_Constants.ITEM_FIELD_REPORT)
                        if items then
                            for i = 0, items:size() - 1 do
                                local item = items:get(i)
                                local md = item:getModData()
                                if md and md[POS_Constants.MD_OPERATION_ID] == op.id then
                                    hasReport = true
                                end
                            end
                        end
                    end)
                end
            end

            if hasReport then
                y = y + 4
                local activeId = op.id
                local activeReward = op.scaledReward or 0
                local activeRep = op.baseReputation or 0
                W.createButton(contentPanel, 8, y, btnW, btnH,
                    W.safeGetText("UI_POS_Ops_TurnIn"), nil,
                    function()
                        local p = getSpecificPlayer(0)
                        if not p then return end

                        local opRec = POS_OperationLog and POS_OperationLog.get(activeId)
                        if not opRec then return end

                        POS_OperationService.consumeFieldReport(p, activeId)
                        POS_OperationService.completeOperation(opRec, p)

                        p:Say(W.safeGetText("UI_POS_Ops_TurnInComplete",
                            tostring(activeReward),
                            tostring(POS_RewardCalculator.scaleReputation(activeRep))))

                        POS_ScreenManager.markDirty()
                    end)
                y = y + btnH + 4
            end
        end

        -- Cancel button
        local cancelPenalty = POS_RewardCalculator.previewCancellationPenalty(op)
        local cancelLabel
        if cancelPenalty <= 0 then
            cancelLabel = W.safeGetText("UI_POS_Cancel_NoPenalty")
        else
            cancelLabel = W.safeGetText("UI_POS_Cancel_WithPenalty",
                tostring(cancelPenalty))
        end
        local cancelId = op.id
        W.createButton(contentPanel, 8, y, btnW, btnH, cancelLabel, nil,
            function()
                POS_OperationLog.cancelOperation(cancelId)
                POS_ScreenManager.markDirty()
            end)
        y = y + btnH + 4
    end

    -- ── Active delivery ──
    if activeDelivery then
        if activeRecon then
            y = y + 8
        end

        local op = activeDelivery
        local obj = op.objectives[1]

        -- Type badge
        local badgeKey, badgeColour = getTypeBadge(op, C)
        PhobosLib.createStatusBadge(contentPanel, 8, y,
            "[" .. W.safeGetText(badgeKey) .. "]", badgeColour)
        W.createLabel(contentPanel, 120, y,
            W.safeGetText("UI_POS_Delivery_Header"), C.text)
        y = y + 20

        -- Status
        local status
        if not obj.pickedUp then
            status = W.safeGetText("UI_POS_Delivery_Status_AwaitingPickup")
        else
            status = W.safeGetText("UI_POS_Delivery_Status_InTransit")
        end
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_StatusLabel") .. ": " .. status, C.text)
        y = y + 20

        -- Item
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Item") .. ": "
            .. (obj.itemType or "???"), C.text)
        y = y + 20

        -- Pickup + Dropoff
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Pickup") .. ": "
            .. formatLocation(obj.pickupX, obj.pickupY), C.text)
        y = y + 20

        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Dropoff") .. ": "
            .. formatLocation(obj.dropoffX, obj.dropoffY), C.text)
        y = y + 20

        -- Show on Map
        local mapX = obj.pickedUp and obj.dropoffX or obj.pickupX
        local mapY = obj.pickedUp and obj.dropoffY or obj.pickupY
        local btnW = contentPanel:getWidth() - 16
        local btnH = 25
        W.createButton(contentPanel, 8, y, btnW, btnH,
            W.safeGetText("UI_POS_Delivery_ShowOnMap"), nil,
            function()
                PhobosLib.showOnWorldMap(0, mapX, mapY, 20.0)
            end)
        y = y + btnH + 4

        -- Distance
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Distance") .. ": "
            .. math.floor(op.straightLineDistance or 0) .. " "
            .. W.safeGetText("UI_POS_Delivery_Tiles"), C.dim)
        y = y + 20

        if obj.pickedUp then
            local walked = POS_PathTracker.getDistance(op.id)
            W.createLabel(contentPanel, 12, y,
                W.safeGetText("UI_POS_Delivery_DistanceWalked") .. ": "
                .. math.floor(walked) .. " "
                .. W.safeGetText("UI_POS_Delivery_Tiles"), C.dim)
            y = y + 20
        end

        -- Reward
        W.createLabel(contentPanel, 12, y,
            W.safeGetText("UI_POS_Delivery_Reward") .. ": ~$"
            .. (op.estimatedReward or "???"), C.warn)
        y = y + 20

        -- Cancel button
        local cancelPenalty = POS_RewardCalculator.previewCancellationPenalty(op)
        local cancelLabel
        if cancelPenalty <= 0 then
            cancelLabel = W.safeGetText("UI_POS_Cancel_NoPenalty")
        else
            cancelLabel = W.safeGetText("UI_POS_Cancel_WithPenalty",
                tostring(cancelPenalty))
        end
        local cancelId = op.id
        W.createButton(contentPanel, 8, y, btnW, btnH, cancelLabel, nil,
            function()
                POS_OperationLog.cancelOperation(cancelId)
                POS_ScreenManager.markDirty()
            end)
        y = y + btnH + 4
    end
end

--- Render the Available tab: paginated list mixing recons and deliveries.
---@param contentPanel table  ISPanel from createTabbedView
---@param startY number       Starting Y offset
local function renderAvailableTab(contentPanel, startY)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local y = startY

    -- Merge available recons + deliveries
    local available = {}

    local recons = getAvailableRecons()
    for _, op in ipairs(recons) do
        table.insert(available, op)
    end

    -- Only include deliveries if shouldShow passes (not tactical band)
    local terminal = POS_TerminalUI and POS_TerminalUI.instance
    local band = terminal and terminal.band or ""
    if band ~= "tactical" then
        local deliveries = getAvailableDeliveries()
        for _, op in ipairs(deliveries) do
            table.insert(available, op)
        end
    end

    if #available == 0 then
        local cacheCount = POS_BuildingCache and POS_BuildingCache.getCacheCount
            and POS_BuildingCache.getCacheCount() or 0
        if cacheCount == 0 then
            W.createLabel(contentPanel, 8, y,
                W.safeGetText("UI_POS_Ops_NeedBuildings"), C.dim)
        else
            W.createLabel(contentPanel, 8, y,
                W.safeGetText("UI_POS_Assignments_NoAvailable"), C.dim)
        end
        return
    end

    PhobosLib_Pagination.create(contentPanel, {
        items = available,
        pageSize = POS_Constants.OPERATIONS_PAGE_SIZE,
        currentPage = 1,
        x = 0,
        y = y,
        width = contentPanel:getWidth(),
        colours = {
            text = C.text, dim = C.dim,
            bgDark = C.bgDark, bgHover = C.bgHover,
            border = C.border,
        },
        renderItem = function(parent, rx, ry, rw, op, _idx)
            local itemY = 0
            local badgeKey, badgeColour = getTypeBadge(op, C)
            local btnH = 25

            -- Type badge on the left
            PhobosLib.createStatusBadge(parent, rx, ry + itemY,
                "[" .. W.safeGetText(badgeKey) .. "]", badgeColour)

            -- Build label based on type
            local label
            local obj = op.objectives and op.objectives[1]
            if obj and obj.type == POS_Constants.MISSION_TYPE_RECON then
                local tierLabel = "T" .. (op.tier or "?")
                label = "[" .. tierLabel .. "] "
                    .. W.safeGetText(op.nameKey or "???")
                    .. " — $" .. (op.scaledReward or "???")
            elseif obj and obj.type == POS_Constants.OBJECTIVE_TYPE_DELIVERY then
                label = (obj.itemType or "Package")
                    .. " — ~" .. math.floor(op.estimatedRoadDistance or 0) .. " "
                    .. W.safeGetText("UI_POS_Delivery_Tiles")
                    .. " — ~$" .. (op.estimatedReward or "???")
            else
                label = W.safeGetText(op.nameKey or "???")
            end

            -- Accept button
            local opId = op.id
            W.createButton(parent, rx + 100, ry + itemY, rw - 100, btnH, label, nil,
                function()
                    POS_ScreenManager.navigateTo(POS_Constants.SCREEN_NEGOTIATE,
                        { operationId = opId })
                end)
            itemY = itemY + btnH + 4

            return itemY
        end,
        onPageChange = function(newPage)
            POS_ScreenManager.replaceCurrent("pos.bbs.assignments",
                { activeTab = "available", availPage = newPage })
        end,
    })
end

--- Render the History tab: last N completed/expired/cancelled operations.
---@param contentPanel table  ISPanel from createTabbedView
---@param startY number       Starting Y offset
local function renderHistoryTab(contentPanel, startY)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local y = startY

    local history = getHistoryEntries()

    if #history == 0 then
        W.createLabel(contentPanel, 8, y,
            W.safeGetText("UI_POS_Assignments_NoHistory"), C.dim)
        return
    end

    for _, op in ipairs(history) do
        -- Type badge
        local typeKey, typeColour = getTypeBadge(op, C)
        PhobosLib.createStatusBadge(contentPanel, 8, y,
            "[" .. W.safeGetText(typeKey) .. "]", typeColour)

        -- Name
        local name = W.safeGetText(op.nameKey or "???")
        W.createLabel(contentPanel, 120, y, name, C.text)
        y = y + 20

        -- Status badge + reward + day
        local statusKey, statusColour = getStatusBadge(op, C)
        PhobosLib.createStatusBadge(contentPanel, 20, y,
            "[" .. W.safeGetText(statusKey) .. "]", statusColour)

        local reward = op.finalReward or op.scaledReward or op.estimatedReward or 0
        local dayStr = ""
        if op.completedDay then
            dayStr = "  " .. W.safeGetText("UI_POS_MarketSignals_Day",
                tostring(op.completedDay))
        end
        W.createLabel(contentPanel, 140, y,
            "$" .. reward .. dayStr, C.dim)
        y = y + 24
    end
end

---------------------------------------------------------------
-- Screen definition — dual tab bar (category × status)
---------------------------------------------------------------

local screen = {}
screen.id        = "pos.bbs.assignments"
screen.menuPath  = {"pos.bbs"}
screen.titleKey  = "UI_POS_Assignments_Title"
screen.sortOrder = 20
screen.requires  = { connected = true }  -- No band gate per §21.5; missions filtered by active band instead

--- Current filter state (persists across refreshes within session).
local _activeCategory = "recon"
local _activeStatus   = "all"
local _selectedMissionId = nil

--- Status badges with colour mapping.
local STATUS_BADGES = {
    [POS_Constants.MISSION_STATUS_AVAILABLE] = { text = "UI_POS_Mission_Status_available", colour = "textBright" },
    [POS_Constants.MISSION_STATUS_ACTIVE]    = { text = "UI_POS_Mission_Status_active",    colour = "warning" },
    [POS_Constants.MISSION_STATUS_COMPLETED] = { text = "UI_POS_Mission_Status_completed", colour = "success" },
    [POS_Constants.MISSION_STATUS_FAILED]    = { text = "UI_POS_Mission_Status_failed",    colour = "error" },
    [POS_Constants.MISSION_STATUS_EXPIRED]   = { text = "UI_POS_Mission_Status_expired",   colour = "dim" },
}

--- Status filter tabs.
local STATUS_FILTERS = { "all", "active", "available", "done" }

--- Build category tabs from POS_Constants.MISSION_CATEGORIES.
local function _buildCategoryTabs()
    local tabs = {}
    for _, catId in ipairs(POS_Constants.MISSION_CATEGORIES) do
        tabs[#tabs + 1] = {
            id = catId,
            labelKey = "UI_POS_Mission_Category_" .. catId,
        }
    end
    return tabs
end

local function _buildStatusTabs()
    local tabs = {}
    for _, sId in ipairs(STATUS_FILTERS) do
        tabs[#tabs + 1] = {
            id = sId,
            labelKey = "UI_POS_Assignments_Filter" .. sId:sub(1,1):upper() .. sId:sub(2),
        }
    end
    return tabs
end

--- Get missions filtered by category and status.
local function getFilteredMissions(category, status)
    local result = {}
    if not POS_OperationLog or not POS_OperationLog.getAll then return result end

    local ok, allOps = PhobosLib.safecall(POS_OperationLog.getAll)
    if not ok or not allOps then return result end

    -- Get active band for mission visibility filtering
    local activeBand = nil
    if POS_ConnectionManager and POS_ConnectionManager.getActiveBand then
        local bandOk, band = PhobosLib.safecall(POS_ConnectionManager.getActiveBand)
        if bandOk then activeBand = band end
    end

    for _, op in ipairs(allOps) do
        -- Category filter
        local catMatch = (op.category == category)
        if not catMatch and op.definitionId then
            local defCat = op.definitionId and string.match(op.definitionId, "^(%a+)_") or nil
            catMatch = (defCat == category)
        end

        if catMatch then
            -- Band filter: skip missions whose requiredBands don't include active band
            local bandMatch = true
            if activeBand and op.requiredBands then
                bandMatch = false
                for _, b in ipairs(op.requiredBands) do
                    if b == activeBand then
                        bandMatch = true
                        break
                    end
                end
            end

            if bandMatch then
                -- Status filter
                local statusMatch = (status == "all")
                if not statusMatch then
                    if status == "active" then
                        statusMatch = (op.status == POS_Constants.STATUS_ACTIVE)
                    elseif status == "available" then
                        statusMatch = (op.status == POS_Constants.STATUS_AVAILABLE)
                    elseif status == "done" then
                        statusMatch = (op.status == POS_Constants.STATUS_COMPLETED
                            or op.status == POS_Constants.STATUS_FAILED
                            or op.status == POS_Constants.STATUS_EXPIRED)
                    end
                end

                if statusMatch then
                    result[#result + 1] = op
                end
            end
        end
    end

    return result
end

--- Render a single mission row.
local function renderMissionRow(ctx, op, parent, rx, ry, rw, _idx)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    local badge = STATUS_BADGES[op.status] or STATUS_BADGES[POS_Constants.MISSION_STATUS_AVAILABLE]
    local badgeText = PhobosLib.safeGetText(badge.text)
    local badgeColour = C[badge.colour] or C.text

    -- Row 1: [STATUS] Mission name
    local title = (op.briefing and op.briefing.title) or op.name or op.id
    W.createLabel(parent, rx, ry,
        "[" .. badgeText .. "] " .. title, badgeColour)
    ry = ry + ctx.lineH

    -- Row 2: Difficulty + days + reward
    local diffKey = "UI_POS_Mission_Difficulty_" .. tostring(op.difficulty or 1)
    local diffLabel = PhobosLib.safeGetText(diffKey)
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local daysLeft = (op.expiryDay or 0) - day
    local reward = op.rewardCash or op.estimatedReward or 0

    local detailStr = diffLabel
    if op.status == POS_Constants.STATUS_ACTIVE
            or op.status == POS_Constants.STATUS_AVAILABLE then
        if daysLeft > 0 then
            detailStr = detailStr .. " | " .. tostring(daysLeft) .. " days"
        elseif daysLeft == 0 then
            detailStr = detailStr .. " | DUE TODAY"
        end
    end
    detailStr = detailStr .. " | $" .. string.format("%.0f", reward)

    W.createLabel(parent, rx + 8, ry, detailStr, C.dim)
    ry = ry + ctx.lineH

    -- Row 3: Location (if available)
    local locationStr = nil
    local obj = op.objectives and op.objectives[1]
    if obj and obj.targetBuildingX and obj.targetBuildingY then
        locationStr = formatLocation(obj.targetBuildingX, obj.targetBuildingY)
    end
    if locationStr then
        W.createLabel(parent, rx + 8, ry, locationStr, C.dim)
        ry = ry + ctx.lineH
    end

    -- View Details button
    local opId = op.id
    local isSelected = (_selectedMissionId == opId)
    W.createButton(parent, rx, ry, rw, ctx.btnH,
        isSelected and "> SELECTED" or PhobosLib.safeGetText("UI_POS_Screen_ViewDetails"),
        nil,
        function()
            _selectedMissionId = opId
            POS_ScreenManager.refreshCurrentScreen()
        end)
    ry = ry + ctx.btnH + 4

    return ry - (ctx.lineH * 2 + (locationStr and ctx.lineH or 0) + ctx.btnH + 4)
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Resolve state from params
    _activeCategory = (_params and _params.category) or _activeCategory or "recon"
    _activeStatus   = (_params and _params.status)   or _activeStatus   or "all"

    W.drawHeader(ctx, "UI_POS_Assignments_Title")

    -- Player reputation + tier
    local player = getSpecificPlayer(0)
    local rep = POS_Reputation.get(player)
    local tierDef = POS_Reputation.getPlayerTierDef(player)
    local cap = POS_Sandbox and POS_Sandbox.getReputationCap
        and POS_Sandbox.getReputationCap() or 2500

    W.createLabel(ctx.panel, 0, ctx.y,
        "  " .. W.safeGetText("UI_POS_Ops_Reputation") .. ": "
        .. rep .. " / " .. cap
        .. " [" .. W.safeGetText(tierDef and tierDef.key or "UI_POS_Rep_Tier_Untrusted") .. "]",
        C.text)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Dual tab bar: category × status (PhobosLib_DualTab)
    ctx.y = PhobosLib_DualTab.create({
        panel   = ctx.panel,
        y       = ctx.y,
        tabs1   = _buildCategoryTabs(),
        tabs2   = _buildStatusTabs(),
        active1 = _activeCategory,
        active2 = _activeStatus,
        colours = C,
        btnH    = ctx.btnH,
        _W      = W,
        onTabChange = function(tab1, tab2)
            _activeCategory = tab1
            _activeStatus = tab2
            _selectedMissionId = nil
            POS_ScreenManager.replaceCurrent(screen.id,
                { category = tab1, status = tab2 })
        end,
    })

    W.createSeparator(ctx.panel, 0, ctx.y, POS_Constants.HEADER_SEPARATOR_WIDTH, "-")
    ctx.y = ctx.y + ctx.lineH

    -- ── Filtered mission list ────────────────────────────────
    local missions = getFilteredMissions(_activeCategory, _activeStatus)

    if #missions == 0 then
        local emptyKey = _activeStatus == "all"
            and "UI_POS_Assignments_NoneInCategory"
            or "UI_POS_Assignments_NoneWithStatus"
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText(emptyKey), C.dim)
        ctx.y = ctx.y + ctx.lineH

        -- §49 No Silent Gates: explain WHY and HOW to overcome
        -- Check if band filtering is hiding missions for this category
        local activeBand = nil
        if POS_ConnectionManager and POS_ConnectionManager.getActiveBand then
            local ok, band = PhobosLib.safecall(POS_ConnectionManager.getActiveBand)
            if ok then activeBand = band end
        end
        if activeBand then
            W.createLabel(ctx.panel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_Gate_NoBandMissions")
                .. " (" .. activeBand .. ")", C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        -- Hint about difficulty/signal gating
        local signalPct = 100
        if POS_ConnectionManager and POS_ConnectionManager.getSignalStrength then
            local ok, sig = PhobosLib.safecall(POS_ConnectionManager.getSignalStrength)
            if ok and type(sig) == "number" then
                signalPct = PhobosLib.clamp(math.floor(sig * 100), 0, 100)
            end
        end
        if signalPct < 100 then
            W.createLabel(ctx.panel, 8, ctx.y,
                PhobosLib.safeGetText("UI_POS_Gate_SignalLimits")
                    :gsub("%%1", tostring(signalPct)),
                C.dim)
            ctx.y = ctx.y + ctx.lineH
        end

        -- General difficulty hint
        W.createLabel(ctx.panel, 8, ctx.y,
            PhobosLib.safeGetText("UI_POS_Gate_DifficultyLocked"), C.dim)
        ctx.y = ctx.y + ctx.lineH
    else
        local currentPage = (_params and _params.missionPage) or 1
        local catCopy = _activeCategory
        local statusCopy = _activeStatus

        ctx.y = PhobosLib_Pagination.create(ctx.panel, {
            items = missions,
            pageSize = POS_Constants.MISSION_PAGE_SIZE,
            currentPage = currentPage,
            x = 0,
            y = ctx.y,
            width = ctx.panel:getWidth(),
            colours = {
                text = C.text, dim = C.dim,
                bgDark = C.bgDark, bgHover = C.bgHover,
                border = C.border,
            },
            renderItem = function(parent, rx, ry, rw, item, idx)
                local startY = ry
                ry = renderMissionRow(ctx, item, parent, rx, ry, rw, idx)
                return ry - startY
            end,
            onPageChange = function(newPage)
                POS_ScreenManager.replaceCurrent(screen.id, {
                    category = catCopy, status = statusCopy,
                    missionPage = newPage,
                })
            end,
        })
    end

    W.drawFooter(ctx)
end

function screen.destroy()
    _selectedMissionId = nil
    POS_TerminalWidgets.defaultDestroy()
end

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

--- ContextPanel: selected mission detail.
screen.getContextData = function(_params)
    local data = {}

    if not _selectedMissionId then
        -- Summary counts by category
        for _, catId in ipairs(POS_Constants.MISSION_CATEGORIES) do
            local all = getFilteredMissions(catId, "all")
            if #all > 0 then
                local active = 0
                for _, op in ipairs(all) do
                    if op.status == POS_Constants.STATUS_ACTIVE then
                        active = active + 1
                    end
                end
                local label = PhobosLib.safeGetText("UI_POS_Mission_Category_" .. catId)
                table.insert(data, { type = "kv", key = label,
                    value = tostring(#all) .. " (" .. active .. " active)" })
            end
        end
        if #data == 0 then
            table.insert(data, { type = "kv", key = "UI_POS_Screen_Hint",
                value = "Select a mission for details" })
        end
        return data
    end

    -- Find the selected mission
    local mission = nil
    if POS_OperationLog and POS_OperationLog.get then
        local ok, op = PhobosLib.safecall(POS_OperationLog.get, _selectedMissionId)
        if ok then mission = op end
    end

    if not mission then
        table.insert(data, { type = "kv", key = "Error",
            value = "Mission not found" })
        return data
    end

    -- Header
    local badge = STATUS_BADGES[mission.status]
        or STATUS_BADGES[POS_Constants.MISSION_STATUS_AVAILABLE]
    table.insert(data, { type = "header",
        text = "[" .. PhobosLib.safeGetText(badge.text) .. "]" })

    -- Mission title
    local title = (mission.briefing and mission.briefing.title) or mission.name or mission.id
    table.insert(data, { type = "kv", key = "Mission", value = title })

    -- Category
    table.insert(data, { type = "kv", key = "Category",
        value = PhobosLib.safeGetText("UI_POS_Mission_Category_" .. (mission.category or "recon")) })

    -- Difficulty
    local diffKey = "UI_POS_Mission_Difficulty_" .. tostring(mission.difficulty or 1)
    table.insert(data, { type = "kv", key = "Difficulty",
        value = PhobosLib.safeGetText(diffKey) })

    -- Deadline
    local day = getGameTime() and getGameTime():getNightsSurvived() or 0
    local daysLeft = (mission.expiryDay or 0) - day
    local dlColour = daysLeft <= 1 and "error" or (daysLeft <= 3 and "warning" or nil)
    table.insert(data, { type = "kv", key = "Deadline",
        value = tostring(daysLeft) .. " days", colour = dlColour })

    -- Reward
    local reward = mission.rewardCash or mission.estimatedReward or 0
    table.insert(data, { type = "kv", key = "Reward",
        value = "$" .. string.format("%.0f", reward) })

    -- Objectives
    if mission.objectives and #mission.objectives > 0 then
        table.insert(data, { type = "separator" })
        table.insert(data, { type = "header", text = "OBJECTIVES" })
        for _, obj in ipairs(mission.objectives) do
            local icon = obj.completed and "[x]" or "[ ]"
            table.insert(data, { type = "kv", key = icon,
                value = obj.description or obj.type or "?" })
        end
    end

    -- Briefing situation preview
    if mission.briefing and mission.briefing.situation
            and mission.briefing.situation ~= "" then
        table.insert(data, { type = "separator" })
        local sit = mission.briefing.situation
        if #sit > 80 then sit = string.sub(sit, 1, 77) .. "..." end
        table.insert(data, { type = "kv", key = "", value = sit })
    end

    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
