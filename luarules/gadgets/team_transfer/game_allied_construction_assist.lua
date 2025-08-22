function gadget:GetInfo()
	return {
		name    = "ModOptions: Allied Construction Assist",
		desc    = "Policy implementation for allied construction assist modoption",
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

local economicUnits = {}
if assistMode == "economic" then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.canAssist or unitDef.isFactory or unitDef.isBuilder then
			economicUnits[unitDefID] = true
		end
		if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
			economicUnits[unitDefID] = true
		end
		if unitDef.extractsMetal > 0 then
			economicUnits[unitDefID] = true
		end
	end
end

TeamTransfer.RegisterPolicy(function(policy)
	if assistMode == "disabled" then
		policy:For(TeamTransfer.PolicyType.Command)
		:When(Predicates.Command.isGuard)
		:When(Predicates.Command.targetAllied)
		:When(Predicates.Command.targetHasAssist)
		:Use(function(ctx)
			return { deny = true }
		end)
		
		policy:For(TeamTransfer.PolicyType.Command)
		:When(Predicates.Command.isRepair)
		:When(Predicates.Command.targetAllied)
		:When(Predicates.Command.targetIsIncomplete)
		:Use(function(ctx)
			return { deny = true }
		end)
	elseif assistMode == "economic" then
		policy:For(TeamTransfer.PolicyType.Command)
		:When(Predicates.Command.isGuard)
		:When(Predicates.Command.targetAllied)
		:When(Predicates.Command.targetHasAssist)
		:When(function(ctx)
			return not economicUnits[ctx.targetUnitDef and ctx.targetUnitDef.id]
		end)
		:Use(function(ctx)
			return { deny = true }
		end)
		
		policy:For(TeamTransfer.PolicyType.Command)
		:When(Predicates.Command.isRepair)
		:When(Predicates.Command.targetAllied)
		:When(Predicates.Command.targetIsIncomplete)
		:When(function(ctx)
			return not economicUnits[ctx.targetUnitDef and ctx.targetUnitDef.id]
		end)
		:Use(function(ctx)
			return { deny = true }
		end)
	end
end)
