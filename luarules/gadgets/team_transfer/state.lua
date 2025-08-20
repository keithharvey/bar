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

return M
