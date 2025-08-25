---@load-file luaui/types/team_transfer.lua

local M = {}

---Normalize resource name from short form to full form
---@param resourceType "m"|"e"|"metal"|"energy" Resource type identifier
---@return "metal"|"energy" normalizedName Full resource name
function M.NormalizeResourceName(resourceType)
	if resourceType == 'm' then return 'metal' end
	if resourceType == 'e' then return 'energy' end
	return resourceType
end

---Calculate maximum shareable amount for a team and resource
---@param receiverTeamId number Team ID of the receiver
---@param resourceName "metal"|"energy" Resource type
---@return number maxShare Maximum amount that can be shared to this team
---@return number currentAmount Current resource amount the team has
function M.ComputeMaxShare(receiverTeamId, resourceName)
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur
	if maxShare < 0 then maxShare = 0 end
	return maxShare, rCur
end

return M
