function upget:GetInfo()
	return {
		name = "Modoption: Disable Economic Sharing",
		desc = "Modoption behavior for disabled economic sharing",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

if gadget then

local isSyncedGadget = gadget and gadgetHandler:IsSyncedCode()

if not isSyncedGadget then
	return
end

local UPGET_NAME = "modoption_disable_economic_sharing"

local restrictedUnits = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist or unitDef.isFactory or unitDef.isBuilder then
		restrictedUnits[unitDefID] = true
	end
	if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
		restrictedUnits[unitDefID] = true
	end
end

function gadget:Initialize()
	if widget then
		return
	end
	
	local isSyncedGadget = gadget and gadgetHandler:IsSyncedCode()
	if not isSyncedGadget then
		return
	end
	
	if globalScope['resource_spot_builder'] and globalScope['resource_spot_builder'].SetAllowExtractorCanBeUpgraded then
		globalScope['resource_spot_builder'].SetAllowExtractorCanBeUpgraded(false)
	end
	
	if globalScope['topbar'] and globalScope['topbar'].SetShareSliderEnabled then
		globalScope['topbar'].SetShareSliderEnabled(false)
	end
	
	if globalScope['sharecmd'] and globalScope['sharecmd'].SetRestrictedUnits then
		globalScope['sharecmd'].SetRestrictedUnits(restrictedUnits)
	end
	
	if globalScope['advplayerlist_api'] and globalScope['advplayerlist_api'].SetModuleActive then
		globalScope['advplayerlist_api'].SetModuleActive('share_resource', false)
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if capture then
		return true
	end
	
	if restrictedUnits[unitDefID] then
		return false
	end
	
	return true
end

end
