-- Pipeline Hook System for Team Transfer Policies
-- Allows policies to register lifecycle hooks for complete self-containment

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
		ResourceTransfer = {},  -- Hooks specific to resource transfer results
		UnitTransfer = {},      -- Hooks specific to unit transfer results
		Command = {},           -- Hooks specific to command results
		TeamEvent = {},         -- Hooks specific to team event results
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
	-- Run policy-type specific hooks with enhanced context
	local policyType = ctx.type
	if hooks.postProcess[policyType] then
		-- Create enhanced context for resource transfers
		local enhancedCtx = ctx
		if policyType == "ResourceTransfer" and result and result.applyTransfer then
			-- Automatically provide applyTransfer context for resource transfer hooks
			enhancedCtx = {}
			for k, v in pairs(ctx) do
				enhancedCtx[k] = v
			end
			enhancedCtx.applyTransfer = result.applyTransfer
		end
		
		for i = 1, #hooks.postProcess[policyType] do
			hooks.postProcess[policyType][i](enhancedCtx, result)
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

-- Run validators with strongly-typed context
function M.RunValidators(ctx, exposeResults)
	local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
	
	-- Create strongly-typed validator context
	local validatorCtx = {
		-- Copy base context
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		amount = ctx.amount,
		resource = ctx.resource,
		
		-- Strongly-typed access to transfer results
		MetalTransfer = exposeResults[SharedEnums.TransferCategory.METAL_TRANSFER] or {},
		EnergyTransfer = exposeResults[SharedEnums.TransferCategory.ENERGY_TRANSFER] or {},
		UnitTransfer = exposeResults[SharedEnums.TransferCategory.UNIT_TRANSFER] or {},
	}
	
	-- Run all validators
	for i = 1, #hooks.validators do
		local entry = hooks.validators[i]
		
		-- Check dependencies (simplified - just run all for now)
		local isValid, reason, suggestedAmount = entry.validator(validatorCtx, exposeResults)
		if not isValid then
			return false, reason, suggestedAmount
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

return M
