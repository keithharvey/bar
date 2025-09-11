-- Shared Unit Definitions Cache
-- Loads real unit definitions once for all tests

local Sides = require("gamedata/sides_enum")

-- Cache to hold loaded unit definitions
local unitDefsCache = nil

---Load real unit definitions from the game files
---@return table<string, table> UnitDefs table with real unit data
local function loadRealUnitDefs()
    if unitDefsCache then
        return unitDefsCache
    end

    -- Set up minimal environment for loading unit files
    local env = {
        _G = _G,
        print = print,
        error = error,
        assert = assert,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        table = table,
        string = string,
        math = math,
        tonumber = tonumber,
        tostring = tostring,
        setmetatable = setmetatable,
        getmetatable = getmetatable
    }

    local unitDefs = {}
    local loadedCount = 0

    -- Key units we want for testing
    local keyUnits = {
        { name = "armcom", path = "units/ArmCommanders/armcom.lua" },
        { name = "armlab", path = "units/ArmBuildings/LandFactories/armlab.lua" },
        { name = "armpw", path = "units/ArmBots/armpw.lua" },
        { name = "armck", path = "units/ArmBots/armck.lua" },
        { name = "armack", path = "units/ArmBots/armack.lua" },
        { name = "armsolar", path = "units/ArmBuildings/LandEconomy/armsolar.lua" },
        { name = "armmex", path = "units/ArmBuildings/LandEconomy/armmex.lua" },
        { name = "armestor", path = "units/ArmBuildings/LandEconomy/armestor.lua" },
        { name = "armmstor", path = "units/ArmBuildings/LandEconomy/armmstor.lua" },
        -- Core equivalents
        { name = "corcom", path = "units/CoreCommanders/corcom.lua" },
        { name = "corak", path = "units/CoreKbots/corak.lua" },
        { name = "corck", path = "units/CoreKbots/corck.lua" },
        { name = "corack", path = "units/CoreKbots/corack.lua" },
        { name = "corsolar", path = "units/CoreBuildings/LandEconomy/corsolar.lua" },
        { name = "cormex", path = "units/CoreBuildings/LandEconomy/cormex.lua" },
        { name = "corestor", path = "units/CoreBuildings/LandEconomy/corestor.lua" },
        { name = "cormstor", path = "units/CoreBuildings/LandEconomy/cormstor.lua" }
    }

    for _, unitInfo in ipairs(keyUnits) do
        local unitFile = unitInfo.path
        local file = io.open(unitFile, "r")
        if file then
            local content = file:read("*all")
            file:close()

            -- Try to load the unit definition using require
            local success, result = pcall(function()
                local modulePath = unitInfo.path:gsub("%.lua$", ""):gsub("/", ".")
                return require(modulePath)
            end)
            
            if success and type(result) == 'table' and result[unitInfo.name] then
                unitDefs[unitInfo.name] = result[unitInfo.name]
                -- Also add by numeric index for compatibility
                unitDefs[#unitDefs + 1] = result[unitInfo.name]
                loadedCount = loadedCount + 1
            end
        end
    end

    -- Add some fallback mock definitions for units that failed to load
    local mockUnits = {
        armpin = {
            name = "armpin",
            customParams = { isPinpointer = "1" },
            canMove = false,
            health = 500
        },
        corpin = {
            name = "corpin", 
            customParams = { isPinpointer = "1" },
            canMove = false,
            health = 500
        }
    }

    for name, unitDef in pairs(mockUnits) do
        if not unitDefs[name] then
            unitDefs[name] = unitDef
            unitDefs[#unitDefs + 1] = unitDef
        end
    end

    print(string.format("Loaded %d real unit definitions for testing", loadedCount))
    unitDefsCache = unitDefs
    return unitDefs
end

---Get unit definition by name
---@param unitName string
---@return table|nil unitDef
local function getUnitDef(unitName)
    local defs = loadRealUnitDefs()
    return defs[unitName]
end

---Get all loaded unit definitions
---@return table<string, table>
local function getAllUnitDefs()
    return loadRealUnitDefs()
end

---Get unit definition for specific faction and building type
---@param faction string
---@param buildingType string
---@return table|nil unitDef
local function getBuildingUnitDef(faction, buildingType)
    local unitName = nil
    
    if buildingType == "ENERGY_STORAGE" then
        unitName = faction == Sides.ARM and "armestor" or "corestor"
    elseif buildingType == "METAL_STORAGE" then
        unitName = faction == Sides.ARM and "armmstor" or "cormstor"
    elseif buildingType == "PINPOINTER" then
        unitName = faction == Sides.ARM and "armpin" or "corpin"
    end
    
    return unitName and getUnitDef(unitName)
end

return {
    loadRealUnitDefs = loadRealUnitDefs,
    getUnitDef = getUnitDef,
    getAllUnitDefs = getAllUnitDefs,
    getBuildingUnitDef = getBuildingUnitDef
}
