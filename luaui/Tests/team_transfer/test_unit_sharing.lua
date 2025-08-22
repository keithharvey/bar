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
	assert(sharing ~= nil, "TeamTransfer API should be exposed via GG")
	
	local mode = sharing.getUnitSharingMode()
	assert(type(mode) == "string", "Unit sharing mode should be a string")
	
	local armadvconDefID = UnitDefNames.armadvcv and UnitDefNames.armadvcv.id
	if armadvconDefID then
		local unitDef = UnitDefs[armadvconDefID]
		assert(sharing.isT2ConstructorDef(unitDef), "Advanced constructor should be detected as T2")
	end
	
	local armpwDefID = UnitDefNames.armpw and UnitDefNames.armpw.id
	if armpwDefID then
		local unitDef = UnitDefs[armpwDefID]
		assert(not sharing.isT2ConstructorDef(unitDef), "Basic unit should not be detected as T2 constructor")
	end
	
	local unitIDs = {}
	for i = 1, 3 do
		local unitID = SyncedRun(function(locals)
			local x, z = Game.mapSizeX / 2 + locals.i * 100, Game.mapSizeZ / 2
			local y = Spring.GetGroundHeight(x, z)
			return Spring.CreateUnit("armpw", x, y, z, 0, Spring.GetMyTeamID())
		end, {i = i})
		table.insert(unitIDs, unitID)
	end
	
	Test.waitFrames(5)
	
	local shareable, unshareable, total = sharing.countUnshareable(unitIDs, "enabled")
	assert(total == 3, "Should count all units")
	assert(shareable == 3, "All units should be shareable in enabled mode")
	assert(unshareable == 0, "No units should be unshareable in enabled mode")
	
	local shareable2, unshareable2, total2 = sharing.countUnshareable(unitIDs, "disabled")
	assert(total2 == 3, "Should count all units")
	assert(shareable2 == 0, "No units should be shareable in disabled mode")
	assert(unshareable2 == 3, "All units should be unshareable in disabled mode")
	
	local combatShareable, combatUnshareable, combatTotal = sharing.countUnshareable(unitIDs, "combat")
	assert(combatTotal == 3, "Should count all units in combat mode")
	assert(combatShareable == 3, "Combat units should be shareable in combat mode")
	assert(combatUnshareable == 0, "Combat units should not be unshareable in combat mode")
	
	local armadvconDefID = UnitDefNames.armadvcv and UnitDefNames.armadvcv.id
	if armadvconDefID then
		local unitDef = UnitDefs[armadvconDefID]
		assert(sharing.isEconomicUnitDef(unitDef), "T2 constructor should be detected as economic")
	end
	
	local armpwDefID = UnitDefNames.armpw and UnitDefNames.armpw.id
	if armpwDefID then
		local unitDef = UnitDefs[armpwDefID]
		assert(not sharing.isEconomicUnitDef(unitDef), "Combat unit should not be detected as economic")
	end
	
	local armvpDefID = UnitDefNames.armvp and UnitDefNames.armvp.id
	if armvpDefID then
		local unitDef = UnitDefs[armvpDefID]
		assert(sharing.isEconomicUnitDef(unitDef), "Factory should be detected as economic")
	end
	
	assert(sharing.shouldShowShareButton(unitIDs, "enabled"), "Should show share button in enabled mode")
	assert(not sharing.shouldShowShareButton(unitIDs, "disabled"), "Should not show share button in disabled mode")
	
	local message = sharing.blockMessage(nil, "disabled")
	assert(type(message) == "string", "Block message should be a string")
	assert(string.find(message, "disabled"), "Block message should mention disabled mode")
	
	local combatMessage = sharing.blockMessage(1, "combat")
	assert(type(combatMessage) == "string", "Combat block message should be a string")
	assert(string.find(combatMessage, "economic"), "Combat block message should mention economic units")
	
	local combatT2Message = sharing.blockMessage(1, "combat_t2cons")
	assert(type(combatT2Message) == "string", "Combat+T2 block message should be a string")
	assert(string.find(combatT2Message, "combat"), "Combat+T2 block message should mention combat units")
end
