-- Pipeline Hook System for Team Transfer Policies
-- Allows policies to register lifecycle hooks for complete self-containment

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local M = {}

-- Ensure policy hooks only run in synced context
local function requireSyncedContext(functionName)
	if gadgetHandler and not gadgetHandler:IsSyncedCode() then
		error("PolicyHooks." .. functionName .. " can only be called from synced context (gadgets), not unsynced context (widgets)")
	end
end

-- Hook registries
local hooks = {
	initialize = {},     -- RegisterInitialize: Run during gadget initialization
	preProcess = {},     -- RegisterPreProcess: Run before policy evaluation (context setup)
	postProcess = {      -- RegisterPostProcess: Run after policy evaluation (cleanup/state updates)
		[SharedEnums.TransferCategory.MetalTransfer] = {},     -- Hooks specific to metal transfer results
		[SharedEnums.TransferCategory.EnergyTransfer] = {},    -- Hooks specific to energy transfer results
		[SharedEnums.TransferCategory.UnitTransfer] = {},      -- Hooks specific to unit transfer results
		[SharedEnums.TransferCategory.CommandValidation] = {}, -- Hooks specific to command validation results
		[SharedEnums.TransferCategory.TeamEvents] = {},        -- Hooks specific to team event results
	},
	postTransfer = {},   -- RegisterPostTransfer: Run after successful transfers
	validators = {},     -- RegisterValidator: Runtime validation with strongly-typed access
	gameFrame = {},      -- RegisterGameFrame: Run during GameFrame callin
	playerEvent = {},    -- RegisterPlayerEvent: Run on player add/remove/change
}

