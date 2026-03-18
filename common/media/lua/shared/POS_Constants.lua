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
-- POS_Constants.lua
-- Single source of truth for cross-file string and ID constants.
--
-- All server commands, screen IDs, item types, and shared modData
-- keys that appear in more than one file are defined here.
---------------------------------------------------------------

POS_Constants = {}

---------------------------------------------------------------
-- Server / client command protocol
---------------------------------------------------------------

POS_Constants.CMD_MODULE = "POS"

-- Server → client
POS_Constants.CMD_NEW_OPERATION       = "NewOperation"
POS_Constants.CMD_NEW_INVESTMENT      = "NewInvestment"
POS_Constants.CMD_INVESTMENT_RESOLVED = "InvestmentResolved"
POS_Constants.CMD_INVESTMENT_ACK      = "InvestmentAcknowledged"

-- Client → server
POS_Constants.CMD_PLAYER_INVESTED     = "PlayerInvested"
POS_Constants.CMD_REQUEST_OPERATION   = "RequestOperation"
POS_Constants.CMD_REQUEST_PAYOUTS     = "RequestPendingPayouts"

---------------------------------------------------------------
-- Screen IDs (POS_ScreenManager navigation targets)
---------------------------------------------------------------

POS_Constants.SCREEN_MAIN_MENU   = "pos.main"
POS_Constants.SCREEN_BBS_HUB     = "pos.bbs"
POS_Constants.SCREEN_BBS_LIST    = "pos.bbs.investments"
POS_Constants.SCREEN_BBS_POST    = "pos.bbs.investments.detail"
POS_Constants.SCREEN_OPERATIONS  = "pos.bbs.operations"
POS_Constants.SCREEN_DELIVERIES  = "pos.bbs.deliveries"
POS_Constants.SCREEN_NEGOTIATE   = "pos.negotiate"
POS_Constants.SCREEN_STOCKMARKET = "pos.stockmarket"

---------------------------------------------------------------
-- Item full types
---------------------------------------------------------------

POS_Constants.ITEM_PORTABLE_COMPUTER = "PhobosOperationalSignals.PortableComputer"
POS_Constants.ITEM_FIELD_REPORT      = "PhobosOperationalSignals.FieldReport"
POS_Constants.ITEM_RECON_PHOTOGRAPH  = "PhobosOperationalSignals.ReconPhotograph"
POS_Constants.ITEM_POSNET_PACKAGE    = "PhobosOperationalSignals.POSnetPackage"

---------------------------------------------------------------
-- ModData keys (used across multiple files)
---------------------------------------------------------------

POS_Constants.MD_OPERATION_ID = "POS_OperationId"

---------------------------------------------------------------
-- AZAS integration
---------------------------------------------------------------

POS_Constants.AZAS_OPS_KEY          = "POSnet_Operations"
POS_Constants.AZAS_TAC_KEY          = "POSnet_Tactical"
POS_Constants.AZAS_DEFAULT_OPS_FREQ = 130000
POS_Constants.AZAS_DEFAULT_TAC_FREQ = 155000

---------------------------------------------------------------
-- POSnet API version for extension compatibility
---------------------------------------------------------------

POS_Constants.API_VERSION = 1

---------------------------------------------------------------
-- Error translation keys
---------------------------------------------------------------

POS_Constants.ERR_UNKNOWN_SCREEN  = "UI_POS_Error_UnknownScreen"
POS_Constants.ERR_NO_SIGNAL       = "UI_POS_Error_NoSignal"
POS_Constants.ERR_WRONG_BAND      = "UI_POS_Error_WrongBand"
POS_Constants.ERR_NOT_CONNECTED   = "UI_POS_Error_NotConnected"
POS_Constants.ERR_EXTENSION_FAIL  = "UI_POS_Error_ExtensionFailed"
POS_Constants.ERR_SCREEN_BLOCKED  = "UI_POS_Error_ScreenBlocked"
POS_Constants.ERR_NO_POWER        = "UI_POS_Error_NoPower"
POS_Constants.MSG_POWER_LOST      = "UI_POS_PowerLost"

---------------------------------------------------------------
-- Power drain modData keys
---------------------------------------------------------------

POS_Constants.MD_POWER_DRAIN_RATE    = "POS_PowerDrainRate"
POS_Constants.MD_POWER_DRAIN_SESSION = "POS_PowerDrainSession"
POS_Constants.POWER_CHECK_INTERVAL   = 60
