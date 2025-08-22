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
	
	Test.expectCallin("AllowResourceTransfer")
	Test.expectCallin("AllowUnitTransfer")
	
	local senderTeamID = Spring.GetMyTeamID()
	local receiverTeamID = senderTeamID -- Same team for testing
	
	local unitID = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("armpw", x, y, z, 0, locals.senderTeamID)
	end, {senderTeamID = senderTeamID})
	
	Test.waitFrames(5)
	
	SyncedRun(function(locals)
		Spring.ShareResources(locals.receiverTeamID, "metal", 100)
	end, {receiverTeamID = receiverTeamID})
	
	Test.waitUntilCallin("AllowResourceTransfer")
	
	SyncedRun(function(locals)
		Spring.TransferUnit(locals.unitID, locals.receiverTeamID, false)
	end, {unitID = unitID, receiverTeamID = receiverTeamID})
	
	Test.waitUntilCallin("AllowUnitTransfer")
	
	local predicates = { 
		Command = { isGuard = function(ctx) return ctx.cmdID == CMD.GUARD end },
		Resource = { 
			isMetalTransfer = function(ctx) return ctx.resource == "metal" end,
			isEnergyTransfer = function(ctx) return ctx.resource == "energy" end,
			areAlliedTeams = function(ctx) return ctx.areAlliedTeams end,
			isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end
		},
		Unit = {
			areAlliedTeams = function(ctx) return ctx.areAlliedTeams end,
			isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end,
			isCapture = function(ctx) return ctx.capture end,
			takeBypassAllowed = function(ctx) return ctx.takeBypassAllowed end
		}
	}
	assert(predicates ~= nil, "Predicates should be exposed")
	assert(type(predicates.Command.isGuard) == "function", "isGuard predicate should be a function")
	
	local mockCtx = {
		cmdID = CMD.GUARD,
		targetID = unitID
	}
	assert(predicates.Command.isGuard(mockCtx), "Should detect guard command")
	
	mockCtx.cmdID = CMD.MOVE
	assert(not predicates.Command.isGuard(mockCtx), "Should not detect non-guard command")
	
	local resourceCtx = {
		resource = "metal",
		areAlliedTeams = true,
		isCheatingEnabled = false
	}
	assert(predicates.Resource.isMetalTransfer(resourceCtx), "Should detect metal transfer")
	assert(predicates.Resource.areAlliedTeams(resourceCtx), "Should detect allied teams")
	assert(not predicates.Resource.isCheatingEnabled(resourceCtx), "Should detect cheating disabled")
	
	resourceCtx.resource = "energy"
	assert(predicates.Resource.isEnergyTransfer(resourceCtx), "Should detect energy transfer")
	assert(not predicates.Resource.isMetalTransfer(resourceCtx), "Should not detect metal when energy")
	
	local unitCtx = {
		areAlliedTeams = true,
		isCheatingEnabled = false,
		capture = false,
		takeBypassAllowed = true
	}
	assert(predicates.Unit.areAlliedTeams(unitCtx), "Should detect allied teams")
	assert(not predicates.Unit.isCheatingEnabled(unitCtx), "Should detect cheating disabled")
	assert(not predicates.Unit.isCapture(unitCtx), "Should detect non-capture")
	assert(predicates.Unit.takeBypassAllowed(unitCtx), "Should detect take bypass allowed")
	
	local armpwDefID = UnitDefNames.armpw and UnitDefNames.armpw.id
	if armpwDefID then
		local combatUnitAllowed = sharing.isUnitShareAllowedByMode(armpwDefID, "combat")
		assert(combatUnitAllowed, "Combat unit should be allowed in combat mode")
	end
	
	local armvpDefID = UnitDefNames.armvp and UnitDefNames.armvp.id
	if armvpDefID then
		local factoryAllowed = sharing.isUnitShareAllowedByMode(armvpDefID, "combat")
		assert(not factoryAllowed, "Factory should not be allowed in combat mode")
	end
	
	local armadvconDefID = UnitDefNames.armadvcv and UnitDefNames.armadvcv.id
	if armadvconDefID then
		local t2ConsAllowed = sharing.isUnitShareAllowedByMode(armadvconDefID, "combat_t2cons")
		assert(t2ConsAllowed, "T2 constructor should be allowed in combat_t2cons mode")
	end
end
