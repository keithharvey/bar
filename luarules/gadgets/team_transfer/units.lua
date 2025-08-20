local M = {}

local function isT2Constructor(ud)
	if not ud then return false end
	if not ud.customParams then return false end
	local tl = tonumber(ud.customParams.techlevel or 1) or 1
	if tl >= 2 and (ud.isBuilder or ud.canAssist or (ud.buildOptions and #ud.buildOptions > 0)) then
		return true
	end
	return false
end

local function getUnitSharingMode()
	local mo = Spring.GetModOptions and Spring.GetModOptions() or nil
	return (mo and mo.unit_sharing_mode) or "enabled"
end

function M.AllowUnitTransferByMode(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end

	local mode = getUnitSharingMode()
	if mode == "enabled" then
		return true
	elseif mode == "disabled" then
		return false
	elseif mode == "t2cons" then
		local ud = UnitDefs[unitDefID]
		return isT2Constructor(ud)
	end

	return false
end

return M
