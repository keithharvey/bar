
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
	local sharing = GG.TeamTransfer
	assert(sharing ~= nil, "TeamTransfer API should be exposed via GG")
	assert(sharing.Predicates ~= nil, "Predicates should be exposed")
	
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	assert(TeamTransfer ~= nil, "TeamTransfer module should be available")
	assert(TeamTransfer.PolicyBuilder ~= nil, "PolicyBuilder should be available")
	
	assert(TeamTransfer.PolicyType.ResourceTransfer ~= nil, "ResourceTransfer policy type should exist")
	assert(TeamTransfer.PolicyType.UnitTransfer ~= nil, "UnitTransfer policy type should exist")
	assert(TeamTransfer.PolicyType.Command ~= nil, "Command policy type should exist")
	
	local policy = TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.ResourceTransfer)
		:When(function(ctx) return ctx.resource == "metal" end)
		:Use(function(ctx) return { allow = true } end)
	
	assert(policy ~= nil, "Fluent policy creation should work")
	
	local predicates = sharing.Predicates
	assert(type(predicates.Command.isGuard) == "function", "isGuard should be a function")
	assert(type(predicates.Resource.isMetalTransfer) == "function", "isMetalTransfer should be a function")
	assert(type(predicates.Unit.areAlliedTeams) == "function", "areAlliedTeams should be a function")
	
	local mockCtx = { cmdID = CMD.GUARD, resource = "metal", areAlliedTeams = true }
	assert(predicates.Command.isGuard(mockCtx), "isGuard predicate should work")
	assert(predicates.Resource.isMetalTransfer(mockCtx), "isMetalTransfer predicate should work")
	assert(predicates.Unit.areAlliedTeams(mockCtx), "areAlliedTeams predicate should work")
end
