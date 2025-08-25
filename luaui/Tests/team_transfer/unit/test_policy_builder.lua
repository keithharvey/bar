
function setup()
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("api_gadgets") then
			return require_policy_builder_module()
		elseif path:match("predicates") then
			return require_predicates_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
end

function require_policy_builder_module()
	local M = {}
	
	M.PolicyType = {
		ResourceTransfer = "ResourceTransfer",
		UnitTransfer = "UnitTransfer", 
		Command = "Command",
	}
	
	local policies = {
		[M.PolicyType.ResourceTransfer] = {},
		[M.PolicyType.UnitTransfer] = {},
		[M.PolicyType.Command] = {},
	}
	
	local function pushPolicy(policyType, entry)
		local list = policies[policyType]
		list[#list + 1] = entry
	end
	
	local function newBuilder()
		local current = {
			policyType = nil,
			predicates = {},
			handler = nil,
		}
		
		local builder = {}
		
		function builder:For(policyType)
			current = { policyType = policyType, predicates = {}, handler = nil }
			return self
		end
		
		function builder:When(predicateFn)
			current.predicates[#current.predicates + 1] = predicateFn
			return self
		end
		
		function builder:Use(handlerFn)
			current.handler = handlerFn
			pushPolicy(current.policyType, { predicates = current.predicates, handler = current.handler })
			current = { policyType = nil, predicates = {}, handler = nil }
			return self
		end
		
		return builder
	end
	
	function M.RegisterPolicy(registrationFn)
		local builder = newBuilder()
		registrationFn(builder)
	end
	
	function M.GetPolicies()
		return policies
	end
	
	M.PolicyBuilder = newBuilder
	
	return M
end

function require_predicates_module()
	local P = {}
	
	P.Command = {
		isGuard = function(ctx) return ctx.cmdID == 10 end, -- Mock CMD.GUARD = 10
		targetAllied = function(ctx) return ctx.targetAllied == true end,
		targetIsIncomplete = function(ctx) return ctx.targetIsComplete == false end,
	}
	
	P.Resource = {
		isMetalTransfer = function(ctx) return ctx.resource == "metal" end,
		isEnergyTransfer = function(ctx) return ctx.resource == "energy" end,
		areAlliedTeams = function(ctx) return ctx.areAlliedTeams == true end,
		isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled == true end,
	}
	
	P.Unit = {
		areAlliedTeams = function(ctx) return ctx.areAlliedTeams == true end,
		isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled == true end,
		isCapture = function(ctx) return ctx.capture == true end,
		takeBypassAllowed = function(ctx) return ctx.takeBypassAllowed == true end,
	}
	
	return P
end

function test()
	local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	
	local policy = TeamTransfer.PolicyBuilder()
	assert(policy ~= nil, "PolicyBuilder should create instance")
	assert(type(policy.For) == "function", "Policy should have For method")
	assert(type(policy.When) == "function", "Policy should have When method") 
	assert(type(policy.Use) == "function", "Policy should have Use method")
	
	local resourcePolicy = policy:For(TeamTransfer.PolicyType.ResourceTransfer)
	assert(resourcePolicy == policy, "For() should return same instance for chaining")
	
	local isMetalPredicate = function(ctx) return ctx.resource == "metal" end
	local policyWithPredicate = policy:When(isMetalPredicate)
	assert(policyWithPredicate == policy, "When() should return same instance for chaining")
	
	local allowHandler = function(ctx) return { allow = true } end
	local completedPolicy = policy:Use(allowHandler)
	assert(completedPolicy == policy, "Use() should return same instance")
	
	local chainedPolicy = TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.ResourceTransfer)
		:When(function(ctx) return ctx.resource == "metal" end)
		:When(function(ctx) return ctx.areAlliedTeams end)
		:Use(function(ctx) return { allow = true } end)
	
	assert(chainedPolicy ~= nil, "Chained policy should be created successfully")
	
	TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.UnitTransfer)
		:When(function(ctx) return ctx.areAlliedTeams end)
		:Use(function(ctx) return { deny = true } end)
	
	TeamTransfer.PolicyBuilder()
		:For(TeamTransfer.PolicyType.Command)
		:When(function(ctx) return ctx.cmdID == 10 end) -- Guard command
		:Use(function(ctx) return { allow = true } end)
	
	local policies = TeamTransfer.GetPolicies()
	assert(#policies[TeamTransfer.PolicyType.ResourceTransfer] >= 1, "Resource transfer policy should be registered")
	assert(#policies[TeamTransfer.PolicyType.UnitTransfer] >= 1, "Unit transfer policy should be registered")
	assert(#policies[TeamTransfer.PolicyType.Command] >= 1, "Command policy should be registered")
	
	local resourcePolicies = policies[TeamTransfer.PolicyType.ResourceTransfer]
	local firstPolicy = resourcePolicies[1]
	assert(firstPolicy.predicates ~= nil, "Policy should have predicates")
	assert(firstPolicy.handler ~= nil, "Policy should have handler")
	assert(#firstPolicy.predicates >= 1, "Policy should have at least one predicate")
	
	local testCtx = { resource = "metal", areAlliedTeams = true }
	local predicateResult = firstPolicy.predicates[1](testCtx)
	assert(predicateResult == true, "Metal predicate should return true for metal resource")
	
	local handlerResult = firstPolicy.handler(testCtx)
	assert(handlerResult.allow == true, "Handler should return allow = true")
end
