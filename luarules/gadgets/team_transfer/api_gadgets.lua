








local M = {}

local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

local policies = {
	[Definitions.PolicyType.ResourceTransfer] = {},
	[Definitions.PolicyType.UnitTransfer] = {},
	[Definitions.PolicyType.Command] = {},
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

local pipeline = {
	onAllowResourceTransfer = {},
	onAllowUnitTransfer = {},
	onAllowCommand = {},
}
function M.RegisterAllowResourceTransfer(fn) pipeline.onAllowResourceTransfer[#pipeline.onAllowResourceTransfer + 1] = fn end
function M.RegisterAllowUnitTransfer(fn) pipeline.onAllowUnitTransfer[#pipeline.onAllowUnitTransfer + 1] = fn end
function M.RegisterAllowCommand(fn) pipeline.onAllowCommand[#pipeline.onAllowCommand + 1] = fn end

function M.GetPolicies()
	return policies
end

function M.GetLegacyPipeline()
	return pipeline
end

return M
