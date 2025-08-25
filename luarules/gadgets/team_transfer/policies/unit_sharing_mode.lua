local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: Unit Sharing Mode',
		desc    = 'Enforces unit sharing restrictions based on mod options',
		author  = 'Devin',
		date    = 'Aug 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local sharing = GG.TeamTransfer.UnitSharing
local MODOPTION_KEYS = GG.TeamTransfer.MODOPTION_KEYS
local modoption = MODOPTION_KEYS.UNIT_SHARING_MODE

local enabled, unitSharingMode = GG.TeamTransfer.IsSharingOption(modoption)
if not enabled or unitSharingMode == "enabled" then
	return
end

GG.TeamTransfer.RegisterPolicy(function(policy)
	if unitSharingMode == "disabled" then
		policy.ForAlliedUnitTransfers.Deny()
	elseif unitSharingMode == "t2cons" then
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			if not sharing.isT2ConstructorDef(UnitDefs[ctx.unitDefID]) then
				return { deny = true }
			end
			return { allow = true }
		end)
	elseif unitSharingMode == "combat" then
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			if sharing.isEconomicUnitDef(UnitDefs[ctx.unitDefID]) then
				return { deny = true }
			end
			return { allow = true }
		end)
	elseif unitSharingMode == "combat_t2cons" then
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			local unitDef = UnitDefs[ctx.unitDefID]
			if sharing.isEconomicUnitDef(unitDef) and not sharing.isT2ConstructorDef(unitDef) then
				return { deny = true }
			end
			return { allow = true }
		end)
	end
end)
