-- Unit Definition Names
-- Static unit definition IDs - no dependencies, basically useful for unit testing

---@class UnitNames
local UnitNames = {
    -- ARM Storage Buildings
    ARM_METAL_STORAGE = "armmstor",
    ARM_ENERGY_STORAGE = "armestor",
    
    -- CORE Storage Buildings  
    CORE_METAL_STORAGE = "cormstor",
    CORE_ENERGY_STORAGE = "corestor",
    
    -- LEGION Storage Buildings
    LEGION_METAL_STORAGE = "legmstor",
    LEGION_ENERGY_STORAGE = "legestor",
    
    -- ARM Basic Units
    ARM_COMMANDER = "armcom",
    ARM_CONSTRUCTION_BOT = "armck",
    ARM_ADVANCED_CONSTRUCTION_BOT = "armack",
    ARM_PEEWEE = "armpw",
    ARM_SOLAR_COLLECTOR = "armsolar",
    ARM_METAL_EXTRACTOR = "armmex",
    ARM_LIGHT_LASER_TOWER = "armllt",
    ARM_VEHICLE_PLANT = "armvp",
    ARM_BOT_LAB = "armlab",
    
    -- CORE Basic Units
    CORE_COMMANDER = "corcom",
    CORE_CONSTRUCTION_KBOT = "corck",
    CORE_ADVANCED_CONSTRUCTION_KBOT = "corack", 
    CORE_A_K = "corak",
    CORE_SOLAR_COLLECTOR = "corsolar",
    CORE_METAL_EXTRACTOR = "cormex",
    CORE_LIGHT_LASER_TOWER = "corllt",
    CORE_VEHICLE_PLANT = "corvp",
    CORE_KBOT_LAB = "corlab",
    
    -- LEGION Basic Units
    LEGION_COMMANDER = "legcom",
    LEGION_CONSTRUCTION_BOT = "legck",
    LEGION_ADVANCED_CONSTRUCTION_BOT = "legack",
    LEGION_GLADIATOR = "leggladiator",
    LEGION_SOLAR_COLLECTOR = "legsolar",
    LEGION_METAL_EXTRACTOR = "legmex"
}

return UnitNames