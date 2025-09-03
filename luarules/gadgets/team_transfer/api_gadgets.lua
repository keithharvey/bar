---@meta
---@module "luarules/gadgets/team_transfer/api_gadgets"

---@load-file luaui/types/team_transfer.lua

---@class TeamTransferAPI
local M = {}

-- Shared logging utility
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
Logger.SetLogMode("NONE")  -- Set to "NONE" to disable all logging, "ERROR" for errors only, "DEBUG" for all

local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

-- Include policy hooks for RegisterInitialize and other hook methods
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")

-- Store SendToUnsynced function reference passed from main gadget
local _sendToUnsynced

-- Function to set the SendToUnsynced function reference from main gadget
function M.SetSendToUnsynced(sendFunc)
	_sendToUnsynced = sendFunc
	LogDebug(string.format("[API_GADGETS] SendToUnsynced function set successfully: %s", tostring(sendFunc ~= nil)))
end

-- Team Transfer Gadget API Initialization Logging
LogDebug("[API_GADGETS] Starting api_gadgets.lua initialization")

-- Ensure policy pipeline only runs in synced context
local function requireSyncedContext(functionName)
	LogDebug("[API_GADGETS] Checking synced context for " .. functionName)
	local handler = _sendToUnsynced and gadgetHandler or gadgetHandler
	if handler and not handler:IsSyncedCode() then
		local errorMsg = "TeamTransfer." .. functionName .. " can only be called from synced context (gadgets), not unsynced context (widgets)"
		LogError("[API_GADGETS] Context error: " .. errorMsg)
		error(errorMsg)
	end
	LogDebug("[API_GADGETS] Synced context check passed for " .. functionName)
end

LogDebug("[API_GADGETS] Including dependencies...")
local sharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")


local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")


local json = VFS.Include("common/luaUtilities/json.lua")


-- Helper function to get table keys (since Lua doesn't have table.keys)
local function tableKeys(t)
	if not t then return {} end
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, tostring(k))
	end
	return keys
end

local modOpts = Spring.GetModOptions()


-- Use shared enums for consistency across synced/unsynced contexts
M.TransferCategory = SharedEnums.TransferCategory
M.Policies = SharedEnums.Policies
M.Scope = SharedEnums.Scope
M.SharedEnums = SharedEnums


local policies = {
	[M.TransferCategory.MetalTransfer] = {},
	[M.TransferCategory.EnergyTransfer] = {},
	[M.TransferCategory.UnitTransfer] = {},
	[M.TransferCategory.CommandValidation] = {},
	[M.TransferCategory.TeamEvents] = {},
}

