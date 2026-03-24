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
-- POS_Screen_Analysis.lua
-- Terminal screen for Intelligence Analysis (Tier II).
-- Lists raw intel items, allows selection, shows preview,
-- and starts POS_TerminalAnalysisAction.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_ScreenManager"
require "POS_TerminalWidgets"
require "POS_TerminalAnalysisService"
require "POS_TerminalAnalysisAction"
require "POS_DataRecorderService"
require "POS_SIGINTSkill"
require "POS_SIGINTService"
require "POS_API"

---------------------------------------------------------------

local screen = {}
screen.id = POS_Constants.SCREEN_ID_ANALYSIS
screen.menuPath = {"pos.bbs"}
screen.titleKey = "UI_POS_Analysis_ScreenTitle"
screen.sortOrder = 30

--- Guard: requires a Data Recorder in inventory OR existing raw intel.
screen.canOpen = function()
    local player = getSpecificPlayer(0)
    if not player then return false, POS_Constants.ERR_NO_RECORDER end
    -- Allow if player already has raw intel to process
    local rawItems = POS_TerminalAnalysisService.findRawIntelItems(player)
    if #rawItems > 0 then return true end
    -- Allow if player has a data recorder (can collect intel)
    local recorder = POS_DataRecorderService.findEquippedRecorder(player)
    if recorder then return true end
    return false, POS_Constants.ERR_NO_RECORDER
end

--- Track selected items for the current screen instance.
local selectedItems = {}

--- Toggle an item's selection state.
local function toggleItem(item, button)
    local W = POS_TerminalWidgets
    local C = W.COLOURS

    if selectedItems[item] then
        selectedItems[item] = nil
        if button then
            button:setTextureColor(ColorInfo.new(C.text.r, C.text.g, C.text.b, 1.0))
        end
    else
        -- Enforce max inputs
        local count = 0
        for _ in pairs(selectedItems) do count = count + 1 end
        if count >= POS_Constants.ANALYSIS_MAX_INPUTS then
            return  -- at cap, ignore selection
        end
        selectedItems[item] = true
        if button then
            button:setTextureColor(ColorInfo.new(C.textBright.r, C.textBright.g, C.textBright.b, 1.0))
        end
    end
end

--- Count selected items.
local function getSelectedCount()
    local count = 0
    for _ in pairs(selectedItems) do count = count + 1 end
    return count
end

