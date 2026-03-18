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
-- POS_DeliveryContextMenu.lua
-- Right-click context menu options on mailbox objects for
-- collecting and delivering POSnet packages.
--
-- Detects mailbox sprites, checks active delivery operations,
-- and provides "Collect POSnet Package" / "Deliver POSnet Package"
-- options when the player is at the correct mailbox.
---------------------------------------------------------------

require "PhobosLib"
require "POS_MailboxScanner"
require "POS_PathTracker"
require "POS_TerminalWidgets"

--- Coordinate tolerance for matching player position to mailbox (tiles).
local COORD_TOLERANCE = 3

--- Scan radius for passive periodic mailbox discovery (tiles).
local PASSIVE_SCAN_RADIUS = 30

--- Check if coordinates match within tolerance.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return boolean
local function coordsMatch(x1, y1, x2, y2)
    return math.abs(x1 - x2) <= COORD_TOLERANCE
       and math.abs(y1 - y2) <= COORD_TOLERANCE
end

--- Find the active delivery operation (if any) from POS_OperationLog.
---@return table|nil The active delivery operation, or nil
local function getActiveDelivery()
    if not POS_OperationLog then return nil end
    local ops = POS_OperationLog.getByStatus("active")
    for _, op in ipairs(ops) do
        if op.objectives and op.objectives[1]
           and op.objectives[1].type == "delivery" then
            return op
        end
    end
    return nil
end

--- Handle "Collect POSnet Package" action.
---@param worldObjects table
---@param player any
---@param operation table
local function onCollectPackage(worldObjects, player, operation)
    local obj = operation.objectives[1]
    if not obj or obj.pickedUp then return end

    -- Spawn the item into player inventory
    local inv = player:getInventory()
    if not inv then return end

    inv:AddItem(obj.itemType)
    obj.pickedUp = true

    -- Start path tracking from pickup
    POS_PathTracker.startTracking(operation.id)

    -- Notify player
    player:Say(POS_TerminalWidgets.safeGetText("UI_POS_Delivery_Status_InTransit"))

    PhobosLib.debug("POS", "[Delivery] Collected package for " .. operation.id)

    -- Mark screen dirty for terminal updates
    if POS_ScreenManager then POS_ScreenManager.markDirty() end
end

--- Handle "Deliver POSnet Package" action.
---@param worldObjects table
---@param player any
---@param operation table
local function onDeliverPackage(worldObjects, player, operation)
    local obj = operation.objectives[1]
    if not obj or not obj.pickedUp then return end

    local inv = player:getInventory()
    if not inv then return end

    -- Verify player still has the item
    local item = inv:getFirstTypeRecurse(obj.itemType)
    if not item then
        player:Say(POS_TerminalWidgets.safeGetText("UI_POS_Delivery_NoItem"))
        return
    end

    -- Remove the item
    inv:Remove(item)

    -- Calculate final reward from actual distance driven
    local actualDistance = POS_PathTracker.stopTracking(operation.id)
    local finalReward = POS_DeliveryGenerator.calculateReward(actualDistance)

    -- Store final stats on the operation
    operation.actualDistance = actualDistance
    operation.finalReward = finalReward

    -- Pay the player
    PhobosLib.addMoney(player, finalReward)

    -- Mark operation complete
    obj.completed = true
    if POS_OperationLog then
        POS_OperationLog.completeOperation(operation.id)
    end

    -- Notify player
    player:Say(POS_TerminalWidgets.safeGetText("UI_POS_Delivery_Completed", tostring(finalReward)))

    PhobosLib.debug("POS", "[Delivery] Delivered " .. operation.id
        .. " — actual distance: " .. math.floor(actualDistance)
        .. " tiles, reward: $" .. finalReward)

    if POS_ScreenManager then POS_ScreenManager.markDirty() end
end

---------------------------------------------------------------
-- Context menu hook
---------------------------------------------------------------

