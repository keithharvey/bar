function setup()
	_G.VFS = _G.VFS or {}
	_G.Spring = _G.Spring or {}
	_G.UnitDefs = _G.UnitDefs or {}
	
	Spring.GetModOptions = function()
		return { unit_sharing_mode = "enabled" }
	end
	
	Spring.Log = function(section, level, message) end
	
	Spring.GetUnitDefID = function(unitID)
		return unitID
	end
	
	UnitDefs[1] = {
		isFactory = false,
		buildOptions = {"unit1", "unit2"},
		customParams = { techlevel = "2" }
	}
	
	UnitDefs[2] = {
		isFactory = true,
		buildOptions = {"unit1"},
		customParams = { techlevel = "1" }
	}
	
	UnitDefs[3] = {
		isFactory = false,
		buildOptions = {},
		customParams = { unitgroup = "energy" }
	}
	
	UnitDefs[4] = {
		isFactory = false,
		buildOptions = {},
		customParams = { unitgroup = "metal" }
	}
	
	UnitDefs[5] = {
		canAssist = true,
		isFactory = false,
		buildOptions = {},
		customParams = {}
	}
	
	VFS.Include = function(path)
		if path:match("unit_sharing") then
			return require_unit_sharing_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
	_G.Spring = nil
	_G.UnitDefs = nil
end

function require_unit_sharing_module()
	local sharing = {}
	local validUnitCache = {}

	function sharing.getUnitSharingMode()
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		return (mo and mo.unit_sharing_mode) or "enabled"
	end

	function sharing.isT2ConstructorDef(unitDef)
		if not unitDef then return false end
		return (not unitDef.isFactory)
			and #(unitDef.buildOptions or {}) > 0
			and unitDef.customParams and unitDef.customParams.techlevel == "2"
	end

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

	local function ensureCacheInitialized(mode)
		if validUnitCache[mode] then
			return
		end
		
		if mode == "enabled" or mode == "disabled" then
			validUnitCache[mode] = {}
			return
		end
		
		validUnitCache[mode] = {}
		local cachedCount = 0
		
		for unitDefID, unitDef in pairs(UnitDefs) do
			if mode == "t2cons" then
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
			end
		end
		
		Spring.Log("UnitSharing", "INFO", "Lazy initialized cache for mode '" .. mode .. "' with " .. cachedCount .. " shareable units")
	end

	function sharing.clearCache()
		validUnitCache = {}
	end

	function sharing.isCacheInitialized(mode)
		mode = mode or sharing.getUnitSharingMode()
		return validUnitCache[mode] ~= nil
	end

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

	function sharing.shouldShowShareButton(unitIDs, mode)
		mode = mode or sharing.getUnitSharingMode()
		if mode == "disabled" then return false end
		local shareable, _, total = sharing.countUnshareable(unitIDs, mode)
		local result = total > 0 and shareable > 0
		return result
	end

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
end

function test()
	local sharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
	
	assert(sharing.getUnitSharingMode() == "enabled", "Should return default enabled mode")
	
	assert(sharing.isT2ConstructorDef(UnitDefs[1]), "Should identify T2 constructor")
	assert(not sharing.isT2ConstructorDef(UnitDefs[2]), "Should not identify factory as T2 constructor")
	assert(not sharing.isT2ConstructorDef(UnitDefs[3]), "Should not identify economic unit as T2 constructor")
	
	assert(sharing.isEconomicUnitDef(UnitDefs[2]), "Should identify factory as economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[3]), "Should identify energy unit as economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[4]), "Should identify metal unit as economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[5]), "Should identify assist unit as economic")
	assert(not sharing.isEconomicUnitDef(UnitDefs[1]), "Should not identify T2 constructor as economic")
	
	assert(sharing.isUnitShareAllowedByMode(1, "enabled"), "Should allow all units in enabled mode")
	assert(not sharing.isUnitShareAllowedByMode(1, "disabled"), "Should not allow any units in disabled mode")
	
	assert(sharing.isUnitShareAllowedByMode(1, "t2cons"), "Should allow T2 constructor in t2cons mode")
	assert(not sharing.isUnitShareAllowedByMode(2, "t2cons"), "Should not allow factory in t2cons mode")
	
	assert(not sharing.isUnitShareAllowedByMode(2, "combat"), "Should not allow factory in combat mode")
	assert(not sharing.isUnitShareAllowedByMode(3, "combat"), "Should not allow energy unit in combat mode")
	
	assert(sharing.isUnitShareAllowedByMode(1, "combat_t2cons"), "Should allow T2 constructor in combat_t2cons mode")
	assert(not sharing.isUnitShareAllowedByMode(2, "combat_t2cons"), "Should not allow factory in combat_t2cons mode")
	
	local shareable, unshareable, total = sharing.countUnshareable({1, 2, 3}, "enabled")
	assert(shareable == 3 and unshareable == 0 and total == 3, "Should count all as shareable in enabled mode")
	
	shareable, unshareable, total = sharing.countUnshareable({1, 2, 3}, "disabled")
	assert(shareable == 0 and unshareable == 3 and total == 3, "Should count all as unshareable in disabled mode")
	
	shareable, unshareable, total = sharing.countUnshareable({1, 2, 3}, "t2cons")
	assert(shareable == 1 and unshareable == 2 and total == 3, "Should count only T2 constructor as shareable in t2cons mode")
	
	assert(sharing.shouldShowShareButton({1, 2, 3}, "enabled"), "Should show share button in enabled mode")
	assert(not sharing.shouldShowShareButton({1, 2, 3}, "disabled"), "Should not show share button in disabled mode")
	assert(sharing.shouldShowShareButton({1, 2, 3}, "t2cons"), "Should show share button when some units are shareable")
	
	assert(sharing.blockMessage(2, "disabled") == "Unit sharing is disabled", "Should return correct message for disabled mode")
	assert(sharing.blockMessage(2, "t2cons"):match("T2 constructors only"), "Should return correct message for t2cons mode")
	assert(sharing.blockMessage(2, "combat"):match("combat units only"), "Should return correct message for combat mode")
	assert(sharing.blockMessage(2, "combat_t2cons"):match("combat units and T2 constructors only"), "Should return correct message for combat_t2cons mode")
	
	sharing.clearCache()
	assert(not sharing.isCacheInitialized("t2cons"), "Should clear cache")
	
	sharing.isUnitShareAllowedByMode(1, "t2cons")
	assert(sharing.isCacheInitialized("t2cons"), "Should initialize cache when needed")
	
	local stats = sharing.getCacheStats()
	assert(type(stats) == "table", "Should return cache statistics")
end
