local M = {}

local cumulativeMetalSent = {}

function M.GetCumulativeMetalSent(teamID)
	return cumulativeMetalSent[teamID] or 0
end

function M.AddCumulativeMetalSent(teamID, amount)
	local cur = cumulativeMetalSent[teamID] or 0
	local newVal = cur + (amount or 0)
	cumulativeMetalSent[teamID] = newVal
	return newVal
end

-- Unit State Tracking for efficient building category checks
local teamUnits = {} -- teamUnits[teamID][unitID] = unitDefID

---Initialize team unit tracking
---@param teamID number
local function initTeamUnits(teamID)
	if not teamUnits[teamID] then
		teamUnits[teamID] = {}
	end
end

---Add a unit to team tracking
---@param unitID number
---@param unitDefID string|number
---@param teamID number
function M.unitAdded(unitID, unitDefID, teamID)
	initTeamUnits(teamID)
	teamUnits[teamID][unitID] = unitDefID
end

---Remove a unit from team tracking
---@param unitID number
---@param teamID number
function M.unitRemoved(unitID, teamID)
	initTeamUnits(teamID)
	teamUnits[teamID][unitID] = nil
end

---Get all units for a team
---@param teamID number
---@return table<number, string|number> unitID -> unitDefID mapping
function M.getTeamUnits(teamID)
	initTeamUnits(teamID)
	return teamUnits[teamID]
end

---Check if team has built specific unit types
---@param teamID number
---@param requiredUnitDefIDs string[]
---@return boolean hasAll
function M.hasBuiltUnits(teamID, requiredUnitDefIDs)
	initTeamUnits(teamID)
	
	local required = {}
	for _, unitDefID in ipairs(requiredUnitDefIDs) do
		required[unitDefID] = true
	end
	
	local found = {}
	for _, unitDefID in pairs(teamUnits[teamID]) do
		if required[unitDefID] then
			found[unitDefID] = true
		end
	end
	
	-- Check if all required units are found
	for unitDefID, _ in pairs(required) do
		if not found[unitDefID] then
			return false
		end
	end
	return true
end

return M
