---@meta
---@module "luarules/gadgets/team_transfer/api_gadgets"

---@load-file luaui/types/team_transfer.lua

---@class TeamTransferAPI
local M = {}



local sharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")
local modOpts = Spring.GetModOptions()

M.PolicyType = {
	ResourceTransfer = "ResourceTransfer",
	UnitTransfer = "UnitTransfer",
	Command = "Command",
	TeamEvent = "TeamEvent",
}

M.Scope = { Allied = "Allied", Enemy = "Enemy" }

local policies = {
	[M.PolicyType.ResourceTransfer] = {},
	[M.PolicyType.UnitTransfer] = {},
	[M.PolicyType.Command] = {},
	[M.PolicyType.TeamEvent] = {},
}

local function pushPolicy(policyType, entry)
	local list = policies[policyType]
	list[#list + 1] = entry
end

-- Top-level builder factory to enable Go To Definition into real code
---@param policyType string
---@param predicates table
---@return PolicyBuilderBase
local function makePolicyBuilder(policyType, predicates)
    local function _create(policyTypeInner, predicatesInner)
        local policyBuilder = {}

        function policyBuilder:When(predicateFn)
            local newPredicates = {}
            for i = 1, #predicatesInner do
                newPredicates[i] = predicatesInner[i]
            end
            newPredicates[#newPredicates + 1] = predicateFn
            return _create(policyTypeInner, newPredicates)
        end

        function policyBuilder:Use(handlerFn)
            pushPolicy(policyTypeInner, { predicates = predicatesInner, handler = handlerFn })
            return self
        end

        function policyBuilder:Allow()
            pushPolicy(policyTypeInner, { predicates = predicatesInner, handler = function(ctx) return { allow = true } end })
            return self
        end

        function policyBuilder:Deny()
            pushPolicy(policyTypeInner, { predicates = predicatesInner, handler = function(ctx) return { deny = true } end })
            return self
        end

        return policyBuilder
    end

    return _create(policyType, predicates)
end

-- Flat, scope-specific helpers (top-level for F12 navigation)



---@return PolicyBuilder
local function newBuilder()
	---@class PolicyBuilder
	local builder = {}

	-- Create the action methods that can be used at the end of chains
	---@class ActionMethods
	---@field Allow fun(): PolicyBuilder Allow this policy to proceed - permits the action when all predicates match
	---@field Deny fun(): PolicyBuilder Deny this policy from proceeding - blocks the action when all predicates match  
	---@field Use fun(handlerFn: function): PolicyBuilder Use custom handler - run custom logic when all predicates match
	
	---@return ActionMethods
	local function createActionMethods(policyType, predicates)
		local actions = {}
		
		---Allow this policy to proceed
		---Registers a policy that permits the action when all predicates match
		---Example: policy.ForAlliedCommands.WhenGuard.Allow() - allows guard commands to allied units
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Allow = function()
			pushPolicy(policyType, { predicates = predicates, handler = function(ctx) return { allow = true } end })
			return builder
		end
		
		---Deny this policy from proceeding
		---Registers a policy that blocks the action when all predicates match
		---Example: policy.ForAlliedCommands.WhenGuard.Deny() - blocks guard commands to allied units
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Deny = function()
			pushPolicy(policyType, { predicates = predicates, handler = function(ctx) return { deny = true } end })
			return builder
		end
		
		---Use custom handler for this policy
		---Registers a policy with custom logic when all predicates match
		---@param handlerFn function Custom handler function that receives context and returns { allow: boolean } or { deny: boolean } or { applyCommands: table }
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Use = function(handlerFn)
			pushPolicy(policyType, { predicates = predicates, handler = handlerFn })
			return builder
		end
		
		return actions
	end

	-- Centralized scope predicates - single source of truth
	local ScopePredicates = {
		Allied = {
			Command = M.Predicates.Command.targetAllied,
			Transfer = function(ctx) return ctx.areAlliedTeams end
		},
		Enemy = {
			Command = function(ctx) return not ctx.targetAllied end,
			Transfer = function(ctx) return not ctx.areAlliedTeams end
		}
	}

	-- Direct property assignments for better F12 navigation (like we had working before)
	
	---For allied command-based policies - Guard commands targeting allied units
	---@type table
	builder.ForAlliedCommands = {}
	
	---When command is Guard - applies to units being ordered to guard other units
	---Checks: command type is Guard AND target has assist capability
	---@type ActionMethods
	builder.ForAlliedCommands.WhenGuard = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isGuard,
		M.Predicates.Command.targetHasAssist
	})
	
	---When command is Repair - applies to units being ordered to repair other units
	---Checks: command type is Repair AND target is damaged/incomplete
	---@type ActionMethods
	builder.ForAlliedCommands.WhenRepair = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isRepair,
		M.Predicates.Command.targetIsIncomplete
	})
	
	---When command is Reclaim - applies to units being ordered to reclaim other units/features
	---Checks: command type is Reclaim
	---@type ActionMethods
	builder.ForAlliedCommands.WhenReclaim = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isReclaim
	})
	
	---For enemy command-based policies - Guard commands targeting enemy units
	---@type table
	builder.ForEnemyCommands = {}
	
	---When command is Guard - applies to units being ordered to guard enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenGuard = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isGuard,
		function(ctx) return not ctx.targetAllied end,
		M.Predicates.Command.targetHasAssist
	})
	
	---When command is Repair - applies to units being ordered to repair enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenRepair = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isRepair,
		function(ctx) return not ctx.targetAllied end,
		M.Predicates.Command.targetIsIncomplete
	})
	
	---When command is Reclaim - applies to units being ordered to reclaim enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenReclaim = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isReclaim,
		function(ctx) return not ctx.targetAllied end
	})
	
	---For allied resource transfer policies - metal/energy transfers to allied teams
	---@type ActionMethods
	builder.ForAlliedResourceTransfers = createActionMethods(M.PolicyType.ResourceTransfer, {
		ScopePredicates.Allied.Transfer
	})
	
	---For enemy resource transfer policies - metal/energy transfers to enemy teams
	---@type ActionMethods
	builder.ForEnemyResourceTransfers = createActionMethods(M.PolicyType.ResourceTransfer, {
		ScopePredicates.Enemy.Transfer
	})
	
	---For allied unit transfer policies - unit sharing to allied teams
	---@type ActionMethods
	builder.ForAlliedUnitTransfers = createActionMethods(M.PolicyType.UnitTransfer, {
		ScopePredicates.Allied.Transfer
	})
	
	---For enemy unit transfer policies - unit sharing to enemy teams
	---@type ActionMethods
	builder.ForEnemyUnitTransfers = createActionMethods(M.PolicyType.UnitTransfer, {
		ScopePredicates.Enemy.Transfer
	})

	---For team event policies
	---@type table
	builder.TeamEvents = {}

	---When a player abandons their team (disconnects or goes spec)
	---@type ActionMethods
	builder.TeamEvents.PlayerAbandoned = createActionMethods(M.PolicyType.TeamEvent, {
		function(ctx) return ctx.eventType == "PlayerAbandoned" end
	})

	---When a player reconnects to their team
	---@type ActionMethods
	builder.TeamEvents.PlayerReconnected = createActionMethods(M.PolicyType.TeamEvent, {
		function(ctx) return ctx.eventType == "PlayerReconnected" end
	})

	return builder
end

---Register a new policy with the Team Transfer Framework
---@param registrationFn fun(policy: PolicyBuilder) Function that configures the policy
---@type fun(registrationFn: fun(policy: PolicyBuilder))
function M.RegisterPolicy(registrationFn)
	---@type PolicyBuilder
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

---Get all registered policies by type
---@return table<string, table[]> policies Policies organized by type
function M.GetPolicies()
	return policies
end

---Get the legacy pipeline callbacks
---@return table pipeline Legacy callback system
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
---Check if a modoption key is enabled in the current sharing mode and return its value
---@param modoptionKey string The modoption key to check
---@return boolean enabled True if the option is enabled in current mode
---@return any value The current value from Spring.GetModOptions()[modoptionKey] (may be nil)
function M.IsSharingOption(modoptionKey)
	return sharingModeUtils.isOptionEnabledInCurrentMode(modoptionKey), modOpts[modoptionKey]
end

---@return TeamTransferAPI
return M
