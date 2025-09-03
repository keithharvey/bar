---@load-file luaui/types/team_transfer.lua

local sharing = {}

-- Cache for valid unit IDs by sharing mode
local validUnitCache = {}

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
	return (not unitDef.isFactory)
		and #(unitDef.buildOptions or {}) > 0
		and unitDef.customParams and unitDef.customParams.techlevel == "2"
end

---Check if a unit definition is economic (energy, metal, factory, assist)
---@param unitDef table? Unit definition from UnitDefs
---@return boolean isEconomic True if the unit is economic
function sharing.isEconomicUnitDef(unitDef)
	if not unitDef then return false end
	if unitDef.canAssist or unitDef.isFactory then
		return true
	end
	if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
		return true
	end
	return false
end

-- Lazy initialize the cache for a specific mode
local function ensureCacheInitialized(mode)
	if validUnitCache[mode] then
		return
	end
	
	if mode == "enabled" or mode == "disabled" then
		-- No need to cache for these modes
		validUnitCache[mode] = {}
		return
	end
	
	validUnitCache[mode] = {}
	local cachedCount = 0
	
	for unitDefID, unitDef in pairs(UnitDefs) do
		if mode == "t2cons" then
			-- Direct check for T2 constructor
			if sharing.isT2ConstructorDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat" then
			if not sharing.isEconomicUnitDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat_t2cons" then
			if not sharing.isEconomicUnitDef(unitDef) or sharing.isT2ConstructorDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat" then
			if not sharing.isEconomicUnitDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat_t2cons" then
			if not sharing.isEconomicUnitDef(unitDef) or sharing.isT2ConstructorDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		end
	end
	
	Spring.Log("UnitSharing", LOG.ERROR, "Lazy initialized cache for mode '" .. mode .. "' with " .. cachedCount .. " shareable units")
end

-- Clear the cache (useful if sharing mode changes)
function sharing.clearCache()
	validUnitCache = {}
end

-- Check if cache is initialized for a specific mode
function sharing.isCacheInitialized(mode)
	mode = mode or sharing.getUnitSharingMode()
	return validUnitCache[mode] ~= nil
end

-- Debug function to show cache statistics
function sharing.getCacheStats()
	local stats = {}
	for mode, cache in pairs(validUnitCache) do
		local count = 0
		for _ in pairs(cache) do
			count = count + 1
		end
		stats[mode] = count
	end
	return stats
end

---Check if a unit type is allowed to be shared in the given mode
---@param unitDefID number Unit definition ID
---@param mode string? Sharing mode, defaults to current mode
---@return boolean allowed True if the unit type can be shared
function sharing.isUnitShareAllowedByMode(unitDefID, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then
		return false
	elseif mode == "t2cons" or mode == "combat" or mode == "combat_t2cons" then
		ensureCacheInitialized(mode)
		return validUnitCache[mode][unitDefID] == true
	end
	return true
end

---Count shareable vs unshareable units in a selection
---@param unitIDs number[] Array of unit IDs to check
---@param mode string? Sharing mode, defaults to current mode
---@return number shareable Number of units that can be shared
---@return number unshareable Number of units that cannot be shared
---@return number total Total number of units checked
function sharing.countUnshareable(unitIDs, mode)
	mode = mode or sharing.getUnitSharingMode()
	local total = #unitIDs
	if mode == "enabled" then
		return total, 0, total
	elseif mode == "disabled" then
		return 0, total, total
	end

	ensureCacheInitialized(mode)

	local shareable = 0
	for i = 1, total do
		local udid = Spring.GetUnitDefID(unitIDs[i])
		if udid and validUnitCache[mode][udid] then
			shareable = shareable + 1
		end
	end
	return shareable, (total - shareable), total
end

---Determine if the share button should be shown for a unit selection
---@param unitIDs number[] Array of unit IDs to check
---@param mode string? Sharing mode, defaults to current mode
---@return boolean shouldShow True if share button should be visible
function sharing.shouldShowShareButton(unitIDs, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then return false end
	local shareable, _, total = sharing.countUnshareable(unitIDs, mode)
	local result = total > 0 and shareable > 0
	return result
end

---Get error message for blocked sharing attempts
---@param unshareable number? Number of unshareable units
---@param mode string? Sharing mode, defaults to current mode
---@return string? message Error message or nil if no error
function sharing.blockMessage(unshareable, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then
		return "Unit sharing is disabled"
	elseif mode == "t2cons" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " unshareable units. Share mode is T2 constructors only"
	elseif mode == "combat" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " economic units. Share mode is combat units only"
	elseif mode == "combat_t2cons" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " unshareable units. Share mode is combat units and T2 constructors only"
	end
	return nil
end

return sharing