local function pushPolicy(policyType, entry)
	LogDebug("[API_GADGETS] Pushing policy to type " .. tostring(policyType) .. " - name: " .. tostring(entry.name))
	local list = policies[policyType]
	local oldCount = #list
	list[#list + 1] = entry
	LogDebug("[API_GADGETS] Policy added, count: " .. oldCount .. " -> " .. #list)
end

LogDebug("[API_GADGETS] Policy storage initialized")

-- Flat, scope-specific helpers (top-level for F12 navigation)



---@return PolicyBuilder
local function newBuilder(policyName, dependencies)
	LogDebug("[API_GADGETS] Creating policy builder for '" .. tostring(policyName) .. "' with " .. tostring(#(dependencies or {})) .. " dependencies")
	---@class PolicyBuilder
	local builder = {}

	-- Create the action methods that can be used at the end of chains
	---@class ActionMethods
	---@field Allow fun(): PolicyBuilder Allow this policy to proceed - permits the action when all predicates match
	---@field Deny fun(): PolicyBuilder Deny this policy from proceeding - blocks the action when all predicates match
	---@field Use fun(handlerFn: function): PolicyBuilder Use custom handler - run custom logic when all predicates match

	local function teamHasBuiltCategories(teamId, categories)
		local required = {}
		for i = 1, #categories do
			required[categories[i]] = true
		end
		local seen = {}
		local units = Spring.GetTeamUnits(teamId) or {}
		for i = 1, #units do
			local unitID = units[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID then
				local ud = UnitDefs[unitDefID]
				if ud and ud.name then
					local catName = BuildingCategoryDefinitions.unitCategories[ud.name:lower()]
					if catName and required[catName] then
						seen[catName] = true
					end
				end
			end
		end
		for cat, _ in pairs(required) do
			if not seen[cat] then
				return false
			end
		end
		return true
	end

	---@return ActionMethods
	local function createActionMethods(policyType, predicates, commandFlag)
		LogDebug("[API_GADGETS] Creating action methods for policy type " .. tostring(policyType) .. " with " .. tostring(#predicates) .. " predicates")
		local actions = {}

		---Allow this policy to proceed
		---Registers a policy that permits the action when all predicates match
		---Example: policy.ForAlliedCommands.WhenGuard.Allow() - allows guard commands to allied units
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Allow = function()
			LogDebug("[API_GADGETS] Policy '" .. policyName .. "' registered ALLOW action")
			if policyType == M.TransferCategory.CommandValidation and commandFlag then
				pushPolicy(policyType, {
					name = policyName,
					dependencies = dependencies,
					predicates = predicates,
					handler = function(ctx)
						local expose = {
							allowGuardCommands = ctx.defaultCommandValidation.allowGuardCommands,
							allowRepairCommands = ctx.defaultCommandValidation.allowRepairCommands,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = nil,
						}
						expose[commandFlag] = true
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
			else
				pushPolicy(policyType, {
					name = policyName,
					dependencies = dependencies,
					predicates = predicates,
					handler = function(ctx) return { allow = true } end
				})
			end
			return builder
		end

		---Deny this policy from proceeding
		---Registers a policy that blocks the action when all predicates match
		---Example: policy.ForAlliedCommands.WhenGuard.Deny() - blocks guard commands to allied units
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Deny = function()
			LogDebug("[API_GADGETS] Policy '" .. policyName .. "' registered DENY action")
			if policyType == M.TransferCategory.CommandValidation and commandFlag then
				pushPolicy(policyType, {
					name = policyName,
					dependencies = dependencies,
					predicates = predicates,
					handler = function(ctx)
						local expose = {
							allowGuardCommands = ctx.defaultCommandValidation.allowGuardCommands,
							allowRepairCommands = ctx.defaultCommandValidation.allowRepairCommands,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = "Blocked by policy: " .. tostring(policyName),
						}
						expose[commandFlag] = false
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
			else
				pushPolicy(policyType, {
					name = policyName,
					dependencies = dependencies,
					predicates = predicates,
					handler = function(ctx) return { deny = true } end
				})
			end
			return builder
		end

		---Use custom handler for this policy
		---Registers a policy with custom logic when all predicates match
		---@param handlerFn function Custom handler function that receives context and returns { allow: boolean } or { deny: boolean } or { applyCommands: table }
		---@return PolicyBuilder Returns the policy builder for chaining
		actions.Use = function(handlerFn)
			LogDebug("[API_GADGETS] Policy '" .. policyName .. "' registered USE action with custom handler")
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
	builder.ForAlliedCommands.WhenGuard = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isGuard,
		M.Predicates.Command.targetHasAssist
	}, "allowGuardCommands")
	
	---When command is Repair - applies to units being ordered to repair other units
	---Checks: command type is Repair AND target is damaged/incomplete
	---@type ActionMethods
	builder.ForAlliedCommands.WhenRepair = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isRepair,
		M.Predicates.Command.targetIsIncomplete
	}, "allowRepairCommands")
	
	---When command is Reclaim - applies to units being ordered to reclaim other units/features
	---Checks: command type is Reclaim
	---@type ActionMethods
	builder.ForAlliedCommands.WhenReclaim = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isReclaim
	}, "allowReclaimCommands")
	
	---For enemy command-based policies - Guard commands targeting enemy units
	---@type table
	builder.ForEnemyCommands = {}
	
	---When command is Guard - applies to units being ordered to guard enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenGuard = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isGuard,
		M.Predicates.Command.targetEnemy,
		M.Predicates.Command.targetHasAssist
	}, "allowGuardCommands")
	
	---When command is Repair - applies to units being ordered to repair enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenRepair = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isRepair,
		M.Predicates.Command.targetEnemy,
		M.Predicates.Command.targetIsIncomplete
	}, "allowRepairCommands")
	
	---When command is Reclaim - applies to units being ordered to reclaim enemy units
	---@type ActionMethods
	builder.ForEnemyCommands.WhenReclaim = createActionMethods(M.TransferCategory.CommandValidation, {
		M.Predicates.Command.isReclaim,
		M.Predicates.Command.targetEnemy
	}, "allowReclaimCommands")
	
	---For allied metal transfer policies - metal transfers to allied teams
	---@type ActionMethods
	builder.ForAlliedMetalTransfers = createActionMethods(M.TransferCategory.MetalTransfer, {
		ScopePredicates.Allied.Transfer
	})
	
	---For enemy metal transfer policies - metal transfers to enemy teams
	---@type ActionMethods
	builder.ForEnemyMetalTransfers = createActionMethods(M.TransferCategory.MetalTransfer, {
		ScopePredicates.Enemy.Transfer
	})
	
	---For allied energy transfer policies - energy transfers to allied teams
	---@type ActionMethods
	builder.ForAlliedEnergyTransfers = createActionMethods(M.TransferCategory.EnergyTransfer, {
		ScopePredicates.Allied.Transfer
	})
	
	---For enemy energy transfer policies - energy transfers to enemy teams
	---@type ActionMethods
	builder.ForEnemyEnergyTransfers = createActionMethods(M.TransferCategory.EnergyTransfer, {
		ScopePredicates.Enemy.Transfer
	})
	
	---For allied unit transfer policies - unit sharing to allied teams
	---@type ActionMethods
	builder.ForAlliedUnitTransfers = createActionMethods(M.TransferCategory.UnitTransfer, {
		ScopePredicates.Allied.Transfer
	})
	
	---For enemy unit transfer policies - unit sharing to enemy teams
	---@type ActionMethods
	builder.ForEnemyUnitTransfers = createActionMethods(M.TransferCategory.UnitTransfer, {
		ScopePredicates.Enemy.Transfer
	})

	---For team event policies
	---@type table
	builder.TeamEvents = {}

	---When a player abandons their team (disconnects or goes spec)
	---@type ActionMethods
	builder.TeamEvents.PlayerAbandoned = createActionMethods(M.TransferCategory.TeamEvents, {
		M.Predicates.TeamEvent.isPlayerAbandoned
	})

	---When a player reconnects to their team
	---@type ActionMethods
	builder.TeamEvents.PlayerReconnected = createActionMethods(M.TransferCategory.TeamEvents, {
		M.Predicates.TeamEvent.isPlayerReconnected
	})

	-- Fluent predicate wrapper: AfterBuildingCategories with implied denial
	function builder.AfterBuildingCategories(...)
		local requiredCategories = { ... }
		local function built(ctx) return teamHasBuiltCategories(ctx.senderTeamId, requiredCategories) end
		local function notBuilt(ctx) return not built(ctx) end
		local reasonText
		do
			local names = {}
			for i = 1, #requiredCategories do names[#names+1] = tostring(requiredCategories[i]) end
			reasonText = (#names == 2 and ("Requires " .. names[1] .. " + " .. names[2])) or ("Requires " .. table.concat(names, ", "))
		end

		local scoped = {}
		scoped.ForAlliedCommands = {}
		-- Guard
		scoped.ForAlliedCommands.WhenGuard = {
			Allow = function()
				pushPolicy(M.TransferCategory.CommandValidation, {
					name = policyName,
					dependencies = dependencies,
					predicates = { M.Predicates.Command.isGuard, M.Predicates.Command.targetHasAssist, built },
					handler = function(ctx)
						local expose = {
							allowGuardCommands = true,
							allowRepairCommands = ctx.defaultCommandValidation.allowRepairCommands,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = nil,
						}
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
				pushPolicy(M.TransferCategory.CommandValidation, {
					name = policyName,
					dependencies = dependencies,
					predicates = { M.Predicates.Command.isGuard, M.Predicates.Command.targetHasAssist, notBuilt },
					handler = function(ctx)
						local expose = {
							allowGuardCommands = false,
							allowRepairCommands = ctx.defaultCommandValidation.allowRepairCommands,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = reasonText,
						}
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
				return builder
			end
		}
		-- Repair
		scoped.ForAlliedCommands.WhenRepair = {
			Allow = function()
				pushPolicy(M.TransferCategory.CommandValidation, {
					name = policyName,
					dependencies = dependencies,
					predicates = { M.Predicates.Command.isRepair, M.Predicates.Command.targetIsIncomplete, built },
					handler = function(ctx)
						local expose = {
							allowGuardCommands = ctx.defaultCommandValidation.allowGuardCommands,
							allowRepairCommands = true,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = nil,
						}
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
				pushPolicy(M.TransferCategory.CommandValidation, {
					name = policyName,
					dependencies = dependencies,
					predicates = { M.Predicates.Command.isRepair, M.Predicates.Command.targetIsIncomplete, notBuilt },
					handler = function(ctx)
						local expose = {
							allowGuardCommands = ctx.defaultCommandValidation.allowGuardCommands,
							allowRepairCommands = false,
							allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
							blockReason = reasonText,
						}
						return { expose = { [M.TransferCategory.CommandValidation] = expose } }
					end
				})
				return builder
			end
		}
		-- Unit transfers
		scoped.ForAlliedUnitTransfers = {
			Allow = function()
				pushPolicy(M.TransferCategory.UnitTransfer, {
					name = policyName,
					dependencies = dependencies,
					predicates = { ScopePredicates.Allied.Transfer, built },
					handler = function(ctx)
						return { expose = { [M.TransferCategory.UnitTransfer] = {
							canShareUnits = true,
							blockReason = nil,
							takeBypass = ctx.defaultUnitTransfer.takeBypass,
							allowedUnits = {},
						} } }
					end
				})
				pushPolicy(M.TransferCategory.UnitTransfer, {
					name = policyName,
					dependencies = dependencies,
					predicates = { ScopePredicates.Allied.Transfer, notBuilt },
					handler = function(ctx)
						return { expose = { [M.TransferCategory.UnitTransfer] = {
							canShareUnits = false,
							blockReason = reasonText,
							takeBypass = ctx.defaultUnitTransfer.takeBypass,
							allowedUnits = {},
						} } }
					end
				})
				return builder
			end
		}

		return scoped
	end

	return builder
end

---Register a new policy with the Team Transfer Framework
---@overload fun(policyName: string, registrationFn: fun(policy: PolicyBuilder))
---@overload fun(policyName: string, options: table, registrationFn: fun(policy: PolicyBuilder))
---@param policyName string A unique name for the policy for logging
---@param options table|fun(policy: PolicyBuilder) Either options table `{ dependsOn = string[] }` or the registration function
---@param registrationFn fun(policy: PolicyBuilder)? Function that configures the policy (if options is provided)
function M.RegisterPolicy(policyName, options, registrationFn)
	LogDebug("[API_GADGETS] RegisterPolicy called for '" .. tostring(policyName) .. "'")
	requireSyncedContext("RegisterPolicy")

	-- Handle function overloading: RegisterPolicy(name, fn) or RegisterPolicy(name, options, fn)
	if type(options) == "function" then
		LogDebug("[API_GADGETS] Function overloading detected - options is function")
		registrationFn = options
		options = {}
	end
	options = options or {}
	local dependencies = options.dependsOn or {}

	LogDebug("[API_GADGETS] Creating builder for '" .. policyName .. "' with " .. #dependencies .. " dependencies")

	-- Pass policy context directly to the builder - much cleaner than global overrides!
	local builder = newBuilder(policyName, dependencies)
	if registrationFn then
		LogDebug("[API_GADGETS] Calling registration function for '" .. policyName .. "'")
		registrationFn(builder)
		LogDebug("[API_GADGETS] Registration function completed for '" .. policyName .. "'")
	else
		LogDebug("[API_GADGETS] No registration function provided for '" .. policyName .. "'")
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
	return _G.TeamTransferPipeline
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
---@param policyType string "MetalTransfer", "EnergyTransfer", or "UnitTransfer"
---@return table? exposeData The expose data from pipeline evaluation, or nil if not allowed
M.QueryTeamState = function(senderTeamID, policyType)
	requireSyncedContext("QueryTeamState")

	-- Validate inputs
	if not senderTeamID or senderTeamID < 0 then
		LogError("[API_GADGETS] QueryTeamState called with invalid senderTeamID: " .. tostring(senderTeamID))
		return nil
	end

	if not policyType then
		LogError("[API_GADGETS] QueryTeamState called with invalid policyType: " .. tostring(policyType))
		return nil
	end

	LogDebug("[API_GADGETS] QueryTeamState called for team " .. senderTeamID .. " with policy type " .. tostring(policyType))

	-- Use the pipeline instance that's already loaded (avoid circular dependency)
	if not _G.TeamTransferPipeline then
		LogError("[API_GADGETS] Pipeline not yet available for QueryTeamState")
		return nil
	end

	-- Use Pipeline's cached expose query
	local exposeData = _G.TeamTransferPipeline.QueryExpose(policyType, senderTeamID)
	LogInfo(string.format("[API_GADGETS] QueryExpose returned for team %d, policyType %s: %s", 
		senderTeamID, policyType, tostring(exposeData ~= nil)))

	-- Send expose data to widgets via sync action
	if exposeData then
		-- Wrap the data with the appropriate camelCase key for widget compatibility
		local widgetData = {}
		if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
			widgetData.ResourceTransfer = exposeData
		elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
			widgetData.UnitTransfer = exposeData
		else
			-- For other policy types, use the raw data
			widgetData = exposeData
		end

		-- Send to widgets for their cache
		LogInfo(string.format("[API_GADGETS] Sending expose data to widgets - senderTeamID=%d, policyType=%s, hasData=%s",
			senderTeamID, policyType, tostring(widgetData ~= nil)))
		if _sendToUnsynced then
			LogInfo(string.format("[API_GADGETS] Calling SendToUnsynced via stored function for team %d", senderTeamID))
			_sendToUnsynced("TeamTransferExposeUpdate", senderTeamID, widgetData)
			LogInfo(string.format("[API_GADGETS] SendToUnsynced call completed for senderTeamID %d", senderTeamID))
		else
			LogError("[API_GADGETS] ERROR: _sendToUnsynced is nil!")
		end

		return exposeData
	else
		LogInfo(string.format("[API_GADGETS] No expose data to send for team %d, policyType %s", senderTeamID, policyType))
	end

	return nil
end

---Query the pipeline for current team state between specific team pairs (for cache initialization)
---@param senderTeamID number
---@param receiverTeamID number
---@param policyType string "MetalTransfer", "EnergyTransfer", or "UnitTransfer"
---@return table? exposeData The expose data from pipeline evaluation, or nil if not allowed
M.QueryTeamStateForPair = function(senderTeamID, receiverTeamID, policyType)
	requireSyncedContext("QueryTeamStateForPair")

	-- Validate inputs
	if not senderTeamID or senderTeamID < 0 then
		LogError("[API_GADGETS] QueryTeamStateForPair called with invalid senderTeamID: " .. tostring(senderTeamID))
		return nil
	end

	if not receiverTeamID or receiverTeamID < 0 then
		LogError("[API_GADGETS] QueryTeamStateForPair called with invalid receiverTeamID: " .. tostring(receiverTeamID))
		return nil
	end

	if not policyType then
		LogError("[API_GADGETS] QueryTeamStateForPair called with invalid policyType: " .. tostring(policyType))
		return nil
	end

	LogInfo("[API_GADGETS] QueryTeamStateForPair called for " .. senderTeamID .. "->" .. receiverTeamID .. " with policy type " .. tostring(policyType))

	-- Use the pipeline instance that's already loaded
	if not _G.TeamTransferPipeline then
		LogError("[API_GADGETS] Pipeline not yet available for QueryTeamStateForPair")
		return nil
	end

	-- Determine scope based on team alliance status
	local scope = SharedEnums.Scope.Enemy
	if Spring.AreTeamsAllied(senderTeamID, receiverTeamID) then
		scope = SharedEnums.Scope.Allied
	end

	-- Use Pipeline's cached expose query for team pairs
	local exposeData = _G.TeamTransferPipeline.QueryExposeByPredicates(scope, policyType, senderTeamID, receiverTeamID)

	LogInfo(string.format("[API_GADGETS] QueryExposeByPredicates result - sender=%d, receiver=%d, policy=%s, result=%s",
		senderTeamID, receiverTeamID, tostring(policyType), tostring(exposeData ~= nil)))

	-- Send expose data to widgets via sync action
	if exposeData then
		LogDebug(string.format("[API_GADGETS] ExposeData keys: %s", exposeData and table.concat(tableKeys(exposeData), ", ") or "none"))

		-- Wrap the data with the appropriate camelCase key for widget compatibility
		local widgetData = {}
		if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
			widgetData.ResourceTransfer = exposeData
			LogDebug("[API_GADGETS] Wrapped as ResourceTransfer")
		elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
			widgetData.UnitTransfer = exposeData
			LogDebug("[API_GADGETS] Wrapped as UnitTransfer")
		else
			-- For other policy types, use the raw data
			widgetData = exposeData
			LogDebug("[API_GADGETS] Using raw data (other policy type)")
		end

		LogDebug(string.format("[API_GADGETS] WidgetData keys: %s", widgetData and table.concat(tableKeys(widgetData), ", ") or "none"))
		if _sendToUnsynced then
			LogInfo(string.format("[API_GADGETS] Calling SendToUnsynced via stored function for team %d", senderTeamID))
			_sendToUnsynced("TeamTransferExposeUpdate", receiverTeamID, widgetData)
			LogInfo(string.format("[API_GADGETS] SendToUnsynced call completed for receiverTeamID %d", receiverTeamID))
		else
			LogError("[API_GADGETS] ERROR: _sendToUnsynced is nil!")
		end

		return exposeData
	end

	return nil
end

---Manual command to initialize team transfer cache (for debugging)
---@param teamID number? Optional specific team ID, or nil for all teams
M.InitializeCache = function(teamID)
	LogError("[API_GADGETS] Manual cache initialization requested for team: " .. tostring(teamID or "ALL"))
	requireSyncedContext("InitializeCache")

	-- Only initialize cache for the local player's team sharing TO other teams
	-- In synced context, we need to initialize for all teams since we don't know which is "local"
	local allTeams = Spring.GetTeamList()
	
	if teamID then
		-- Initialize for specific team only
		LogError(string.format("[API_GADGETS] CACHE DEBUG - InitializeCache for specific team %d sharing to teams: [%s]", 
			teamID, table.concat(allTeams, ", ")))
		local myTeamID = teamID
	else
		-- Initialize for all teams as senders (but optimized to skip self-transfers)
		LogError(string.format("[API_GADGETS] CACHE DEBUG - InitializeCache for ALL teams sharing to teams: [%s]", 
			table.concat(allTeams, ", ")))
		
		-- Process each team as a potential sender
		for _, senderTeam in ipairs(allTeams) do
			if senderTeam and senderTeam >= 0 then
				LogDebug("[API_GADGETS] Initializing cache for sender team " .. senderTeam)
				
				-- Only generate cache entries for "sender team → other teams" (skip self-transfers)
				for _, receiverTeam in ipairs(allTeams) do
					if receiverTeam and receiverTeam >= 0 and receiverTeam ~= senderTeam then
						LogDebug("[API_GADGETS] Initializing cache for " .. senderTeam .. " -> " .. receiverTeam)

						-- Query metal, energy, and unit transfer states for this team pair
						local metalResult = M.QueryTeamStateForPair(senderTeam, receiverTeam, M.TransferCategory.MetalTransfer)
						local energyResult = M.QueryTeamStateForPair(senderTeam, receiverTeam, M.TransferCategory.EnergyTransfer)
						local unitResult = M.QueryTeamStateForPair(senderTeam, receiverTeam, M.TransferCategory.UnitTransfer)

						LogDebug("[API_GADGETS] Team pair " .. senderTeam .. "->" .. receiverTeam .. " - Metal result: " .. tostring(metalResult ~= nil) .. ", Energy result: " .. tostring(energyResult ~= nil) .. ", Unit result: " .. tostring(unitResult ~= nil))
					elseif receiverTeam == senderTeam then
						LogDebug("[API_GADGETS] Skipping self-transfer cache for " .. senderTeam .. " -> " .. receiverTeam)
					end
				end
			end
		end
		
		LogDebug("[API_GADGETS] Manual cache initialization completed for all teams")
		return
	end

	local myTeamID = teamID

	-- Only generate cache entries for "my team → other teams" (skip self-transfers)
	for _, receiverTeam in ipairs(allTeams) do
		if receiverTeam and receiverTeam >= 0 and receiverTeam ~= myTeamID then
			LogDebug("[API_GADGETS] Initializing cache for " .. myTeamID .. " -> " .. receiverTeam)

			-- Query metal, energy, and unit transfer states for this team pair
			local metalResult = M.QueryTeamStateForPair(myTeamID, receiverTeam, M.TransferCategory.MetalTransfer)
			local energyResult = M.QueryTeamStateForPair(myTeamID, receiverTeam, M.TransferCategory.EnergyTransfer)
			local unitResult = M.QueryTeamStateForPair(myTeamID, receiverTeam, M.TransferCategory.UnitTransfer)

			LogDebug("[API_GADGETS] Team pair " .. myTeamID .. "->" .. receiverTeam .. " - Metal result: " .. tostring(metalResult ~= nil) .. ", Energy result: " .. tostring(energyResult ~= nil) .. ", Unit result: " .. tostring(unitResult ~= nil))
		elseif receiverTeam == myTeamID then
			LogDebug("[API_GADGETS] Skipping self-transfer cache for " .. myTeamID .. " -> " .. receiverTeam)
		else
			LogError("[API_GADGETS] Skipping cache initialization for invalid receiver team: " .. tostring(receiverTeam))
		end
	end

	LogDebug("[API_GADGETS] Manual cache initialization completed for local team " .. myTeamID)
end

-- Manual test function to send dummy data to unsynced side
function M.TestSendToUnsynced()
	LogError("[API_GADGETS] MANUAL TEST - Sending dummy data to unsynced side")
	
	-- Create dummy expose data for testing
	local testData = {
		ResourceTransfer = {
			metal = { canShareMetal = true, maxMetalShareAmount = 1000, blockReason = nil },
			energy = { canShareEnergy = true, maxEnergyShareAmount = 2000, blockReason = nil }
		},
		UnitTransfer = {
			canShareUnits = true,
			blockReason = nil
		}
	}
	
	-- Send test data for team 3 (the team the GUI is querying)
	if _sendToUnsynced then
		LogError("[API_GADGETS] MANUAL TEST - Sending test data for team 3")
		_sendToUnsynced("TeamTransferExposeUpdate", 3, testData)
		LogError("[API_GADGETS] MANUAL TEST - Test data sent")
	else
		LogError("[API_GADGETS] MANUAL TEST - SendToUnsynced not available")
	end
end

-- Utility function for debugging
local function tableKeys(t)
	if not t then return {} end
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, tostring(k))
	end
	return keys
end

-- Core Spring gadget callback methods that delegate to the policy system
function M.AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- Commands are generally allowed unless policies specifically block them
	-- Policies can register hooks to override this behavior
	return true
end

function M.AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
	-- Use cached expose data from previous cache initialization
	LogDebug(string.format("[API_GADGETS] AllowResourceTransfer called - %d->%d, type=%s, amount=%s", 
		oldTeamID, newTeamID, tostring(resourceType), tostring(amount)))
	
	-- Look up cached expose data for this team pair based on resource type
	local transferCategory = (resourceType == "metal") and M.TransferCategory.MetalTransfer or M.TransferCategory.EnergyTransfer
	local exposeData = M.QueryTeamStateForPair(oldTeamID, newTeamID, transferCategory)
	if exposeData then
		if resourceType == "metal" and exposeData.metal then
			LogDebug(string.format("[API_GADGETS] AllowResourceTransfer - metal policy: %s", tostring(exposeData.metal.canShareMetal)))
			return exposeData.metal.canShareMetal
		elseif resourceType == "energy" and exposeData.energy then
			LogDebug(string.format("[API_GADGETS] AllowResourceTransfer - energy policy: %s", tostring(exposeData.energy.canShareEnergy)))
			return exposeData.energy.canShareEnergy
		end
	end
	
	-- Default to allow if no cached policy data available
	LogDebug("[API_GADGETS] AllowResourceTransfer - no cached data, defaulting to allow")
	return true
end

function M.AllowUnitTransfer(unitID, unitDefID, oldTeamID, newTeamID, capture)
	LogDebug(string.format("[API_GADGETS] AllowUnitTransfer called - unitID=%s, %d->%d, capture=%s", 
		tostring(unitID), oldTeamID, newTeamID, tostring(capture)))
	
	if capture then
		return true  -- Captures are always allowed
	end
	
	-- Use pipeline validation which gets expose data and runs validators
	return _G.TeamTransferPipeline.ValidateUnitTransfer(oldTeamID, newTeamID, unitID, unitDefID)
end

-- Expose all policy hook methods automatically via iteration
for methodName, methodFunc in pairs(PolicyHooks) do
	if type(methodFunc) == "function" then
		M[methodName] = methodFunc
		LogDebug("[API_GADGETS] Exposed PolicyHooks method: " .. methodName)
	end
end

-- Explicitly expose the category-specific validator registration functions
M.RegisterMetalTransferValidator = PolicyHooks.RegisterMetalTransferValidator
M.RegisterEnergyTransferValidator = PolicyHooks.RegisterEnergyTransferValidator
M.RegisterUnitTransferValidator = PolicyHooks.RegisterUnitTransferValidator

LogInfo("[API_GADGETS] api_gadgets.lua initialization completed successfully")
LogDebug("[API_GADGETS] Final policy counts:")
for policyType, policyList in pairs(policies) do
	LogDebug("[API_GADGETS]   " .. tostring(policyType) .. ": " .. #policyList .. " policies")
end

---@return TeamTransferAPI
return M
