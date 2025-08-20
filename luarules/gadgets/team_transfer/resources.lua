local M = {}

local Tax = VFS.Include('common/luaUtilities/resource_share_tax.lua')

function M.ComputeMaxShare(receiverTeamId, resourceName)
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur
	if maxShare < 0 then maxShare = 0 end
	return maxShare, rCur
end

function M.ApplyTaxedTransfer(senderTeamId, receiverTeamId, resourceName, amount, sharingTax, metalTaxThreshold, currentCumulative)
	local breakdown = Tax.computeTransfer(resourceName, amount, sharingTax, metalTaxThreshold, currentCumulative)
	local actualSentAmount = math.min(breakdown.actualSent, amount)
	local actualReceivedAmount = math.min(breakdown.actualReceived, amount)

	Spring.SetTeamResource(receiverTeamId, resourceName, select(1, Spring.GetTeamResources(receiverTeamId, resourceName)) + actualReceivedAmount)
	local sCur = select(1, Spring.GetTeamResources(senderTeamId, resourceName))
	Spring.SetTeamResource(senderTeamId, resourceName, sCur - actualSentAmount)

	return actualSentAmount, actualReceivedAmount, breakdown
end

return M
