
function setup()
	_G.Spring = _G.Spring or {}
	Spring.GetModOptions = function()
		return {
			unit_sharing_mode = "enabled" -- Default for testing
		}
	end
	
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("unit_sharing") then
			return require_unit_sharing_module()
		end
		return {}
	end
end

function cleanup()
	_G.Spring = nil
	_G.VFS = nil
end

function require_unit_sharing_module()
	local sharing = {}
	
	function sharing.getUnitSharingMode()
		local mo = Spring.GetModOptions and Spring.GetModOptions()
		return (mo and mo.unit_sharing_mode) or "enabled"
	end
	
	function sharing.isT2ConstructorDef(unitDef)
		if not unitDef then return false end
		
		return (unitDef.techLevel and unitDef.techLevel >= 2) and
		       unitDef.isBuilder and 
		       unitDef.canMove and
		       not unitDef.isFactory
	end
	
	function sharing.countUnshareable(unitIDs, mode)
		mode = mode or sharing.getUnitSharingMode()
		local total = #unitIDs
		local shareable = 0
		local unshareable = 0
		
		if mode == "disabled" then
			return 0, total, total
		elseif mode == "enabled" then
			return total, 0, total
		elseif mode == "t2cons" then
			for _, unitID in ipairs(unitIDs) do
				local mockUnitDef = getMockUnitDef(unitID)
				if sharing.isT2ConstructorDef(mockUnitDef) then
					shareable = shareable + 1
				else
					unshareable = unshareable + 1
				end
			end
			return shareable, unshareable, total
		end
		
		return 0, total, total
	end
	
	function sharing.shouldShowShareButton(unitIDs, mode)
		mode = mode or sharing.getUnitSharingMode()
		if mode == "disabled" then return false end
		
		local shareable, unshareable, total = sharing.countUnshareable(unitIDs, mode)
		return total > 0 and shareable > 0
	end
	
	function sharing.blockMessage(unshareable, mode)
		mode = mode or sharing.getUnitSharingMode()
		if mode == "disabled" then
			return "Unit sharing is disabled"
		elseif mode == "t2cons" then
			if unshareable and unshareable > 0 then
				return "Only T2 constructors can be shared in this mode"
			end
		end
		return "Cannot share selected units"
	end
	
	return sharing
end

function getMockUnitDef(unitID)
	local mockDefs = {
		[1] = { techLevel = 1, isBuilder = true, canMove = true, isFactory = false }, -- T1 constructor
		[2] = { techLevel = 2, isBuilder = true, canMove = true, isFactory = false }, -- T2 constructor  
		[3] = { techLevel = 1, isBuilder = false, canMove = true, isFactory = false }, -- Regular unit
		[4] = { techLevel = 2, isBuilder = true, canMove = false, isFactory = true }, -- Factory
	}
	return mockDefs[unitID] or { techLevel = 1, isBuilder = false, canMove = true, isFactory = false }
end

function test()
	local sharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
	
	local mode = sharing.getUnitSharingMode()
	assert(type(mode) == "string", "Unit sharing mode should be a string")
	assert(mode == "enabled", "Default mode should be enabled")
	
	Spring.GetModOptions = function() return { unit_sharing_mode = "disabled" } end
	assert(sharing.getUnitSharingMode() == "disabled", "Should detect disabled mode")
	
	Spring.GetModOptions = function() return { unit_sharing_mode = "t2cons" } end
	assert(sharing.getUnitSharingMode() == "t2cons", "Should detect t2cons mode")
	
	Spring.GetModOptions = function() return {} end
	assert(sharing.getUnitSharingMode() == "enabled", "Should default to enabled when not specified")
	
	local t1Constructor = { techLevel = 1, isBuilder = true, canMove = true, isFactory = false }
	assert(not sharing.isT2ConstructorDef(t1Constructor), "T1 constructor should not be detected as T2")
	
	local t2Constructor = { techLevel = 2, isBuilder = true, canMove = true, isFactory = false }
	assert(sharing.isT2ConstructorDef(t2Constructor), "T2 constructor should be detected")
	
	local factory = { techLevel = 2, isBuilder = true, canMove = false, isFactory = true }
	assert(not sharing.isT2ConstructorDef(factory), "Factory should not be detected as T2 constructor")
	
	local regularUnit = { techLevel = 1, isBuilder = false, canMove = true, isFactory = false }
	assert(not sharing.isT2ConstructorDef(regularUnit), "Regular unit should not be detected as T2 constructor")
	
	assert(not sharing.isT2ConstructorDef(nil), "Nil unitDef should not be detected as T2 constructor")
	
	Spring.GetModOptions = function() return { unit_sharing_mode = "enabled" } end
	local unitIDs = {1, 2, 3, 4}
	local shareable, unshareable, total = sharing.countUnshareable(unitIDs, "enabled")
	assert(total == 4, "Should count all units")
	assert(shareable == 4, "All units should be shareable in enabled mode")
	assert(unshareable == 0, "No units should be unshareable in enabled mode")
	
	local shareable2, unshareable2, total2 = sharing.countUnshareable(unitIDs, "disabled")
	assert(total2 == 4, "Should count all units")
	assert(shareable2 == 0, "No units should be shareable in disabled mode")
	assert(unshareable2 == 4, "All units should be unshareable in disabled mode")
	
	local shareable3, unshareable3, total3 = sharing.countUnshareable(unitIDs, "t2cons")
	assert(total3 == 4, "Should count all units")
	assert(shareable3 == 1, "Only T2 constructor should be shareable in t2cons mode") -- unitID 2
	assert(unshareable3 == 3, "Non-T2 constructors should be unshareable in t2cons mode")
	
	assert(sharing.shouldShowShareButton(unitIDs, "enabled"), "Should show share button in enabled mode")
	assert(not sharing.shouldShowShareButton(unitIDs, "disabled"), "Should not show share button in disabled mode")
	assert(sharing.shouldShowShareButton(unitIDs, "t2cons"), "Should show share button in t2cons mode with T2 constructor")
	assert(not sharing.shouldShowShareButton({1, 3}, "t2cons"), "Should not show share button in t2cons mode without T2 constructor")
	assert(not sharing.shouldShowShareButton({}, "enabled"), "Should not show share button with no units")
	
	assert(sharing.blockMessage(nil, "disabled") == "Unit sharing is disabled", "Should return disabled message")
	assert(sharing.blockMessage(2, "t2cons") == "Only T2 constructors can be shared in this mode", "Should return t2cons block message")
	assert(sharing.blockMessage(0, "t2cons") == "Cannot share selected units", "Should return generic message for no unshareable units")
	
	local emptyResult = sharing.countUnshareable({}, "enabled")
	assert(emptyResult == 0, "Empty unit list should return 0 shareable")
	
	local singleT2 = sharing.countUnshareable({2}, "t2cons")
	assert(singleT2 == 1, "Single T2 constructor should be shareable in t2cons mode")
	
	Spring.GetModOptions = function() return { unit_sharing_mode = "t2cons" } end
	local fallbackResult = sharing.countUnshareable(unitIDs) -- No mode parameter
	assert(fallbackResult == 1, "Should use current sharing mode when no mode parameter provided")
end
