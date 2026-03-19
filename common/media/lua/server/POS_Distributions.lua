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
-- POS_Distributions.lua
-- Loot distribution tables for POSnet items.
--
-- Items distributed here:
--   Devices:  PortableComputer, ReconCamcorder, FieldSurveyLogger,
--             DataCalculator, DataRecorder
--   Tapes:    BlankVHSCTape, DamagedVHSTape, MagneticTapeScrap
--   Media:    Microcassette, SpentMicrocassette, BlankFloppyDisk, CorruptFloppyDisk
--
-- Items NOT distributed (crafted/mission-generated only):
--   RawMarketNote, CompiledMarketReport, FieldReport,
--   ReconPhotograph, POSnetPackage
---------------------------------------------------------------
require "Items/ItemPicker"
require "Items/Distributions"
require "Items/ProceduralDistributions"
require "POS_Constants"

-----------------------------------------------------
-- Nil-guarded distribution helper.
-- Prevents crash if a distribution key is renamed,
-- removed, or absent in the current B42 build.
-----------------------------------------------------
local function dist(listName, itemType, chance)
    local entry = ProceduralDistributions.list[listName]
    if entry and entry.items then
        table.insert(entry.items, itemType)
        table.insert(entry.items, chance)
    end
end

-- Shorthand references
local PC       = POS_Constants.ITEM_PORTABLE_COMPUTER
local CAMCORD  = POS_Constants.ITEM_RECON_CAMCORDER
local LOGGER   = POS_Constants.ITEM_FIELD_SURVEY_LOGGER
local CALC     = POS_Constants.ITEM_DATA_CALCULATOR
local BLANK    = POS_Constants.ITEM_BLANK_VHS_TAPE
local DAMAGED  = POS_Constants.ITEM_DAMAGED_VHS_TAPE
local SCRAP    = POS_Constants.ITEM_MAGNETIC_TAPE_SCRAP
local RECORDER = POS_Constants.ITEM_DATA_RECORDER
local MICRO    = POS_Constants.ITEM_MICROCASSETTE
local MICRO_S  = POS_Constants.ITEM_SPENT_MICROCASSETTE
local FLOPPY   = POS_Constants.ITEM_BLANK_FLOPPY_DISK
local FLOPPY_C = POS_Constants.ITEM_CORRUPT_FLOPPY_DISK

-----------------------------------------------------
-- PORTABLE COMPUTER
-- Very rare find — rewards exploration of offices,
-- military bases, electronics stores, and police stations.
-----------------------------------------------------

-- Electronics stores — most likely find location
dist("ElectronicStoreComputers",  PC, 0.8)
dist("ElectronicStoreMisc",       PC, 0.3)

-- Military — bunkers and storage facilities
dist("ArmyStorageElectronics",    PC, 0.6)
dist("ArmyBunkerStorage",         PC, 0.3)

-- Offices — desk drawers and shelves
dist("OfficeDesk",                PC, 0.3)
dist("OfficeDrawers",             PC, 0.2)

-- Police stations — desks
dist("PoliceDesk",                PC, 0.2)

-- Schools — lockers
dist("SchoolLockers",             PC, 0.1)

-----------------------------------------------------
-- RECON CAMCORDER
-- Rare electronics find — news crews, military, police
-----------------------------------------------------

dist("ElectronicStoreComputers",  CAMCORD, 0.05)
dist("ArmyStorageElectronics",    CAMCORD, 0.08)
dist("PoliceStorageElectronics",  CAMCORD, 0.04)
dist("OfficeDesk",                CAMCORD, 0.02)

-----------------------------------------------------
-- FIELD SURVEY LOGGER
-- Scientific/industrial survey tool
-----------------------------------------------------

dist("OfficeDesk",                LOGGER, 0.04)
dist("WarehouseTools",            LOGGER, 0.03)
dist("PoliceDesk",                LOGGER, 0.04)
dist("FactoryTools",              LOGGER, 0.03)
dist("MechanicShelf",             LOGGER, 0.02)

-----------------------------------------------------
-- DATA CALCULATOR
-- Common office/school electronics item
-----------------------------------------------------

dist("OfficeDesk",                CALC, 0.10)
dist("OfficeDrawers",             CALC, 0.08)
dist("SchoolLockers",             CALC, 0.06)
dist("SchoolDesk",                CALC, 0.06)
dist("ElectronicStoreMisc",       CALC, 0.10)
dist("DeskDrawers",               CALC, 0.05)
dist("LibraryBooks",              CALC, 0.03)

