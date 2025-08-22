function gadget:GetInfo()
	return {
		name    = "ModOptions: Unit Sharing Mode",
		desc    = "Policy implementation for unit sharing mode dropdown options",
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

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.UNIT_SHARING_MODE) then
	return
end

local unitSharingMode = Spring.GetModOptions()[MODOPTION_KEYS.UNIT_SHARING_MODE] or "enabled"
if unitSharingMode == "enabled" then
	return
end

----------------------------------------------------------------
----------------------------------------------------------------
local Units = TeamTransfer.Units

----------------------------------------------------------------
----------------------------------------------------------------
TeamTransfer.RegisterPolicy(function(policy)
	if unitSharingMode == "disabled" then
		policy:For(TeamTransfer.PolicyType.UnitTransfer)
		:Use(function(ctx)
			return { deny = true }
		end)
	elseif unitSharingMode == "t2cons" then
		policy:For(TeamTransfer.PolicyType.UnitTransfer)
		:When(Predicates.Unit.isNotT2Constructor)
		:Use(function(ctx)
			return { deny = true }
		end)
	elseif unitSharingMode == "combat" then
		policy:For(TeamTransfer.PolicyType.UnitTransfer)
		:When(Predicates.Unit.isNotCombat)
		:Use(function(ctx)
			return { deny = true }
		end)
	elseif unitSharingMode == "economy" then
		policy:For(TeamTransfer.PolicyType.UnitTransfer)
		:When(Predicates.Unit.isNotEconomic)
		:Use(function(ctx)
			return { deny = true }
		end)
	end
end)

