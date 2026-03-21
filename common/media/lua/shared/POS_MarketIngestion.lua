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
-- POS_MarketIngestion.lua
-- Market note ingestion and report compilation.
-- Converts raw market note items into database records and
-- compiles aggregated reports from stored intel.
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_WorldState"
require "POS_MarketDatabase"

POS_MarketIngestion = {}

local _TAG = "[POS:Ingestion]"

--- Ingest a raw market note item into the database.
--- On server/SP: adds the record directly via POS_MarketDatabase.
--- On MP client: sends the record to the server via sendClientCommand.
--- @param noteItem any InventoryItem with market note modData
--- @param player any|nil IsoPlayer (required for MP client routing)
--- @return boolean success
function POS_MarketIngestion.ingestNote(noteItem, player)
    if not noteItem then return false end
    local md = noteItem:getModData()
    if not md or md[POS_Constants.MD_NOTE_TYPE] ~= "market" then return false end

    local record = {
        id = "POS_INTEL_" .. tostring(getTimestampMs()),
        categoryId = md[POS_Constants.MD_NOTE_CATEGORY],
        source = md[POS_Constants.MD_NOTE_SOURCE],
        location = md[POS_Constants.MD_NOTE_LOCATION],
        price = md[POS_Constants.MD_NOTE_PRICE],
        stock = md[POS_Constants.MD_NOTE_STOCK],
        recordedDay = md[POS_Constants.MD_NOTE_RECORDED],
        confidence = md[POS_Constants.MD_NOTE_CONFIDENCE],
    }

    if POS_WorldState and POS_WorldState.isAuthority() then
        -- Server/SP: add directly
        return POS_MarketDatabase.addRecord(record)
    else
        -- MP client: send to server
        local p = player or getSpecificPlayer(0)
        if p then
            sendClientCommand(p, POS_Constants.CMD_MODULE,
                POS_Constants.CMD_SUBMIT_OBSERVATION, { record = record })
        end
        return true  -- Optimistic: assume server will accept
    end
end

--- Check if enough data exists to compile a report for a category.
--- @param categoryId string
--- @return boolean
function POS_MarketIngestion.canCompileReport(categoryId)
    local records = POS_MarketDatabase.getRecords(categoryId)
    return #records >= POS_Constants.MARKET_COMPILE_MIN_RECORDS
end

--- Compile a market report from database records and add to player inventory.
--- @param categoryId string
--- @param player any IsoPlayer
--- @return any|nil Created report item or nil
function POS_MarketIngestion.compileReport(categoryId, player)
    if not player then return nil end
    local summary = POS_MarketDatabase.getSummary(categoryId)
    local inv = player:getInventory()
    if not inv then return nil end

    local report = inv:AddItem(POS_Constants.ITEM_COMPILED_REPORT)
    if not report then return nil end

    local md = report:getModData()
    md[POS_Constants.MD_REPORT_TYPE] = "market"
    md[POS_Constants.MD_NOTE_CATEGORY] = categoryId
    md[POS_Constants.MD_REPORT_REGION] = summary.region or PhobosLib.safeGetText("UI_POS_Market_Unknown")
    md[POS_Constants.MD_REPORT_LOW] = summary.low
    md[POS_Constants.MD_REPORT_HIGH] = summary.high
    md[POS_Constants.MD_REPORT_AVG] = summary.avg
    md[POS_Constants.MD_REPORT_SOURCES] = summary.sourceCount

    local currentDay = 0
    if getGameTime then currentDay = getGameTime():getNightsSurvived() end
    md[POS_Constants.MD_REPORT_COMPILED] = currentDay

    PhobosLib.debug("POS", _TAG,
        "Compiled market report for category: " .. categoryId)
    return report
end

--- Count raw market notes in player inventory.
--- @param player any IsoPlayer
--- @return number count
function POS_MarketIngestion.countNotes(player)
    if not player then return 0 end
    local inv = player:getInventory()
    if not inv then return 0 end
    local items = inv:getItemsFromFullType(POS_Constants.ITEM_RAW_MARKET_NOTE)
    if not items then return 0 end
    return items:size()
end

--- Get all raw market notes from player inventory.
--- @param player any IsoPlayer
--- @return table Array of InventoryItem
function POS_MarketIngestion.getNotes(player)
    if not player then return {} end
    local inv = player:getInventory()
    if not inv then return {} end
    local items = inv:getItemsFromFullType(POS_Constants.ITEM_RAW_MARKET_NOTE)
    if not items then return {} end
    local result = {}
    for i = 0, items:size() - 1 do
        table.insert(result, items:get(i))
    end
    return result
end
