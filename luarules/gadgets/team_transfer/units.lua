local M = {}

local function isT2Constructor(ud)
	if not ud then return false end
	if not ud.customParams then return false end
	local tl = tonumber(ud.customParams.techlevel or 1) or 1
	if tl >= 2 and (ud.isBuilder or ud.canAssist or (ud.buildOptions and #ud.buildOptions > 0)) then
		return true
	end
	return false
end

local economicUnits = {}
local combatUnits = {}
local t2Constructors = {}
local unitsInitialized = false

local function initializeUnitClassifications()
	if unitsInitialized then return end
	
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
		
		if unitDef.canAttack or unitDef.weapons then
			combatUnits[unitDefID] = true
		end
		
		if unitDef.isBuilder and unitDef.techLevel and unitDef.techLevel >= 2 then
			t2Constructors[unitDefID] = true
		end
	end
	
	unitsInitialized = true
end

function M.EconomicUnits()
	initializeUnitClassifications()
	return economicUnits
end

function M.IsEconomicUnit(unitDefID)
	initializeUnitClassifications()
	return economicUnits[unitDefID] == true
end

function M.IsCombatUnit(unitDefID)
	initializeUnitClassifications()
	return combatUnits[unitDefID] == true
end

function M.IsT2Constructor(unitDefID)
	initializeUnitClassifications()
	return t2Constructors[unitDefID] == true
end

function M.AllowUnitTransferByMode(unitID, unitDefID, fromTeamID, toTeamID, capture, mode)
	if capture then
		return true
	end

	if mode == "enabled" then
		return true
	elseif mode == "disabled" then
		return false
	elseif mode == "t2cons" then
		local ud = UnitDefs[unitDefID]
		return isT2Constructor(ud)
	end

	return false
end

return M