-- Register a hook function for a specific lifecycle event
function M.RegisterInitialize(fn)
	requireSyncedContext("RegisterInitialize")
	hooks.initialize[#hooks.initialize + 1] = fn
end

function M.RegisterPreProcess(fn)
	requireSyncedContext("RegisterPreProcess")
	hooks.preProcess[#hooks.preProcess + 1] = fn
end

function M.RegisterPostProcess(policyType, fn)
	requireSyncedContext("RegisterPostProcess")
	
	-- Support both old (fn) and new (policyType, fn) signatures for backward compatibility
	if type(policyType) == "function" then
		-- Old signature: RegisterPostProcess(fn) - register for all policy types
		fn = policyType
		for _, typeHooks in pairs(hooks.postProcess) do
			typeHooks[#typeHooks + 1] = fn
		end
	else
		-- New signature: RegisterPostProcess(policyType, fn) - register for specific policy type
		if not hooks.postProcess[policyType] then
			error("Invalid policy type: " .. tostring(policyType))
		end
		hooks.postProcess[policyType][#hooks.postProcess[policyType] + 1] = fn
	end
end

function M.RegisterGameFrame(fn)
	requireSyncedContext("RegisterGameFrame")
	hooks.gameFrame[#hooks.gameFrame + 1] = fn
end

function M.RegisterPlayerEvent(fn)
	requireSyncedContext("RegisterPlayerEvent")
	hooks.playerEvent[#hooks.playerEvent + 1] = fn
end

-- Execute all hooks of a given type
function M.RunInitialize()
	for i = 1, #hooks.initialize do
		hooks.initialize[i]()
	end
end

function M.RunPreProcess(ctx)
	for i = 1, #hooks.preProcess do
		hooks.preProcess[i](ctx)
	end
	return ctx
end

function M.RunPostProcess(ctx, result)
	-- Run policy-type specific hooks
	local policyType = ctx.type
	if hooks.postProcess[policyType] then
		for i = 1, #hooks.postProcess[policyType] do
			hooks.postProcess[policyType][i](ctx, result)
		end
	end
end

function M.RunGameFrame(gameFrame)
	for i = 1, #hooks.gameFrame do
		hooks.gameFrame[i](gameFrame)
	end
end

function M.RunPlayerEvent(eventType, playerID, teamID)
	for i = 1, #hooks.playerEvent do
		hooks.playerEvent[i](eventType, playerID, teamID)
	end
end

-- Register a runtime validator with strongly-typed access to transfer results
-- DEPRECATED: Use category-specific RegisterXXXValidator functions instead
function M.RegisterValidator(config, validatorFn)
	requireSyncedContext("RegisterValidator")
	
	-- Support both old (fn) and new (config, fn) signatures
	if type(config) == "function" then
		validatorFn = config
		config = {}
	end
	
	hooks.validators[#hooks.validators + 1] = {
		dependsOn = config.dependsOn or {},
		validator = validatorFn
	}
end

-- Category-Specific Validator Registration Functions with Strong Typing

---Register a metal transfer validator with strongly-typed access to metal transfer results
---@see luaui/types/team_transfer.lua M.RegisterMetalTransferValidator
---@param validatorFn MetalTransferValidator The validator function
function M.RegisterMetalTransferValidator(validatorFn)
	requireSyncedContext("RegisterMetalTransferValidator")
	
	hooks.validators[#hooks.validators + 1] = {
		category = SharedEnums.TransferCategory.MetalTransfer,
		validator = validatorFn
	}
end

---Register an energy transfer validator with strongly-typed access to energy transfer results
---@see luaui/types/team_transfer.lua M.RegisterEnergyTransferValidator
---@param validatorFn EnergyTransferValidator The validator function
function M.RegisterEnergyTransferValidator(validatorFn)
	requireSyncedContext("RegisterEnergyTransferValidator")
	
	hooks.validators[#hooks.validators + 1] = {
		category = SharedEnums.TransferCategory.EnergyTransfer,
		validator = validatorFn
	}
end

---Register a unit transfer validator with strongly-typed access to unit transfer results
---@see luaui/types/team_transfer.lua M.RegisterUnitTransferValidator
---@param validatorFn UnitTransferValidator The validator function
function M.RegisterUnitTransferValidator(validatorFn)
	requireSyncedContext("RegisterUnitTransferValidator")
	
	hooks.validators[#hooks.validators + 1] = {
		category = SharedEnums.TransferCategory.UnitTransfer,
		validator = validatorFn
	}
end

-- Run validators with strongly-typed context
function M.RunValidators(ctx, exposeResults)
	-- Create strongly-typed validator context
	local validatorCtx = {
		-- Copy base context
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		amount = ctx.amount,
		resource = ctx.resource,
		areAlliedTeams = ctx.areAlliedTeams,
		gameFrame = ctx.gameFrame,
		isCheatingEnabled = ctx.isCheatingEnabled,
		
		-- Strongly-typed access to transfer results
		MetalTransfer = exposeResults[SharedEnums.TransferCategory.MetalTransfer] or {},
		EnergyTransfer = exposeResults[SharedEnums.TransferCategory.EnergyTransfer] or {},
		UnitTransfer = exposeResults[SharedEnums.TransferCategory.UnitTransfer] or {},
	}
	
	-- Run category-specific validators and legacy validators
	for i = 1, #hooks.validators do
		local entry = hooks.validators[i]
		
		-- If validator has a category, only run it for matching contexts
		if entry.category then
			if ctx.type == entry.category then
				-- Provide category-specific strongly-typed expose results
				local categoryResults = {}
				if entry.category == SharedEnums.TransferCategory.MetalTransfer then
					categoryResults = exposeResults[SharedEnums.TransferCategory.MetalTransfer] or {}
				elseif entry.category == SharedEnums.TransferCategory.EnergyTransfer then
					categoryResults = exposeResults[SharedEnums.TransferCategory.EnergyTransfer] or {}
				elseif entry.category == SharedEnums.TransferCategory.UnitTransfer then
					categoryResults = exposeResults[SharedEnums.TransferCategory.UnitTransfer] or {}
				elseif entry.category == SharedEnums.TransferCategory.CommandValidation then
					categoryResults = exposeResults[SharedEnums.TransferCategory.CommandValidation] or {}
				elseif entry.category == SharedEnums.TransferCategory.TeamEvents then
					categoryResults = exposeResults[SharedEnums.TransferCategory.TeamEvents] or {}
				end
				
				-- Run category-specific validator with strongly-typed results
				local isValid, reason, suggestedAmount = entry.validator(validatorCtx, categoryResults)
				if not isValid then
					return false, reason, suggestedAmount
				end
			end
		else
			-- Legacy validator - run with full expose results
			local isValid, reason, suggestedAmount = entry.validator(validatorCtx, exposeResults)
			if not isValid then
				return false, reason, suggestedAmount
			end
		end
	end
	
	return true
end

-- Register a post-transfer hook (runs after successful transfers)
function M.RegisterPostTransfer(fn)
	requireSyncedContext("RegisterPostTransfer")
	hooks.postTransfer[#hooks.postTransfer + 1] = fn
end

-- Notify all post-transfer hooks
function M.NotifyPostTransfer(transferData)
	for i = 1, #hooks.postTransfer do
		hooks.postTransfer[i](transferData)
	end
end

-- Specialized post-transfer hooks with strong typing by resource
function M.RegisterAfterMetalTransfer(fn)
	requireSyncedContext("RegisterAfterMetalTransfer")
	hooks.postTransfer[#hooks.postTransfer + 1] = function(transferData)
		if transferData and transferData.resource == SharedEnums.ResourceType.METAL then
			fn(transferData)
		end
	end
end

function M.RegisterAfterEnergyTransfer(fn)
	requireSyncedContext("RegisterAfterEnergyTransfer")
	hooks.postTransfer[#hooks.postTransfer + 1] = function(transferData)
		if transferData and transferData.resource == SharedEnums.ResourceType.ENERGY then
			fn(transferData)
		end
	end
end

return M
