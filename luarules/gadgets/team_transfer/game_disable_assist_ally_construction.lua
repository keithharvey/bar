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


local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")
local Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION) then
	return
end

local allowAssist = not Spring.GetModOptions()[KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION]
if allowAssist then
	return
end

API.RegisterPolicy(function(policy)
	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:When(Predicates.Command.targetAllied)
	:When(Predicates.Command.targetHasAssist)
	:Use(function(ctx)
		return { deny = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:Use(function(ctx)
		return { allow = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isRepair)
	:When(Predicates.Command.targetAllied)
	:When(Predicates.Command.targetIsIncomplete)
	:Use(function(ctx)
		return { deny = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isRepair)
	:Use(function(ctx)
		return { allow = true }
	end)
end)
