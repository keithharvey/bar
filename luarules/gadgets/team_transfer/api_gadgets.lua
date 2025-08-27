---@meta
---@module "luarules/gadgets/team_transfer/api_gadgets"

---@load-file luaui/types/team_transfer.lua

---@class TeamTransferAPI
local M = {}

-- Ensure policy pipeline only runs in synced context
local function requireSyncedContext(functionName)
	if gadgetHandler and not gadgetHandler:IsSyncedCode() then
		error("TeamTransfer." .. functionName .. " can only be called from synced context (gadgets), not unsynced context (widgets)")
	end
end

local sharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local json = VFS.Include("common/luaUtilities/json.lua")
local modOpts = Spring.GetModOptions()

-- Use shared enums for consistency across synced/unsynced contexts
M.PolicyType = SharedEnums.PolicyType
M.Policies = SharedEnums.Policies
M.Scope = SharedEnums.Scope
M.SharedEnums = SharedEnums

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

-- Flat, scope-specific helpers (top-level for F12 navigation)



---@return PolicyBuilder
local function newBuilder(policyName, dependencies)
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
			pushPolicy(policyType, { 
				name = policyName,
				dependencies = dependencies,
				predicates = predicates, 
				handler = function(ctx) return { allow = true } end 
			})
			return builder
		end
		
		---Deny this policy from proceeding
		---Registers a policy that blocks the action when all predicates match
		---Example: policy.ForAlliedCommands.WhenGuard.Deny() - blocks guard commands to allied units
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Deny = function()
			pushPolicy(policyType, { 
				name = policyName,
				dependencies = dependencies,
				predicates = predicates, 
				handler = function(ctx) return { deny = true } end 
			})
			return builder
		end
		
		---Use custom handler for this policy
		---Registers a policy with custom logic when all predicates match
		---@param handlerFn function Custom handler function that receives context and returns { allow: boolean } or { deny: boolean } or { applyCommands: table }
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Use = function(handlerFn)
			pushPolicy(policyType, { 
				name = policyName,
				dependencies = dependencies,
				predicates = predicates, 
				handler = handlerFn 
			})
			return builder
		end
		
		return actions
	end

	-- Centralized scope predicates - single source of truth
	local ScopePredicates = {
		Allied = {
			Command = M.Predicates.Command.targetAllied,
			Transfer = { name = "areAlliedTeams", fn = function(ctx) return ctx.areAlliedTeams end }
		},
		Enemy = {
			Command = M.Predicates.Command.targetEnemy,
			Transfer = { name = "areEnemyTeams", fn = function(ctx) return not ctx.areAlliedTeams end }
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
		M.Predicates.Command.targetEnemy,
		M.Predicates.Command.targetHasAssist
	})
	
	---When command is Repair - applies to units being ordered to repair enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenRepair = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isRepair,
		M.Predicates.Command.targetEnemy,
		M.Predicates.Command.targetIsIncomplete
	})
	
	---When command is Reclaim - applies to units being ordered to reclaim enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenReclaim = createActionMethods(M.PolicyType.Command, {
		M.Predicates.Command.isReclaim,
		M.Predicates.Command.targetEnemy
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
		M.Predicates.TeamEvent.isPlayerAbandoned
	})

	---When a player reconnects to their team
	---@type ActionMethods
	builder.TeamEvents.PlayerReconnected = createActionMethods(M.PolicyType.TeamEvent, {
		M.Predicates.TeamEvent.isPlayerReconnected
	})

	return builder
end

