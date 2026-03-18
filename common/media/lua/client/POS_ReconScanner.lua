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
-- POS_ReconScanner.lua
-- Periodic scan for cameras in the player's inventory while
-- they are inside a recon target room. Automatically pushes
-- a ReconPhotograph item when conditions are met.
--
-- Scan interval: every 3 seconds (~90 ticks at 30 FPS).
---------------------------------------------------------------

require "PhobosLib"
require "POS_Constants"
require "POS_TerminalWidgets"

POS_ReconScanner = POS_ReconScanner or {}

--- Scan interval in ticks (~3 seconds at 30 FPS).
local SCAN_INTERVAL = 90

--- Distance threshold for considering a player "at" the target building (tiles).
local ROOM_ENTRY_THRESHOLD = 100

--- Tick counter.
local tickCounter = 0

--- Find the active recon operation with entered=true, photographed=false.
---@return table|nil The active recon operation, or nil
local function getPhotoReadyRecon()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus("active")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "recon"
           and op.objectives[1].entered
           and not op.objectives[1].photographed then
            return op
        end
    end
    return nil
end

--- Check if the player is inside a room matching the recon target.
---@param player any IsoPlayer
---@param objective table Recon objective with targetRoomDefs
---@return boolean
local function isInTargetRoom(player, objective)
    local roomName = PhobosLib.getPlayerRoomName(player)
    if not roomName then return false end

    for _, target in ipairs(objective.targetRoomDefs or {}) do
        if roomName == target then
            -- Verify proximity to target building
            local px, py = player:getX(), player:getY()
            local bx = objective.targetBuildingX or 0
            local by = objective.targetBuildingY or 0
            if math.abs(px - bx) + math.abs(py - by) < ROOM_ENTRY_THRESHOLD then
                return true
            end
        end
    end
    return false
end

--- Check if the player has a camera (tag: base:camera) via deep scan.
---@param player any IsoPlayer
---@return boolean
local function hasCamera(player)
    local inv = player:getInventory()
    if not inv then return false end
    local ok, result = pcall(function()
        return inv:containsTagRecurse("camera")
    end)
    if ok and result then return true end
    -- Fallback: check by type
    local cameraTypes = { "Base.Camera", "Base.CameraDisposable", "Base.CameraExpensive" }
    for _, cType in ipairs(cameraTypes) do
        local ok2, found = pcall(function()
            return inv:containsTypeRecurse(cType)
        end)
        if ok2 and found then return true end
    end
    return false
end

--- Push a ReconPhotograph to the player's main inventory.
---@param player any IsoPlayer
---@param operationId string Operation ID to store in modData
local function pushPhotograph(player, operationId)
    local inv = player:getInventory()
    if not inv then return end

    local photo = inv:AddItem(POS_Constants.ITEM_RECON_PHOTOGRAPH)
    if photo then
        local md = photo:getModData()
        if md then
            md[POS_Constants.MD_OPERATION_ID] = operationId
        end
    end
end

---------------------------------------------------------------
-- Tick handler
---------------------------------------------------------------

local function onTick()
    tickCounter = tickCounter + 1
    if tickCounter < SCAN_INTERVAL then return end
    tickCounter = 0

    local player = getSpecificPlayer(0)
    if not player then return end

    local recon = getPhotoReadyRecon()
    if not recon then return end

    local obj = recon.objectives[1]

    -- Must be inside the target room
    if not isInTargetRoom(player, obj) then return end

    -- Must have a camera
    if not hasCamera(player) then return end

    -- Take photograph
    pushPhotograph(player, recon.id)
    obj.photographed = true

    -- Notify player
    player:Say(POS_TerminalWidgets.safeGetText("UI_POS_Ops_PhotoCaptured"))

    PhobosLib.debug("POS", "[ReconScanner] Photograph captured for " .. recon.id)

    -- Mark screen dirty
    if POS_ScreenManager then POS_ScreenManager.markDirty() end
end

Events.OnTick.Add(onTick)
