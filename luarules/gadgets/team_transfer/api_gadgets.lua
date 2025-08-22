---@meta
---@module "luarules/gadgets/team_transfer/api_gadgets"

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
---@field Commands CommandBuilder
---@field ResourceTransfers ResourceTransferBuilder
---@field UnitTransfers UnitTransferBuilder

---@class CommandBuilder
---@field Guard GuardBuilder
---@field Repair RepairBuilder
---@field Reclaim ReclaimBuilder

---@class GuardBuilder
---@field Allied PolicyBuilder
---@field Enemy PolicyBuilder

---@class RepairBuilder
---@field Allied PolicyBuilder

---@class ReclaimBuilder
---@field Allied PolicyBuilder
---@field Enemy PolicyBuilder

---@class ResourceTransferBuilder
---@field Allied PolicyBuilder
---@field Enemy PolicyBuilder

---@class UnitTransferBuilder
---@field Allied PolicyBuilder
---@field Enemy PolicyBuilder

---@class TeamTransferAPI
---@field PolicyType { ResourceTransfer: string, UnitTransfer: string, Command: string }
---@field RegisterPolicy fun(registrar: fun(policy: PolicyBuilder))
---@field GetPolicies fun(): table
---@field GetPipeline fun(): table
---@field UnitSharing table
---@field ResourceShareTax table
---@field MODOPTION_KEYS table
---@field Predicates TeamTransferPredicates
---@field Units table
---@field IsSharingOption fun(modoptionKey: string): boolean

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

	local function createPolicyBuilder(policyType, predicates)
		local policyBuilder = {}
		
		function policyBuilder:When(predicateFn)
			local newPredicates = {}
			for i = 1, #predicates do
				newPredicates[i] = predicates[i]
			end
			newPredicates[#newPredicates + 1] = predicateFn
			return createPolicyBuilder(policyType, newPredicates)
		end
		
		function policyBuilder:Use(handlerFn)
			pushPolicy(policyType, { predicates = predicates, handler = handlerFn })
			return self
		end
		
		function policyBuilder:Allow()
			pushPolicy(policyType, { predicates = predicates, handler = function(ctx) return { allow = true } end })
			return self
		end
		
		function policyBuilder:Deny()
			pushPolicy(policyType, { predicates = predicates, handler = function(ctx) return { deny = true } end })
			return self
		end
		
		return policyBuilder
	end

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

	builder.Commands = {
		Guard = {
			Allied = createPolicyBuilder(M.PolicyType.Command, {
				M.Predicates.Command.isGuard,
				M.Predicates.Command.targetAllied,
				M.Predicates.Command.targetHasAssist
			}),
			Enemy = createPolicyBuilder(M.PolicyType.Command, {
				M.Predicates.Command.isGuard,
				function(ctx) return not ctx.targetAllied end,
				M.Predicates.Command.targetHasAssist
			})
		},
		Repair = {
			Allied = createPolicyBuilder(M.PolicyType.Command, {
				M.Predicates.Command.isRepair,
				M.Predicates.Command.targetAllied,
				M.Predicates.Command.targetIsIncomplete
			})
		},
		Reclaim = {
			Allied = createPolicyBuilder(M.PolicyType.Command, {
				M.Predicates.Command.isReclaim,
				M.Predicates.Command.targetAllied
			}),
			Enemy = createPolicyBuilder(M.PolicyType.Command, {
				M.Predicates.Command.isReclaim,
				function(ctx) return not ctx.targetAllied end
			})
		}
	}

	builder.ResourceTransfers = {
		Allied = createPolicyBuilder(M.PolicyType.ResourceTransfer, {
			function(ctx) return ctx.areAlliedTeams end
		}),
		Enemy = createPolicyBuilder(M.PolicyType.ResourceTransfer, {
			function(ctx) return not ctx.areAlliedTeams end
		})
	}

	builder.UnitTransfers = {
		Allied = createPolicyBuilder(M.PolicyType.UnitTransfer, {
			function(ctx) return ctx.areAlliedTeams end
		}),
		Enemy = createPolicyBuilder(M.PolicyType.UnitTransfer, {
			function(ctx) return not ctx.areAlliedTeams end
		})
	}

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

-- Expose shared helpers and constants for gadgets/widgets
M.UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
M.ResourceShareTax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
M.MODOPTION_KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")
---@type TeamTransferPredicates
M.Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")
M.Units = VFS.Include("luarules/gadgets/team_transfer/units.lua")

-- Inline sharing mode option check to avoid extra includes and improve discoverability
local cachedSharingModes
local function loadSharingModes()
	if cachedSharingModes then return cachedSharingModes end
	cachedSharingModes = {}
	if VFS.FileExists("gamedata/sharingoptions.json") then
		local jsonStr = VFS.LoadFile("gamedata/sharingoptions.json")
		if jsonStr then
			for modeBlock in jsonStr:gmatch('"key"%s*:%s*"([^"]+)".-"options"%s*:%s*{(.-)}') do
				local key = modeBlock
				if key then
					cachedSharingModes[key] = {}
					for optKey in modeBlock:gmatch('"([^"_][^"]*)"%s*:') do
						cachedSharingModes[key][optKey] = true
					end
				end
			end
		end
	end
	return cachedSharingModes
end

function M.IsSharingOption(modoptionKey)
	local selectedMode = Spring.GetModOptions()._sharing_mode_selected or ""
	if selectedMode == "" then return true end
	local modes = loadSharingModes()
	local modeCfg = modes[selectedMode]
	if not modeCfg then return true end
	return modeCfg[modoptionKey] ~= nil
end

---@return TeamTransferAPI
return M
