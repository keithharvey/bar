local upget = gadget or widget
local globalScope = gadget and GG or WG

local unitSharingMode = Spring.GetModOptions().unit_sharing_mode or "enabled"
local disableAllyExtractorUpgrade = Spring.GetModOptions().disable_ally_extractor_upgrade

if unitSharingMode == "enabled" and not disableAllyExtractorUpgrade then
	return false
end

function upget:GetInfo()
	return {
		name = "Modoption: Sharing UI Restrictions",
		desc = "UI behavior for sharing modoptions",
		author = "BAR",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

if gadget then
	if not gadgetHandler:IsSyncedCode() then
		return
	end
end

local restrictedUnits = {}
if unitSharingMode == "economy" then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not (unitDef.canAssist or unitDef.isFactory or unitDef.isBuilder) then
			if not (unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal")) then
				if unitDef.extractsMetal <= 0 then
					restrictedUnits[unitDefID] = true
				end
			end
		end
	end
elseif unitSharingMode == "combat" then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not (unitDef.canAttack or unitDef.weapons) then
			restrictedUnits[unitDefID] = true
		end
	end
elseif unitSharingMode == "t2cons" then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not (unitDef.isBuilder and unitDef.techLevel and unitDef.techLevel >= 2) then
			restrictedUnits[unitDefID] = true
		end
	end
elseif unitSharingMode == "disabled" then
	for unitDefID, unitDef in pairs(UnitDefs) do
		restrictedUnits[unitDefID] = true
	end
end

function upget:Initialize()
	if widget then
		if disableAllyExtractorUpgrade and globalScope['resource_spot_builder'] and globalScope['resource_spot_builder'].SetAllyExtractorCanBeUpgraded then
			globalScope['resource_spot_builder'].SetAllyExtractorCanBeUpgraded(false)
		end
		
		if unitSharingMode == "disabled" and globalScope['topbar'] and globalScope['topbar'].setShareSliderEnabled then
			globalScope['topbar'].setShareSliderEnabled(false)
		end
		
		if next(restrictedUnits) and globalScope['sharecmd'] and globalScope['sharecmd'].setRestrictedUnits then
			globalScope['sharecmd'].setRestrictedUnits(restrictedUnits)
		end
		
		if unitSharingMode == "disabled" and globalScope['advplayerlist_api'] and globalScope['advplayerlist_api'].SetModuleActive then
			globalScope['advplayerlist_api'].SetModuleActive({ 'share_resource', false })
		end
	end
end