-----------------------------------------------------
-- BLANK VHS-C TAPES
-- Uncommon — new-old-stock in stores, offices, homes
-----------------------------------------------------

dist("ElectronicStoreMisc",       BLANK, 0.15)
dist("LivingRoomShelf",           BLANK, 0.06)
dist("LivingRoomSideTable",       BLANK, 0.05)
dist("BedroomDresser",            BLANK, 0.05)
dist("OfficeDrawers",             BLANK, 0.06)
dist("StoreShelf",                BLANK, 0.05)
dist("SchoolLockers",             BLANK, 0.03)

-----------------------------------------------------
-- DAMAGED VHS TAPES
-- Common — it's the 90s, tapes are everywhere
-----------------------------------------------------

dist("LivingRoomShelf",           DAMAGED, 0.25)
dist("LivingRoomSideTable",       DAMAGED, 0.20)
dist("BedroomDresser",            DAMAGED, 0.18)
dist("BedroomSideTable",          DAMAGED, 0.15)
dist("ElectronicStoreMisc",       DAMAGED, 0.20)
dist("SchoolLockers",             DAMAGED, 0.12)
dist("GarageShelves",             DAMAGED, 0.15)
dist("ClosetShelves",             DAMAGED, 0.12)
dist("BarCounterMisc",            DAMAGED, 0.10)
dist("StoreShelf",                DAMAGED, 0.10)

-----------------------------------------------------
-- MAGNETIC TAPE SCRAP
-- Uncommon — electronics workshops, garages, factories
-----------------------------------------------------

dist("ElectronicStoreMisc",       SCRAP, 0.10)
dist("GarageShelves",             SCRAP, 0.08)
dist("GarageTools",               SCRAP, 0.06)
dist("WarehouseShelves",          SCRAP, 0.07)
dist("FactoryTools",              SCRAP, 0.05)

-----------------------------------------------------
-- VEHICLE DISTRIBUTIONS
-----------------------------------------------------

dist("GloveBox",                  DAMAGED, 0.05)
dist("GloveBox",                  CALC,    0.02)
dist("GloveBoxPolice",            LOGGER,  0.03)
dist("GloveBoxPolice",            CAMCORD, 0.02)

-----------------------------------------------------
-- DATA-RECORDER
-- Rare military/research field equipment
-----------------------------------------------------

dist("ArmyStorageElectronics",    RECORDER, 0.04)
dist("ArmyBunkerStorage",         RECORDER, 0.03)
dist("PoliceStorageElectronics",  RECORDER, 0.02)
dist("OfficeDesk",                RECORDER, 0.01)
dist("WarehouseTools",            RECORDER, 0.01)
dist("SchoolLockers",             RECORDER, 0.01)
dist("ElectronicStoreComputers",  RECORDER, 0.02)

-----------------------------------------------------
-- MICROCASSETTE
-- Uncommon — offices, police, journalism, medical
-----------------------------------------------------

dist("OfficeDesk",                MICRO, 0.08)
dist("OfficeDrawers",             MICRO, 0.06)
dist("PoliceDesk",                MICRO, 0.06)
dist("DeskDrawers",               MICRO, 0.04)
dist("BedroomDresser",            MICRO, 0.03)
dist("ElectronicStoreMisc",       MICRO, 0.05)

-----------------------------------------------------
-- SPENT MICROCASSETTE
-- Uncommon — discarded in offices, homes
-----------------------------------------------------

dist("OfficeDrawers",             MICRO_S, 0.05)
dist("LivingRoomSideTable",       MICRO_S, 0.04)
dist("BedroomSideTable",          MICRO_S, 0.03)
dist("GarageShelves",             MICRO_S, 0.03)
dist("ClosetShelves",             MICRO_S, 0.02)

-----------------------------------------------------
-- BLANK FLOPPY DISK
-- Very rare — university labs, government, military
-----------------------------------------------------

dist("OfficeDesk",                FLOPPY, 0.02)
dist("ArmyStorageElectronics",    FLOPPY, 0.03)
dist("ElectronicStoreComputers",  FLOPPY, 0.02)
dist("SchoolLockers",             FLOPPY, 0.01)
dist("LibraryBooks",              FLOPPY, 0.01)

-----------------------------------------------------
-- CORRUPT FLOPPY DISK
-- Rare — old discarded floppies in tech locations
-----------------------------------------------------

dist("OfficeDrawers",             FLOPPY_C, 0.03)
dist("GarageShelves",             FLOPPY_C, 0.02)
dist("ElectronicStoreMisc",       FLOPPY_C, 0.02)
dist("SchoolLockers",             FLOPPY_C, 0.01)
