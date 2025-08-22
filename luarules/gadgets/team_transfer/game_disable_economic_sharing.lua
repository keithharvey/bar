function gadget:GetInfo()
	return {
		name    = "ModOptions: Transfer To Enemies",
		desc    = "Policy implementation for transfer to enemies modoption",
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

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.TRANSFER_TO_ENEMIES) then
	return
end

local transferToEnemies = Spring.GetModOptions()[MODOPTION_KEYS.TRANSFER_TO_ENEMIES]
if transferToEnemies then
	return
end

----------------------------------------------------------------
----------------------------------------------------------------
TeamTransfer.RegisterPolicy(function(policy)
	policy:For(TeamTransfer.PolicyType.ResourceTransfer)
	:When(Predicates.Team.isEnemy)
	:Use(function(ctx)
		return { deny = true }
	end)
	
	policy:For(TeamTransfer.PolicyType.UnitTransfer)
	:When(Predicates.Team.isEnemy)
	:Use(function(ctx)
		return { deny = true }
	end)
end)