---Register a new policy with the Team Transfer Framework
---@overload fun(policyName: string, registrationFn: fun(policy: PolicyBuilder))
---@overload fun(policyName: string, options: table, registrationFn: fun(policy: PolicyBuilder))
---@param policyName string A unique name for the policy for logging
---@param options table|fun(policy: PolicyBuilder) Either options table `{ dependsOn = string[] }` or the registration function
---@param registrationFn fun(policy: PolicyBuilder)? Function that configures the policy (if options is provided)
function M.RegisterPolicy(policyName, options, registrationFn)
	requireSyncedContext("RegisterPolicy")
	
	-- Handle function overloading: RegisterPolicy(name, fn) or RegisterPolicy(name, options, fn)
	if type(options) == "function" then
		registrationFn = options
		options = {}
	end
	options = options or {}
	local dependencies = options.dependsOn or {}

	-- Pass policy context directly to the builder - much cleaner than global overrides!
	local builder = newBuilder(policyName, dependencies)
	if registrationFn then
		registrationFn(builder)
	end
end

local legacyCallbacks = {
	onAllowResourceTransfer = {},
	onAllowUnitTransfer = {},
	onAllowCommand = {},
}
function M.RegisterAllowResourceTransfer(fn) 
	requireSyncedContext("RegisterAllowResourceTransfer")
	legacyCallbacks.onAllowResourceTransfer[#legacyCallbacks.onAllowResourceTransfer + 1] = fn 
end
function M.RegisterAllowUnitTransfer(fn) 
	requireSyncedContext("RegisterAllowUnitTransfer")
	legacyCallbacks.onAllowUnitTransfer[#legacyCallbacks.onAllowUnitTransfer + 1] = fn 
end
function M.RegisterAllowCommand(fn) 
	requireSyncedContext("RegisterAllowCommand")
	legacyCallbacks.onAllowCommand[#legacyCallbacks.onAllowCommand + 1] = fn 
end

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
M.PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")

-- Inline sharing mode option check to avoid extra includes and improve discoverability
---Check if a modoption key is enabled in the current sharing mode and return its value
---@param modoptionKey string The modoption key to check
---@return boolean enabled True if the option is enabled in current mode
---@return any value The current value from Spring.GetModOptions()[modoptionKey] (may be nil)
function M.IsSharingOption(modoptionKey)
	return sharingModeUtils.isOptionEnabledInCurrentMode(modoptionKey), modOpts[modoptionKey]
end

---Query the pipeline for current team state (no actual transfer, just state evaluation)
---@param senderTeamID number
---@param policyType string "ResourceTransfer" or "UnitTransfer"
---@return table? exposeData The expose data from pipeline evaluation, or nil if not allowed
M.QueryTeamState = function(senderTeamID, policyType)
	requireSyncedContext("QueryTeamState")
	
	-- Use the pipeline instance that's already loaded (avoid circular dependency)
	if not _G.TeamTransferPipeline then
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Pipeline not yet available for QueryTeamState")
		return nil
	end
	
	-- Use Pipeline's cached expose query
	local exposeData = _G.TeamTransferPipeline.QueryExpose(policyType, senderTeamID)
	
	-- Send expose data to widgets via sync action
	if exposeData then
		-- Send to widgets for their cache
		if gadgetHandler and gadgetHandler.SyncAction then
			gadgetHandler:SyncAction("TeamTransferExposeUpdate", senderTeamID, exposeData)
		end
		
		return exposeData
	end
	
	return nil
end

---Manual command to initialize team transfer cache (for debugging)
---@param teamID number? Optional specific team ID, or nil for all teams
M.InitializeCache = function(teamID)
	requireSyncedContext("InitializeCache")
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Manual cache initialization requested for team: " .. tostring(teamID or "ALL"))
	
	local teamsToUpdate = {}
	if teamID then
		teamsToUpdate = {teamID}
	else
		teamsToUpdate = Spring.GetTeamList()
	end
	
	for _, team in ipairs(teamsToUpdate) do
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Initializing cache for team " .. team)
		
		-- Query both resource and unit transfer states
		local resourceResult = M.QueryTeamState(team, M.PolicyType.ResourceTransfer)
		local unitResult = M.QueryTeamState(team, M.PolicyType.UnitTransfer)
		
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Team " .. team .. " - Resource result: " .. tostring(resourceResult ~= nil) .. ", Unit result: " .. tostring(unitResult ~= nil))
	end
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Manual cache initialization completed")
end

---@return TeamTransferAPI
return M