--- Get selected items as an array.
local function getSelectedArray()
    local result = {}
    for item in pairs(selectedItems) do
        result[#result + 1] = item
    end
    return result
end

function screen.create(contentPanel, _params, _terminal)
    local W = POS_TerminalWidgets
    local C = W.COLOURS
    local ctx = W.initLayout(contentPanel)

    -- Reset selection on screen create
    selectedItems = {}

    -- Header
    W.drawHeader(ctx, "UI_POS_Analysis_ScreenTitle")

    local player = getSpecificPlayer(0)
    if not player then
        W.createLabel(ctx.panel, 8, ctx.y, W.safeGetText("UI_POS_Analysis_NoPlayer"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- Check cooldown
    local onCooldown, minutesLeft = POS_TerminalAnalysisService.isOnCooldown(player)
    if onCooldown then
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_Cooldown") .. " "
            .. tostring(minutesLeft) .. " min.",
            C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.drawFooter(ctx)
        return
    end

    -- SIGINT level display with XP progress bar
    local sigintLevel = POS_SIGINTSkill.getLevel(player)
    local tierKey = POS_SIGINTSkill.getTierNameKey(sigintLevel)
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Analysis_SIGINTLevel")
        .. " " .. tostring(sigintLevel)
        .. " (" .. W.safeGetText(tierKey) .. ")",
        C.text)
    ctx.y = ctx.y + ctx.lineH

    -- XP progress bar toward next level
    if sigintLevel < POS_Constants.SIGINT_MAX_LEVEL then
        local xpProgress = POS_SIGINTSkill.getLevelProgress(player)
        W.createProgressBar(ctx.panel, 8, ctx.y, ctx.pw - 16, xpProgress, C.text)
        ctx.y = ctx.y + ctx.lineH
    end

    -- Find available raw intel
    local rawItems = POS_TerminalAnalysisService.findRawIntelItems(player)

    if #rawItems == 0 then
        ctx.y = ctx.y + 4
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_NoInputs"), C.dim)
        ctx.y = ctx.y + ctx.lineH + 4

        -- Guidance text for empty state
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EmptyGuidance_Line1"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EmptyGuidance_Line2"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EmptyGuidance_Line3"), C.dim)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EmptyGuidance_Line4"), C.dim)
        ctx.y = ctx.y + ctx.lineH

        W.drawFooter(ctx)
        return
    end

    -- Instructions
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Analysis_SelectInputs"), C.text)
    ctx.y = ctx.y + ctx.lineH
    W.createLabel(ctx.panel, 8, ctx.y,
        W.safeGetText("UI_POS_Analysis_MaxInputs",
            tostring(POS_Constants.ANALYSIS_MAX_INPUTS)),
        C.dim)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Item list (selectable buttons)
    for idx, item in ipairs(rawItems) do
        local displayName = item:getDisplayName() or "???"
        local md = PhobosLib.getModData(item)
        local category = md and md.POS_Category or ""
        local label = "  [" .. idx .. "] " .. displayName
        if category ~= "" then
            label = label .. " (" .. category .. ")"
        end

        local capturedItem = item
        local btn = W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            label, nil, function()
                toggleItem(capturedItem, nil)
                -- Refresh the screen to update preview
                POS_TerminalWidgets.dynamicRefresh(screen, _params)
            end)
        ctx.y = ctx.y + ctx.btnH + 2
    end

    ctx.y = ctx.y + 4
    W.createSeparator(ctx.panel, 0, ctx.y)
    ctx.y = ctx.y + ctx.lineH + 4

    -- Estimated output preview
    local selCount = getSelectedCount()
    if selCount > 0 then
        local est = POS_TerminalAnalysisService.getEstimate(player, selCount)
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EstimatedQuality", est.confidenceRange),
            C.text)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EstimatedTime", tostring(est.estimatedTime)),
            C.text)
        ctx.y = ctx.y + ctx.lineH
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_EstimatedFragments", est.estimatedFragments),
            C.text)
        ctx.y = ctx.y + ctx.lineH + 4

        -- Process button
        W.createButton(ctx.panel, ctx.btnX, ctx.y, ctx.btnW, ctx.btnH,
            "[P] " .. W.safeGetText("UI_POS_Analysis_ProcessButton"),
            nil, function()
                local items = getSelectedArray()
                if #items > 0 then
                    ISTimedActionQueue.add(
                        POS_TerminalAnalysisAction:new(player, items)
                    )
                    -- Close terminal or navigate back
                    POS_ScreenManager.goBack()
                end
            end)
        ctx.y = ctx.y + ctx.btnH + 4
    else
        W.createLabel(ctx.panel, 8, ctx.y,
            W.safeGetText("UI_POS_Analysis_SelectPrompt"), C.dim)
        ctx.y = ctx.y + ctx.lineH + 4
    end

    -- Footer
    W.drawFooter(ctx)
end

screen.destroy = POS_TerminalWidgets.defaultDestroy

function screen.refresh(params)
    POS_TerminalWidgets.dynamicRefresh(screen, params)
end

screen.getContextData = function(_params)
    local data = {}
    table.insert(data, { type = "header", text = "UI_POS_Analysis_Title" })
    table.insert(data, { type = "separator" })

    -- Total recordings available
    if POS_DataRecorderService and POS_DataRecorderService.getRawDataCount then
        local ok, count = PhobosLib.safecall(POS_DataRecorderService.getRawDataCount)
        if ok and type(count) == "number" then
            table.insert(data, { type = "kv",
                key = PhobosLib.safeGetText("UI_POS_Analysis_TotalRecordings"),
                value = tostring(count) })
        end
    end

    -- SIGINT skill level
    local player = getSpecificPlayer(0)
    if player and POS_SIGINTSkill and POS_SIGINTSkill.getLevel then
        local lvl = POS_SIGINTSkill.getLevel(player)
        table.insert(data, { type = "kv",
            key = "SIGINT",
            value = PhobosLib.safeGetText("UI_POS_Level") .. " " .. tostring(lvl) })
    end

    return data
end

---------------------------------------------------------------

POS_API.registerScreen(screen)
