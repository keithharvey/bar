function gadget:GetInfo()
	return {
		name    = "ModOptions: Disable Assist Ally Construction",
		desc    = "Declares mod options for disabling allied assist/repair on certain targets",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
local Predicates = TeamTransfer.Predicates

if not (TeamTransfer.IsSharingOption(MODOPTION_KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION) or 
        TeamTransfer.IsSharingOption(MODOPTION_KEYS.DISABLE_ECONOMIC_SHARING)) then
	return
end

local allowAssist = not Spring.GetModOptions()[MODOPTION_KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION]
if allowAssist then
	return
end

TeamTransfer.RegisterPolicy(function(policy)
	policy:For(TeamTransfer.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:When(Predicates.Command.targetAllied)
	:When(Predicates.Command.targetHasAssist)
	:Use(function(ctx)
		return { deny = true }
	end)
	)

	policy:For(TeamTransfer.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:Use(function(ctx)
		return { allow = true }
	end)

	policy:For(TeamTransfer.PolicyType.Command)
	:When(Predicates.Command.isRepair)
	:When(Predicates.Command.targetAllied)
	:When(Predicates.Command.targetIsIncomplete)
	:Use(function(ctx)
		return { deny = true }
	end)

	policy:For(TeamTransfer.PolicyType.Command)
	:When(Predicates.Command.isRepair)
	:Use(function(ctx)
		return { allow = true }
	end)
end)
