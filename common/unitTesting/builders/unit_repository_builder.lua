-- Unit Repository Builder
-- Builds UnitRepository with mocked unit tracking for testing

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
local Definitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")

---@return UnitRepositoryBuilder
function UnitRepositoryBuilder.new()
    return setmetatable({
        teamUnits = {},
        nextAutoUnitId = 100000,
    }, UnitRepositoryBuilder)
end

-- Fluent methods that mutate the instance
-- Concrete colon methods for IntelliSense and navigation

---@param self UnitRepositoryBuilder
---@param unitID number
---@param unitDefID string|number
---@param teamID number
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnit(unitID, unitDefID, teamID)
    self.teamUnits[teamID] = self.teamUnits[teamID] or {}
    self.teamUnits[teamID][unitID] = unitDefID
    return self
end

---@param self UnitRepositoryBuilder
---@param teamID number
---@param units table<number, string|number>
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnits(teamID, units)
    self.teamUnits[teamID] = self.teamUnits[teamID] or {}
    for unitID, unitDefID in pairs(units) do
        self.teamUnits[teamID][unitID] = unitDefID
    end
    return self
end

---@param self UnitRepositoryBuilder
---@param category string
---@param side any
---@param teamID number|nil
---@return UnitRepositoryBuilder
function UnitRepositoryBuilder:WithUnitFromCategory(category, side, teamID)
    local unitName = Definitions.getUnitByCategory(category, side)
    if not unitName then
        error("WithUnitFromCategory: getUnitByCategory returned nil for category '" .. tostring(category) .. "' and side '" .. tostring(side) .. "'")
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
    return {
        unitAdded = function(unitID, unitDefID, teamID)
            instance.teamUnits[teamID] = instance.teamUnits[teamID] or {}
            instance.teamUnits[teamID][unitID] = unitDefID
        end,

        unitRemoved = function(unitID, teamID)
            if instance.teamUnits[teamID] then
                instance.teamUnits[teamID][unitID] = nil
            end
        end,

        getTeamUnits = function(teamID)
            instance.teamUnits[teamID] = instance.teamUnits[teamID] or {}
            return instance.teamUnits[teamID]
        end,

        hasBuiltUnits = function(teamID, requiredUnitDefIDs)
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
    }
end

return UnitRepositoryBuilder
