function gadget:GetInfo()
	return {
		name    = "ModOptions: Unit Sharing Mode",
		desc    = "Declares mod options for unit sharing mode (enabled, t2cons, disabled)",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local units = TeamTransfer.Units
local sharing = TeamTransfer.UnitSharing
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.UNIT_SHARING_MODE) then
	return
end

local unitSharingMode = sharing.getUnitSharingMode()
if unitSharingMode == "enabled" then
	return
end

TeamTransfer.RegisterPolicy(function(policy)
	policy.For(TeamTransfer.PolicyType.ResourceTransfer)
	policy:For(TeamTransfer.PolicyType.UnitTransfer)
	:Use(function(ctx)
		
	end)
end)

