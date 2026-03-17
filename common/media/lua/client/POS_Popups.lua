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
-- POS_Popups.lua
-- Welcome guide popup for POSnet.
---------------------------------------------------------------

require "PhobosLib"

local function safeGetText(key)
    local ok, result = pcall(getText, key)
    if ok and result then return result end
    return key
end

PhobosLib.registerGuidePopup("POS", {
    title = safeGetText("UI_POS_GuideTitle"),
    width = 620,
    height = 500,
    buildContent = function()
        local lines = {}
        table.insert(lines, " <RGB:0.3,1.0,0.3> " .. safeGetText("UI_POS_GuideTitle"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.9,0.9,0.9> " .. safeGetText("UI_POS_GuideIntro"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. safeGetText("UI_POS_GuideStep1"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. safeGetText("UI_POS_GuideStep2"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. safeGetText("UI_POS_GuideStep3"))
        table.insert(lines, " <RGB:0.6,1.0,0.6> " .. safeGetText("UI_POS_GuideStep4"))
        table.insert(lines, " ")
        table.insert(lines, " <RGB:0.7,0.7,0.7> " .. safeGetText("UI_POS_GuideNote"))
        return table.concat(lines, " <LINE> ")
    end,
    backgroundColor = { r = 0.05, g = 0.08, b = 0.05, a = 0.95 },
    borderColor = { r = 0.15, g = 0.40, b = 0.15, a = 1.0 },
})
