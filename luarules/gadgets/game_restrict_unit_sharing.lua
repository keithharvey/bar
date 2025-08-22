function gadget:GetInfo()
	return {
		name = "Restrict Unit Sharing",
		desc = "Provides granular control over what units can be shared between allies",
		author = "Hobo Joe", 
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.DISABLE_UNIT_SHARING) then
	return
end

local restrictedUnitTypes = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams then
		local unitGroup = unitDef.customParams.unitgroup
		if unitGroup == "energy" or unitGroup == "metal" or unitGroup == "builder" then
			restrictedUnitTypes[unitDefID] = true
		end
	end
	
	if unitDef.isFactory or unitDef.canAssist or unitDef.isBuilder then
		restrictedUnitTypes[unitDefID] = true
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if capture then
		return true
	end
	
	if restrictedUnitTypes[unitDefID] then
		return false
	end
	
	return true
end
