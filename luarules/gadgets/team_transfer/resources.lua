local M = {}

local cumulativeMetalSent = {}

function M.NormalizeResourceName(resourceType)
	if resourceType == 'm' then return 'metal' end
	if resourceType == 'e' then return 'energy' end
	return resourceType
end

function M.GetCumulativeMetalSent(teamID)
	return cumulativeMetalSent[teamID] or 0
end

function M.AddCumulativeMetalSent(teamID, amount)
	local cur = cumulativeMetalSent[teamID] or 0
	local newVal = cur + (amount or 0)
	cumulativeMetalSent[teamID] = newVal
	return newVal
end

function M.ComputeMaxShare(receiverTeamId, resourceName)
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur
	if maxShare < 0 then maxShare = 0 end
	return maxShare, rCur
end

return M
