local M = {}

local sharing = VFS.Include("common/unit_sharing.lua")

function M.AllowUnitTransferByMode(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	return sharing.isUnitShareAllowedByMode(unitDefID)
end

return M
