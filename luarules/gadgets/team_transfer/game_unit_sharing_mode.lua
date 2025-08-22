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

