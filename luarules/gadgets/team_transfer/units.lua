---@load-file luaui/types/team_transfer.lua

local M = {}

---Check if a unit definition represents a T2 constructor
---@param ud table? Unit definition from UnitDefs
---@return boolean isT2Con True if the unit is a T2 constructor
local function isT2Constructor(ud)
	if not ud then return false end
	if not ud.customParams then return false end
	local tl = tonumber(ud.customParams.techlevel or 1) or 1
	if tl >= 2 and (ud.isBuilder or ud.canAssist or (ud.buildOptions and #ud.buildOptions > 0)) then
		return true
	end
	return false
end

---Check if a unit transfer should be allowed based on sharing mode
---@param unitID number Unit ID being transferred
---@param unitDefID number Unit definition ID
---@param fromTeamID number Source team ID
---@param toTeamID number Destination team ID
---@param capture boolean Whether this is a capture (always allowed)
---@param mode string Sharing mode ("enabled", "disabled", "t2cons", etc.)
---@return boolean allowed True if the transfer should be allowed
function M.AllowUnitTransferByMode(unitID, unitDefID, fromTeamID, toTeamID, capture, mode)
	if capture then
		return true
	end

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
