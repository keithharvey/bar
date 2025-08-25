function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local sharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
	GG.TeamTransfer = sharing
	
	local originalGetModOptions = Spring.GetModOptions
	
	Spring.GetModOptions = function() return { game_assist_ally = "enabled" } end
	local assistMode = Spring.GetModOptions().game_assist_ally
	assert(assistMode == "enabled", "Should detect enabled ally assist mode")
	
	Spring.GetModOptions = function() return { game_assist_ally = "disabled" } end
	assistMode = Spring.GetModOptions().game_assist_ally
	assert(assistMode == "disabled", "Should detect disabled ally assist mode")
	
	Spring.GetModOptions = function() return {} end
	assistMode = Spring.GetModOptions().game_assist_ally
	assert(assistMode == nil, "Should return nil when not specified")
	
	Spring.GetModOptions = originalGetModOptions
	
	local unitSharingMode = sharing.getUnitSharingMode()
	assert(type(unitSharingMode) == "string", "Unit sharing mode should be independent of ally assist")
	
	local armpwDefID = UnitDefNames.armpw and UnitDefNames.armpw.id
	if armpwDefID then
		local allowedEnabled = sharing.isUnitShareAllowedByMode(armpwDefID, "enabled")
		local allowedCombat = sharing.isUnitShareAllowedByMode(armpwDefID, "combat")
		assert(allowedEnabled, "Unit sharing should work regardless of ally assist setting")
		assert(allowedCombat, "Combat mode should work regardless of ally assist setting")
	end
	
	assert(sharing.isEconomicUnitDef(UnitDefs[4]), "T2 constructor should be economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[5]), "Factory should be economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[6]), "Energy building should be economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[7]), "Metal building should be economic")
	assert(not sharing.isEconomicUnitDef(UnitDefs[3]), "Combat unit should not be economic")
end
