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

local function alliedGuardCommands(additionalPredicates)
	return function(policy)
		local builder = policy:For(TeamTransfer.PolicyType.Command)
			:When(Predicates.Command.isGuard)
			:When(Predicates.Command.targetAllied)
			:When(Predicates.Command.targetHasAssist)
		
		if additionalPredicates then
			for _, predicate in ipairs(additionalPredicates) do
				builder = builder:When(predicate)
			end
		end
		
		return builder:Use(function(ctx)
			return { deny = true }
		end)
	end
end

local function alliedRepairCommands(additionalPredicates)
	return function(policy)
		local builder = policy:For(TeamTransfer.PolicyType.Command)
			:When(Predicates.Command.isRepair)
			:When(Predicates.Command.targetAllied)
			:When(Predicates.Command.targetIsIncomplete)
		
		if additionalPredicates then
			for _, predicate in ipairs(additionalPredicates) do
				builder = builder:When(predicate)
			end
		end
		
		return builder:Use(function(ctx)
			return { deny = true }
		end)
	end
end

TeamTransfer.RegisterPolicy(function(policy)
	if assistMode == "disabled" then
		alliedGuardCommands()(policy)
		alliedRepairCommands()(policy)
	elseif assistMode == "economic" then
		alliedGuardCommands({Predicates.Unit.isNotEconomic})(policy)
		alliedRepairCommands({Predicates.Unit.isNotEconomic})(policy)
	end
end)