--- Add POSnet delivery options when right-clicking mailbox objects.
---@param playerIndex number
---@param context any ISContextMenu
---@param worldObjects table
local function onFillWorldObjectContextMenu(playerIndex, context, worldObjects)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end

    -- Check if any clicked object is a mailbox
    local mailboxX, mailboxY
    for _, obj in ipairs(worldObjects) do
        -- worldObjects can contain tables of objects per square
        local objects = obj
        if type(obj) ~= "table" then
            objects = { obj }
        end
        for _, worldObj in ipairs(objects) do
            if worldObj and worldObj.getSprite then
                local spriteName = nil
                pcall(function()
                    local sprite = worldObj:getSprite()
                    if sprite and sprite.getName then
                        spriteName = sprite:getName()
                    end
                end)
                if spriteName and POS_MailboxScanner.isMailboxSprite(spriteName) then
                    pcall(function()
                        mailboxX = worldObj:getX()
                        mailboxY = worldObj:getY()
                    end)
                    break
                end
            end
        end
        if mailboxX then break end
    end

    if not mailboxX then return end  -- Not a mailbox

    -- Auto-discover: cache this mailbox position for future deliveries
    POS_MailboxScanner.addToCache(mailboxX, mailboxY)

    -- Check for active delivery
    local delivery = getActiveDelivery()
    if not delivery then return end

    local obj = delivery.objectives[1]
    if not obj then return end

    -- "Collect POSnet Package" — at pickup mailbox, not yet picked up
    if not obj.pickedUp
       and coordsMatch(mailboxX, mailboxY, obj.pickupX, obj.pickupY) then
        context:addOption(
            POS_TerminalWidgets.safeGetText("UI_POS_Delivery_CollectPackage"),
            worldObjects, onCollectPackage, player, delivery)
    end

    -- "Deliver POSnet Package" — at dropoff mailbox, already picked up
    if obj.pickedUp and not obj.completed
       and coordsMatch(mailboxX, mailboxY, obj.dropoffX, obj.dropoffY) then
        -- Verify player has the item
        local inv = player:getInventory()
        if inv and inv:getFirstTypeRecurse(obj.itemType) then
            context:addOption(
                POS_TerminalWidgets.safeGetText("UI_POS_Delivery_DeliverPackage"),
                worldObjects, onDeliverPackage, player, delivery)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

---------------------------------------------------------------
-- Passive mailbox discovery — scan nearby area periodically
---------------------------------------------------------------

--- Scan a small radius around the player for mailboxes and cache them.
--- Runs every in-game minute to passively build the discovery cache.
local function onPassiveMailboxScan()
    if not POS_Sandbox or not POS_Sandbox.isDeliveryEnabled() then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())

    -- Scan a small 30-tile radius (cheap, loaded chunks only)
    local found = PhobosLib.findWorldObjectsBySprite(
        px, py, PASSIVE_SCAN_RADIUS, POS_MailboxScanner.MAILBOX_SPRITES)

    for _, entry in ipairs(found) do
        POS_MailboxScanner.addToCache(entry.x, entry.y)
    end
end

Events.EveryOneMinute.Add(onPassiveMailboxScan)

--- Also passively scan for buildings with recon-relevant rooms.
local function onPassiveBuildingScan()
    if POS_BuildingCache and POS_BuildingCache.passiveScan then
        POS_BuildingCache.passiveScan()
    end
end

Events.EveryOneMinute.Add(onPassiveBuildingScan)

--- One-time retroactive scan on first mod load.
--- Catches buildings and mailboxes the player has already explored.
local function onInitialScan()
    if POS_BuildingCache and POS_BuildingCache.initialScan then
        POS_BuildingCache.initialScan()
    end
    if POS_MailboxScanner and POS_MailboxScanner.initialScan then
        POS_MailboxScanner.initialScan()
    end
end

Events.OnGameStart.Add(onInitialScan)
