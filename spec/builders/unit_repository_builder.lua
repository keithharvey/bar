local Definitions = require("luaui/Include/blueprint_substitution/definitions")
local Sides = require("gamedata/sides_enum")

---@class UnitRepositoryBuilder
---@field teamUnits table
---@field nextAutoUnitId number

---@class UnitRepositoryMock
---@field unitAdded fun(unitID: number, unitDefID: string|number, teamID: number)
---@field unitRemoved fun(unitID: number, teamID: number)
---@field getTeamUnits fun(teamID: number): table<number, string|number>
---@field hasBuiltUnits fun(teamID: number, requiredUnitDefIDs: string[]): boolean

---@class UnitRepositoryBuilder
local UnitRepositoryBuilder = {}
UnitRepositoryBuilder.__index = UnitRepositoryBuilder

local function resolveTeamId(team)
    if type(team) == "number" then return team end
    if type(team) == "table" then
        if type(team.Build) == "function" then
            local built = team:Build()
            return built and built.id or team.id
        end
        return team.id
    end
    return team
end

-- Default data for UnitRepositoryBuilder instances (mirrors PipelineBuilder pattern)
local defaultData = {
    teamUnits = {},
    nextAutoUnitId = 100000,
}

---@return UnitRepositoryBuilder
function UnitRepositoryBuilder.new()
    local instance = setmetatable({}, UnitRepositoryBuilder)
    -- Copy default data (keep structure stable across instances)
    for k, v in pairs(defaultData) do
        if type(v) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            instance[k] = t
        else
            instance[k] = v
        end
    end
    return instance
end

-- Fluent methods that mutate the instance
-- Concrete colon methods for IntelliSense and navigation

---@param self UnitRepositoryBuilder
---@param unitID number
---@param unitDefID string|number
---@param teamID number
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnit(unitID, unitDefID, teamID)
    local tID = resolveTeamId(teamID)
    self.teamUnits[tID] = self.teamUnits[tID] or {}
    self.teamUnits[tID][unitID] = unitDefID
    return self
end

---@param self UnitRepositoryBuilder
---@param teamID number
---@param units table<number, string|number>
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnits(teamID, units)
    local tID = resolveTeamId(teamID)
    self.teamUnits[tID] = self.teamUnits[tID] or {}
    for unitID, unitDefID in pairs(units) do
        self.teamUnits[tID][unitID] = unitDefID
    end
    return self
end

---@param self UnitRepositoryBuilder
---@param category string
---@param teamID number|nil
---@param side string?
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnitFromCategory(category, teamID, side)
    -- Default to ARM side if not specified
    local actualSide = side or Sides.ARM
    local unitName = Definitions.getUnitByCategory(category, actualSide)
    if not unitName then
        error("WithUnitFromCategory: getUnitByCategory returned nil for category '" .. tostring(category) .. "' and side '" .. tostring(actualSide) .. "'")
    end

    local tID = teamID or 0
    local unitID = self.nextAutoUnitId or 100000
    self.nextAutoUnitId = unitID + 1
    return UnitRepositoryBuilder.WithUnit(self, unitID, unitName, tID)
end

---Build creates the UnitRepository mock
---@param self UnitRepositoryBuilder
---@return UnitRepositoryMock
function UnitRepositoryBuilder:Build()
    local instance = self
    return setmetatable({
        unitAdded = function(self, unitID, unitDefID, teamID)
            instance.teamUnits[teamID] = instance.teamUnits[teamID] or {}
            instance.teamUnits[teamID][unitID] = unitDefID
        end,

        unitRemoved = function(self, unitID, teamID)
            if instance.teamUnits[teamID] then
                instance.teamUnits[teamID][unitID] = nil
            end
        end,

        getTeamUnits = function(self, teamID)
            instance.teamUnits[teamID] = instance.teamUnits[teamID] or {}
            return instance.teamUnits[teamID]
        end,

        hasBuiltUnits = function(self, teamID, requiredUnitDefIDs)
            instance.teamUnits[teamID] = instance.teamUnits[teamID] or {}

            local required = {}
            for _, unitDefID in ipairs(requiredUnitDefIDs) do
                required[unitDefID] = true
            end

            local found = {}
            for _, unitDefID in pairs(instance.teamUnits[teamID]) do
                if required[unitDefID] then
                    found[unitDefID] = true
                end
            end

            for unitDefID, _ in pairs(required) do
                if not found[unitDefID] then
                    return false
                end
            end
            return true
        end,
    }, { __index = {
        unitAdded = function(self, unitID, unitDefID, teamID) end,
        unitRemoved = function(self, unitID, teamID) end,
        getTeamUnits = function(self, teamID) return instance.teamUnits[teamID] or {} end,
        hasBuiltUnits = function(self, teamID, requiredUnitDefIDs) return false end,
    }})
end

return UnitRepositoryBuilder
