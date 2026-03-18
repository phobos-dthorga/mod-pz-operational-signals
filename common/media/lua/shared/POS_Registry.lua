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
-- POS_Registry.lua
-- Central storage for screen definitions and menu categories.
--
-- Screens and categories are registered via POS_API and stored
-- here. The MenuBuilder queries this registry to build menus.
---------------------------------------------------------------

POS_Registry = POS_Registry or {}

local screens = {}
local categories = {}

--- Store a validated screen definition.
function POS_Registry.addScreen(def)
    screens[def.id] = def
end

--- Store a validated category definition.
function POS_Registry.addCategory(def)
    categories[def.id] = def
end

--- Look up a screen by ID.
function POS_Registry.getScreen(id)
    return screens[id]
end

--- Look up a category by ID.
function POS_Registry.getCategory(id)
    return categories[id]
end

--- Get all screens whose menuPath matches the given path.
--- Filters by shouldShow. Sorted by sortOrder.
function POS_Registry.getMenuEntries(path, player, ctx)
    local results = {}
    for _, def in pairs(screens) do
        if POS_Registry.pathMatches(def.menuPath, path) then
            local visible = (not def.shouldShow) or def.shouldShow(player, ctx or {})
            if visible then
                table.insert(results, def)
            end
        end
    end
    table.sort(results, function(a, b)
        return (a.sortOrder or 1000) < (b.sortOrder or 1000)
    end)
    return results
end

--- Check if a screen's menuPath matches a target path.
--- Exact table equality check — same length and same elements.
function POS_Registry.pathMatches(menuPath, targetPath)
    if not menuPath or not targetPath then return false end
    if #menuPath ~= #targetPath then return false end
    for i = 1, #menuPath do
        if menuPath[i] ~= targetPath[i] then return false end
    end
    return true
end

--- Get all registered screen IDs (for debugging).
function POS_Registry.getAllScreenIds()
    local ids = {}
    for id, _ in pairs(screens) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end
