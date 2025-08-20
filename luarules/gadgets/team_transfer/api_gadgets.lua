---@meta
---@class TeamTransferPolicyContext
---@field type string
---@field resource? "metal"|"energy"
---@field amount? number
---@field amountClamped? number
---@field maxShare? number
---@field receiverCur? number
---@field cumulativeMetal? number
---@field senderTeamId? number
---@field receiverTeamId? number
---@field fromTeamID? number
---@field toTeamID? number
---@field areAlliedTeams? boolean
---@field isCheatingEnabled? boolean
---@field senderIsNonPlayer? boolean
---@field receiverIsNonPlayer? boolean
---@field fromIsNonPlayer? boolean
---@field toIsNonPlayer? boolean
---@field capture? boolean
---@field takeBypassAllowed? boolean
---@field unitID? number
---@field unitDefID? number
---@field unitTeam? number
---@field commandID? number
---@field cmdID? number
---@field cmdParams? number[]
---@field cmdOptions? table
---@field cmdTag? number
---@field synced? boolean
---@field targetID? number
---@field targetTeam? number
---@field targetUnitDef? table
---@field targetAllied? boolean
---@field targetIsComplete? boolean

---@class TeamTransferApplyTransfer
---@field sent number
---@field received number
---@field updateCumulativeMetal? boolean

---@class TeamTransferExpose
---@field taxRate? number
---@field threshold? number

---@class TeamTransferResultTable
---@field allow? boolean
---@field deny? boolean
---@field applyTransfer? TeamTransferApplyTransfer
---@field expose? TeamTransferExpose

---@alias TeamTransferResult boolean|TeamTransferResultTable|nil
---@alias TeamTransferPredicate fun(ctx: TeamTransferPolicyContext): boolean
---@alias TeamTransferHandler fun(ctx: TeamTransferPolicyContext): TeamTransferResult

---@class PolicyBuilder
---@field For fun(self: PolicyBuilder, policyType: string): PolicyBuilder
---@field When fun(self: PolicyBuilder, predicate: TeamTransferPredicate): PolicyBuilder
---@field Use fun(self: PolicyBuilder, handler: TeamTransferHandler)

---@class TeamTransferAPI
---@field RegisterPolicy fun(registrar: fun(policy: PolicyBuilder))









local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

local M = {}

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

function M.GetPipeline()
	return pipeline
end

return M
