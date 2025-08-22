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

local units = GG.TeamTransfer.Units
local sharing = GG.TeamTransfer.UnitSharing
local MODOPTION_KEYS = GG.TeamTransfer.MODOPTION_KEYS

local enabled = GG.TeamTransfer.IsSharingOption(MODOPTION_KEYS.UNIT_SHARING_MODE)
if not enabled then
	return
end

local unitSharingMode = sharing.getUnitSharingMode()
if unitSharingMode == "enabled" then
	return
end

GG.TeamTransfer.RegisterPolicy(function(policy)
	if unitSharingMode == "disabled" then
		policy.UnitTransfers.Allied:Deny()
	elseif unitSharingMode == "t2cons" then
		policy.UnitTransfers.Allied:When(function(ctx)
			return not sharing.isT2ConstructorDef(UnitDefs[ctx.unitDefID])
		end):Deny()
	elseif unitSharingMode == "combat" then
		policy.UnitTransfers.Allied:When(function(ctx)
			return sharing.isEconomicUnitDef(UnitDefs[ctx.unitDefID])
		end):Deny()
	elseif unitSharingMode == "combat_t2cons" then
		policy.UnitTransfers.Allied:When(function(ctx)
			local unitDef = UnitDefs[ctx.unitDefID]
			return sharing.isEconomicUnitDef(unitDef) and not sharing.isT2ConstructorDef(unitDef)
		end):Deny()
	end
end)
