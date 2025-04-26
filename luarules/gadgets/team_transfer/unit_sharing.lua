-- Unit sharing and transfer logic implementation
-- Provides comprehensive unit sharing logic for testing
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local sharing = {}

---Classify a unit definition by type
---@param unitDef table Unit definition from UnitDefs
---@return string unitType One of SharedEnums.UnitType values
function sharing.classifyUnitDef(unitDef)
	if not unitDef then return nil end
	
	-- Economic units include T2 constructors, so check economic first
	if sharing.isEconomicUnitDef(unitDef) then
		-- T2 constructors are a special subset of economic units
		if sharing.isT2ConstructorDef(unitDef) then
			return SharedEnums.UnitType.T2Constructor
		end
		return SharedEnums.UnitType.Economic
	end
	
	if sharing.isUtilityUnitDef(unitDef) then
		return SharedEnums.UnitType.Utility
	end
	
	if sharing.isCombatUnitDef(unitDef) then
		return SharedEnums.UnitType.Combat
	end
	
	-- Default to combat for unclassified units
	return SharedEnums.UnitType.Combat
end

---Get the current unit sharing mode from modoptions
---@return string mode Current sharing mode ("enabled", "disabled", "t2cons", "combat", "combat_t2cons")
function sharing.getUnitSharingMode()
	local mo = Spring.GetModOptions and Spring.GetModOptions()
	return (mo and mo.unit_sharing_mode) or "enabled"
end

---Check if a unit definition is a T2 constructor
---@param unitDef table? Unit definition from UnitDefs
---@return boolean isT2Con True if the unit is a T2 constructor
function sharing.isT2ConstructorDef(unitDef)
	if not unitDef then return false end


	-- Use the comprehensive check for T2 constructor units
	local isNotFactory = not unitDef.isFactory
	local hasBuildOptions = #(unitDef.buildOptions or {}) > 0
	local hasCustomParams = unitDef.customParams ~= nil
	local isT2 = hasCustomParams and unitDef.customParams.techlevel == 2
	
	return isNotFactory and hasBuildOptions and hasCustomParams and isT2
end

---Check if a unit definition is combat-oriented (weapons, defense, offense)
---@param unitDef table? Unit definition from UnitDefs
---@return boolean isCombat True if the unit is combat-focused
function sharing.isCombatUnitDef(unitDef)
	if not unitDef then return false end

	if unitDef.customParams and (
		unitDef.customParams.unitgroup == "weapon" or
		unitDef.customParams.unitgroup == "aa" or
		unitDef.customParams.unitgroup == "sub" or
		unitDef.customParams.unitgroup == "weaponaa" or
		unitDef.customParams.unitgroup == "weaponsub" or
		unitDef.customParams.unitgroup == "emp" or
		unitDef.customParams.unitgroup == "nuke" or
		unitDef.customParams.unitgroup == "antinuke" or
		unitDef.customParams.unitgroup == "explo"
	) then
		return true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		return true
	end

	return false
end

---Check if a unit definition is economic (construction units only)
---@param unitDef table? Unit definition from UnitDefs
---@return boolean isEconomic True if the unit is for construction/building
function sharing.isEconomicUnitDef(unitDef)
	if not unitDef then return false end

	-- Economic units: builders, factories, assist units (construction-focused)
	if unitDef.canAssist or unitDef.isFactory or unitDef.builder then
		return true
	end

	return false
end

---Check if a unit definition is a utility building (resource generation, storage, etc.)
---@param unitDef table? Unit definition from UnitDefs  
---@return boolean isUtility True if the unit is a utility building
function sharing.isUtilityUnitDef(unitDef)
	if not unitDef then return false end

	-- Resource generation units: energy and metal producers/extractors
	if unitDef.customParams and (
		unitDef.customParams.unitgroup == SharedEnums.ResourceType.ENERGY or
		unitDef.customParams.unitgroup == SharedEnums.ResourceType.METAL
	) then
		return true
	end

	-- Utility buildings that support economy (not combat)
	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
		return true
	end

	return false
end


return sharing
