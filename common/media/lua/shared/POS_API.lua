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
-- POS_API.lua
-- Public API for registering screens and categories.
--
-- Third-party extensions use POS_API.registerScreen() or the
-- safe wrapper POS_API.tryRegisterScreen() to add new terminal
-- screens. All input is validated before reaching POS_Registry.
---------------------------------------------------------------

require "POS_Constants"
require "POS_Registry"

POS_API = POS_API or {}

local _TAG = "[POS:API]"

--- Current API version. Extensions declare compatibility with this.
POS_API.VERSION = POS_Constants.API_VERSION

local REQUIRED_FIELDS = { "id", "menuPath", "titleKey", "create" }

--- Register a screen definition with the POSnet terminal system.
--- Required fields: id (string, dot-namespaced), menuPath (table), titleKey (string), create (function).
--- Optional: destroy, refresh, onEnter, onExit, sortOrder, shouldShow, canOpen, requires, isRoot.
function POS_API.registerScreen(def)
    -- Validate type
    assert(type(def) == "table", "registerScreen: definition must be a table")

    -- Validate required fields (warn instead of crash during ResetLua)
    for _, field in ipairs(REQUIRED_FIELDS) do
        if def[field] == nil then
            PhobosLib.debug("POS", "[POS:API]",
                "registerScreen: '" .. field .. "' is nil — skipping (likely ResetLua race)")
            return
        end
    end
    assert(type(def.id) == "string", "registerScreen: 'id' must be a string")
    assert(type(def.menuPath) == "table", "registerScreen: 'menuPath' must be a table")
    assert(type(def.titleKey) == "string", "registerScreen: 'titleKey' must be a string")
    assert(type(def.create) == "function", "registerScreen: 'create' must be a function")

    -- Reject duplicate IDs
    if POS_Registry.getScreen(def.id) then
        error("registerScreen: duplicate id '" .. def.id .. "'")
    end

    -- Apply defaults for optional fields
    def.sortOrder = def.sortOrder or 1000
    def.isRoot = def.isRoot or false

    -- Store in registry
    POS_Registry.addScreen(def)

    -- Also register with legacy ScreenManager for backward compatibility
    -- during migration (screens still need create/destroy/refresh callable)
    if POS_ScreenManager and POS_ScreenManager.registerScreen then
        local legacyScreen = {
            id = def.id,
            create = def.create,
            destroy = def.destroy or POS_TerminalWidgets.defaultDestroy,
            refresh = def.refresh or function() end,
            onEnter = def.onEnter,
            onExit = def.onExit,
        }
        -- Only register if not already registered
        if not POS_ScreenManager.screens or not POS_ScreenManager.screens[def.id] then
            POS_ScreenManager.registerScreen(legacyScreen)
        end
    end

    PhobosLib.debug("POS", _TAG, "Registered screen: " .. def.id)
end

--- Safe registration wrapper for third-party extensions.
--- Returns ok (boolean), err (string or nil).
function POS_API.tryRegisterScreen(def)
    local ok, err = PhobosLib.safecall(POS_API.registerScreen, def)
    if not ok then
        PhobosLib.debug("POS", _TAG, "Screen registration failed: " .. tostring(err))
    end
    return ok, err
end

--- Register a menu category.
--- Required fields: id (string), titleKey (string).
--- Optional: parent (string), sortOrder (number).
function POS_API.registerCategory(def)
    assert(type(def) == "table", "registerCategory: definition must be a table")
    assert(type(def.id) == "string", "registerCategory: 'id' is required")
    assert(type(def.titleKey) == "string", "registerCategory: 'titleKey' is required")

    if POS_Registry.getCategory(def.id) then
        error("registerCategory: duplicate category id '" .. def.id .. "'")
    end

    def.sortOrder = def.sortOrder or 1000
    POS_Registry.addCategory(def)

    PhobosLib.debug("POS", _TAG, "Registered category: " .. def.id)
end

--- Check if a screen's `requires` declaration is met.
--- Returns true/nil on success, false/reason on failure.
function POS_API.checkRequires(requires, ctx)
    if not requires then return true, nil end
    ctx = ctx or {}

    if requires.connected and not ctx.connected then
        return false, POS_Constants.ERR_NOT_CONNECTED
    end

    if requires.minSignal then
        local signal = ctx.signal or 0
        if signal < requires.minSignal then
            return false, POS_Constants.ERR_NO_SIGNAL
        end
    end

    if requires.bands then
        local band = ctx.band or ""
        local found = false
        for _, b in ipairs(requires.bands) do
            if b == band then found = true; break end
        end
        if not found then
            return false, POS_Constants.ERR_WRONG_BAND
        end
    end

    return true, nil
end
