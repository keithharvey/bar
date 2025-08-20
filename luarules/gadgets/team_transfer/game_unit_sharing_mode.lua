local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local units = VFS.Include("luarules/gadgets/team_transfer/units.lua")
local sharing = VFS.Include("common/unit_sharing.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("common/sharing_modoption_keys.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.UNIT_SHARING_MODE) then
	return
end

local unitSharingMode = sharing.getUnitSharingMode()
if unitSharingMode == "enabled" then
	return
end

local transferOverrideFlags = {
	"transfer_override_market",
}

local function CheckTakeCondition(fromTeamID, toTeamID)
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
			if active and not spectator and teamID == fromTeamID then
				return false
			end
		end
		return true
	end
	return false
end

API.RegisterAllowUnitTransfer(function(unitID, unitDefID, fromTeamID, toTeamID, capture)
	for _, flagName in ipairs(transferOverrideFlags) do
		local flagValue = Spring.GetUnitRulesParam(unitID, flagName)
		if flagValue and flagValue == 1 then
			Spring.SetUnitRulesParam(unitID, flagName, nil)
			return true
		end
	end

	if CheckTakeCondition(fromTeamID, toTeamID) then
		return true
	end

	return units.AllowUnitTransferByMode(unitID, unitDefID, fromTeamID, toTeamID, capture)
end)

