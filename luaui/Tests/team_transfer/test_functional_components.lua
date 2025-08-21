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
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	assert(TeamTransfer ~= nil, "TeamTransfer module should be available")
	assert(TeamTransfer.PolicyBuilder ~= nil, "PolicyBuilder should be available")
	
	assert(TeamTransfer.PolicyType.ResourceTransfer ~= nil, "ResourceTransfer policy type should exist")
	assert(TeamTransfer.PolicyType.UnitTransfer ~= nil, "UnitTransfer policy type should exist")
	assert(TeamTransfer.PolicyType.Command ~= nil, "Command policy type should exist")
	
	local policy = TeamTransfer.PolicyBuilder()
	assert(policy ~= nil, "PolicyBuilder should create policy instance")
	assert(type(policy.For) == "function", "Policy should have For method")
	assert(type(policy.When) == "function", "Policy should have When method")
	assert(type(policy.Use) == "function", "Policy should have Use method")
	
	local policyWithType = policy:For(TeamTransfer.PolicyType.ResourceTransfer)
	assert(policyWithType ~= nil, "For() should return policy builder")
	assert(policyWithType == policy, "For() should return same instance for chaining")
	
	local testPredicate = function(ctx) return ctx.resource == "metal" end
	local policyWithPredicate = policy:When(testPredicate)
	assert(policyWithPredicate ~= nil, "When() should return policy builder")
	assert(policyWithPredicate == policy, "When() should return same instance for chaining")
	
	local testHandler = function(ctx) return { allow = true } end
	local completedPolicy = policy:Use(testHandler)
	assert(completedPolicy ~= nil, "Use() should return policy builder")
	
	local chainedPolicy = TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.ResourceTransfer)
		:When(function(ctx) return ctx.resource == "metal" end)
		:When(function(ctx) return ctx.areAlliedTeams end)
		:Use(function(ctx) return { allow = true } end)
	
	assert(chainedPolicy ~= nil, "Chained policy should be created successfully")
	
	local multiPredicatePolicy = TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.UnitTransfer)
		:When(GG.TeamTransfer.Predicates.Unit.areAlliedTeams)
		:When(GG.TeamTransfer.Predicates.Unit.isCheatingEnabled)
		:Use(function(ctx) return { deny = true } end)
	
	assert(multiPredicatePolicy ~= nil, "Multi-predicate policy should be created successfully")
	
	local resourcePolicy = TeamTransfer.PolicyBuilder():For(TeamTransfer.PolicyType.ResourceTransfer)
	local unitPolicy = TeamTransfer.PolicyBuilder():For(TeamTransfer.PolicyType.UnitTransfer)
	local commandPolicy = TeamTransfer.PolicyBuilder():For(TeamTransfer.PolicyType.Command)
	
	assert(resourcePolicy ~= nil, "Resource policy For block should work")
	assert(unitPolicy ~= nil, "Unit policy For block should work")
	assert(commandPolicy ~= nil, "Command policy For block should work")
	
	local predicates = GG.TeamTransfer.Predicates
	
	assert(type(predicates.Command.isGuard) == "function", "isGuard should be a function")
	assert(type(predicates.Command.targetAllied) == "function", "targetAllied should be a function")
	assert(type(predicates.Command.targetIsIncomplete) == "function", "targetIsIncomplete should be a function")
	
	assert(type(predicates.Resource.isMetalTransfer) == "function", "isMetalTransfer should be a function")
	assert(type(predicates.Resource.isEnergyTransfer) == "function", "isEnergyTransfer should be a function")
	assert(type(predicates.Resource.areAlliedTeams) == "function", "areAlliedTeams should be a function")
	
	assert(type(predicates.Unit.areAlliedTeams) == "function", "areAlliedTeams should be a function")
	assert(type(predicates.Unit.isCheatingEnabled) == "function", "isCheatingEnabled should be a function")
	assert(type(predicates.Unit.isCapture) == "function", "isCapture should be a function")
	
	local commandCtx = { cmdID = CMD.GUARD, targetAllied = true, targetIsComplete = false }
	assert(predicates.Command.isGuard(commandCtx), "isGuard predicate should work")
	assert(predicates.Command.targetAllied(commandCtx), "targetAllied predicate should work")
	assert(predicates.Command.targetIsIncomplete(commandCtx), "targetIsIncomplete predicate should work")
	
	local resourceCtx = { resource = "metal", areAlliedTeams = true, isCheatingEnabled = false }
	assert(predicates.Resource.isMetalTransfer(resourceCtx), "isMetalTransfer predicate should work")
	assert(not predicates.Resource.isEnergyTransfer(resourceCtx), "isEnergyTransfer predicate should work")
	assert(predicates.Resource.areAlliedTeams(resourceCtx), "areAlliedTeams predicate should work")
	
	local unitCtx = { areAlliedTeams = true, isCheatingEnabled = false, capture = false }
	assert(predicates.Unit.areAlliedTeams(unitCtx), "areAlliedTeams predicate should work")
	assert(not predicates.Unit.isCheatingEnabled(unitCtx), "isCheatingEnabled predicate should work")
	assert(not predicates.Unit.isCapture(unitCtx), "isCapture predicate should work")
end
