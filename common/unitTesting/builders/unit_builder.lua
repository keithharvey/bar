-- Unit Builder
-- Builds units for testing using real unit definition IDs

local Units = require("gamedata/unit_names")
local SharedUnitDefs = require("common/unitTesting/shared_unit_defs")

---@class UnitDef
---@field name string
---@field customParams table
---@field canMove boolean
---@field health number

---@class UnitBuilder
---@field From fun(unitDefID: string): UnitDef
---@field GetAllRealUnitDefs fun(): table<string, UnitDef>
local UnitBuilder = {}

-- Auto-load and cache unit definitions on first use
local unitDefsLoaded = false

---Ensure unit definitions are loaded and cached
local function ensureUnitDefsLoaded()
    if not unitDefsLoaded then
        _G.UnitDefs = SharedUnitDefs.getAllUnitDefs()
        unitDefsLoaded = true
    end
end

---From retrieves a real unit definition by its ID
---@param unitDefID string Real unit definition ID from gamedata/unit_names.lua
---@return UnitDef unitDef Real unit definition
function UnitBuilder.From(unitDefID)
    ensureUnitDefsLoaded()

    local unitDef = SharedUnitDefs.getUnitDef(unitDefID)
    if not unitDef then
        error("Unit definition not found: " .. tostring(unitDefID))
    end
    return unitDef
end

---GetAllRealUnitDefs loads and returns all real unit definitions
---@return table<string, UnitDef> All unit definitions for testing
function UnitBuilder.GetAllRealUnitDefs()
    ensureUnitDefsLoaded()
    return _G.UnitDefs
end

return UnitBuilder
