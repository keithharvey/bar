local M = {}

function M.ComputeMaxShare(receiverTeamId, resourceName)
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur
	if maxShare < 0 then maxShare = 0 end
	return maxShare, rCur
end

return M
