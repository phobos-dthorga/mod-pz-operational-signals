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
-- POS_RoomCategoryMap.lua
-- Pattern-based mapping of PZ room type strings to market
-- commodity category IDs.
--
-- Used by POS_MarketReconAction to determine what kind of intel
-- a given building location should generate.
--
-- Pattern list maintained in sync with:
--   scripts/snapshot-room-categories.py
-- Updated manually when PZ adds new room types.
---------------------------------------------------------------

require "POS_Constants"

POS_RoomCategoryMap = {}

---------------------------------------------------------------
-- Pattern table: checked in order, first match wins.
-- Keep in sync with CATEGORY_PATTERNS in
-- scripts/snapshot-room-categories.py
---------------------------------------------------------------
local PATTERNS = {
    -- Fuel
    { pattern = "gas",         category = "fuel" },
    { pattern = "fuel",        category = "fuel" },
    { pattern = "garage",      category = "fuel" },
    { pattern = "mechanic",    category = "fuel" },
    { pattern = "fossoil",     category = "fuel" },

    -- Medicine
    { pattern = "pharmacy",    category = "medicine" },
    { pattern = "medical",     category = "medicine" },
    { pattern = "clinic",      category = "medicine" },
    { pattern = "hospital",    category = "medicine" },
    { pattern = "doctor",      category = "medicine" },
    { pattern = "dentist",     category = "medicine" },
    { pattern = "vet",         category = "medicine" },
    { pattern = "morgue",      category = "medicine" },
    { pattern = "coroner",     category = "medicine" },

    -- Food
    { pattern = "grocery",     category = "food" },
    { pattern = "kitchen",     category = "food" },
    { pattern = "restaurant",  category = "food" },
    { pattern = "bakery",      category = "food" },
    { pattern = "butcher",     category = "food" },
    { pattern = "cafe",        category = "food" },
    { pattern = "cafeteria",   category = "food" },
    { pattern = "diner",       category = "food" },
    { pattern = "bar",         category = "food" },
    { pattern = "pizz",        category = "food" },
    { pattern = "spiffo",      category = "food" },
    { pattern = "jayschicken", category = "food" },
    { pattern = "gigamart",    category = "food" },
    { pattern = "burger",      category = "food" },
    { pattern = "donut",       category = "food" },
    { pattern = "icecream",    category = "food" },
    { pattern = "sushi",       category = "food" },
    { pattern = "catfish",     category = "food" },
    { pattern = "chinese",     category = "food" },
    { pattern = "italian",     category = "food" },
    { pattern = "mexican",     category = "food" },
    { pattern = "western",     category = "food" },
    { pattern = "deepfry",     category = "food" },
    { pattern = "fishchip",    category = "food" },
    { pattern = "hotdog",      category = "food" },
    { pattern = "candy",       category = "food" },
    { pattern = "brewery",     category = "food" },
    { pattern = "whiskey",     category = "food" },
    { pattern = "liquor",      category = "food" },
    { pattern = "dining",      category = "food" },
    { pattern = "produce",     category = "food" },
    { pattern = "jerky",       category = "food" },
    { pattern = "crepe",       category = "food" },
    { pattern = "juice",       category = "food" },
    { pattern = "egg",         category = "food" },
    { pattern = "corner",      category = "food" },
    { pattern = "convenience", category = "food" },

    -- Ammunition
    { pattern = "gun",         category = "ammunition" },
    { pattern = "armory",      category = "ammunition" },
    { pattern = "army",        category = "ammunition" },
    { pattern = "military",    category = "ammunition" },
    { pattern = "police",      category = "ammunition" },
    { pattern = "hunting",     category = "ammunition" },
    { pattern = "swat",        category = "ammunition" },
    { pattern = "prison",      category = "ammunition" },
    { pattern = "ammo",        category = "ammunition" },

    -- Tools
    { pattern = "warehouse",   category = "tools" },
    { pattern = "tool",        category = "tools" },
    { pattern = "hardware",    category = "tools" },
    { pattern = "construct",   category = "tools" },
    { pattern = "plumb",       category = "tools" },
    { pattern = "carpent",     category = "tools" },
    { pattern = "welding",     category = "tools" },
    { pattern = "factory",     category = "tools" },
    { pattern = "shipping",    category = "tools" },
    { pattern = "logging",     category = "tools" },
    { pattern = "railroad",    category = "tools" },
    { pattern = "metalfab",    category = "tools" },
    { pattern = "metalshop",   category = "tools" },

    -- Radio / Electronics
    { pattern = "electronic",  category = "radio" },
    { pattern = "office",      category = "radio" },
    { pattern = "computer",    category = "radio" },
    { pattern = "radio",       category = "radio" },
    { pattern = "cyber",       category = "radio" },

    -- Chemicals (PCP cross-mod)
    { pattern = "lab",         category = "chemicals" },
    { pattern = "chem",        category = "chemicals" },
    { pattern = "drug",        category = "chemicals" },
}

---------------------------------------------------------------
-- Public API
---------------------------------------------------------------

--- Get the commodity category for a room type string.
--- @param roomType string PZ room type name (e.g. "gasstation", "pharmacy")
--- @return string|nil Category ID or nil if no match
function POS_RoomCategoryMap.getCategory(roomType)
    if not roomType then return nil end
    local lower = string.lower(roomType)
    for _, entry in ipairs(PATTERNS) do
        if lower:find(entry.pattern) then
            return entry.category
        end
    end
    return nil
end

--- Get all patterns for a given category (for debugging).
--- @param categoryId string
--- @return string[] Array of pattern strings
function POS_RoomCategoryMap.getPatternsForCategory(categoryId)
    local result = {}
    for _, entry in ipairs(PATTERNS) do
        if entry.category == categoryId then
            table.insert(result, entry.pattern)
        end
    end
    return result
end

--- Get all known category IDs.
--- @return string[] Deduplicated sorted list of category IDs
function POS_RoomCategoryMap.getAllCategories()
    local seen = {}
    local result = {}
    for _, entry in ipairs(PATTERNS) do
        if not seen[entry.category] then
            seen[entry.category] = true
            table.insert(result, entry.category)
        end
    end
    table.sort(result)
    return result
end
