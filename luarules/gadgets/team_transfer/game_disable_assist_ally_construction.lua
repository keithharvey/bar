function gadget:GetInfo()
	return {
		name    = "ModOptions: Allied Construction Assist",
		desc    = "Policy implementation for allied construction assist modoptions",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
local Predicates = TeamTransfer.Predicates

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.ALLIED_CONSTRUCTION_ASSIST) then
	return
end

local assistMode = Spring.GetModOptions()[MODOPTION_KEYS.ALLIED_CONSTRUCTION_ASSIST] or "enabled"

if assistMode == "enabled" then
	return
end

----------------------------------------------------------------
----------------------------------------------------------------


TeamTransfer.RegisterPolicy(function(policy)
	if assistMode == "disabled" then
		alliedGuardCommands = policy:ForAlliedGuardCommands()
		alliedGuardCommands:Deny()
		
		alliedRepairCommands = policy:ForAlliedRepairCommands()
		alliedRepairCommands:Deny()
	elseif assistMode == "economic" then
		alliedGuardCommands = policy:ForAlliedGuardCommands()
		alliedGuardCommands:When(Predicates.Unit.isNotEconomic):Deny()
		
		alliedRepairCommands = policy:ForAlliedRepairCommands()
		alliedRepairCommands:When(Predicates.Unit.isNotEconomic):Deny()
	end
end)
