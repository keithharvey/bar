
local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local FluentPolicy = VFS.Include("luarules/gadgets/team_transfer/fluent_policy.lua")

-- Shared logging utility
-- Removed Logger dependencies - using Spring.Log directly

---@class TeamTransferPipeline
---@field springRepo table
---@field teamRepo table
---@field unitRepo table
---@field policyRepo table
local Pipeline = {}
Pipeline.__index = Pipeline

-- Track if deferred policies have been executed
local deferredPoliciesExecuted = false

---Create a new pipeline instance with proper service registry lookups
---@return TeamTransferPipeline
function Pipeline.new()
    local springRepo = ServiceRegistry.SpringRepository()
    local teamRepo = ServiceRegistry.TeamRepository()
    local unitRepo = ServiceRegistry.UnitRepository()
    local policyRepo = ServiceRegistry.PolicyRepository()

    -- Execute deferred policies on pipeline creation
    if FluentPolicy.HasDeferredPolicies() then
        local context = {
            Spring = _G.Spring,
            VFS = _G.VFS,
            UnitDefs = _G.UnitDefs,
            repositories = {
                SpringRepository = springRepo,
                TeamRepository = teamRepo,
                UnitRepository = unitRepo
            }
        }
        FluentPolicy.ExecuteDeferredPolicies(context)
    end

    local instance = setmetatable({
        springRepo = springRepo,
        teamRepo = teamRepo,
        unitRepo = unitRepo,
        policyRepo = policyRepo
    }, Pipeline)

    Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE] Pipeline instance created")
    return instance
end


-- PolicyRepository handles all policy access



-- Default Expose Data Calculation Functions
-- These provide strongly-typed default calculations that policies can use or override

---Calculate default metal transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultMetalTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultMetalTransferResult Default metal transfer calculations
local function calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
	-- Default to deny metal sharing - policies must explicitly allow it
	return {
		canShare = false,
		maxMetalShareAmount = 0,
		blockReason = "No policies allowed metal sharing",
		taxRate = 0,
		remainingTaxFreeAllowance = 0
	}
end

---Calculate default energy transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultEnergyTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultEnergyTransferResult Default energy transfer calculations
local function calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
	-- Default to deny energy sharing - policies must explicitly allow it
	return {
		canShare = false,
		maxEnergyShareAmount = 0,
		blockReason = "No policies allowed energy sharing",
		taxRate = 0
	}
end

---Calculate default unit transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultUnitTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param selectedUnitIDs number[]? Selected unit IDs for transfer
---@return DefaultUnitTransferResult Default unit transfer calculations
local function calculateDefaultUnitTransfer(senderTeamID, receiverTeamID, selectedUnitIDs)
	-- Default to deny unit sharing - policies must explicitly allow it
	return {
		canShareUnits = false,
		takeBypass = false,
		blockReason = "No policies allowed unit sharing"
	}
end

---Calculate default command validation data for pipeline context
---@see luaui/types/team_transfer.lua DefaultCommandValidationResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultCommandValidationResult Default command validation
local function calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
	-- Default to deny all commands - policies must explicitly allow them
	return {
		allowGuardCommands = false,
		allowRepairCommands = false,
		allowReclaimCommands = false,
		blockReason = "No policies allowed these commands"
	}
end

---Calculate default team events data for pipeline context
---@see luaui/types/team_transfer.lua DefaultTeamEventsResult
---@param teamID number The team ID affected by the event
---@return DefaultTeamEventsResult Default team event processing
local function calculateDefaultTeamEvents(teamID)
	---@type DefaultTeamEventsResult
	return {
		canProcessEvent = true -- Default: all events can be processed
	}
end

-- Build a common policy context used across pipeline entry points
-- predicateScope is optional; when provided, it determines areAlliedTeams
---@return TeamTransferPolicyContext
---Build policy context for evaluation
---@param self TeamTransferPipeline
---@param senderTeamID number
---@param receiverTeamID number
---@return TeamTransferPolicyContext
function Pipeline:buildPolicyContext(senderTeamID, receiverTeamID)
	local defaultMetalTransfer = calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
	local defaultEnergyTransfer = calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
	local defaultUnitTransfer = calculateDefaultUnitTransfer(senderTeamID, receiverTeamID)
	local defaultCommandValidation = calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
	local defaultTeamEvents = calculateDefaultTeamEvents(senderTeamID)

	local areAllied = self.teamRepo.AreAlliedTeams(senderTeamID, receiverTeamID)

	local senderResources = self.teamRepo.GetTeamResourcesData(senderTeamID)
	local receiverResources = self.teamRepo.GetTeamResourcesData(receiverTeamID)

	---@type TeamTransferPolicyContext
	local ctx = {
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		gameFrame = self.springRepo.GetGameFrame(),
		areAlliedTeams = areAllied,
		isCheatingEnabled = self.springRepo.IsCheatingEnabled(),
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
		resources = {
			sender = senderResources, receiver = receiverResources
		},
		repositories = {
			SpringRepository = self.springRepo,
			TeamRepository = self.teamRepo,
			UnitRepository = self.unitRepo
		}
	}

	if senderResources or receiverResources then
		ctx.resources = { sender = senderResources, receiver = receiverResources }
	end

	return ctx
end

-- Helper function to get table keys (since Lua doesn't have table.keys)
local function tableKeys(t)
	if not t then return {} end
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, tostring(k))
	end
	return keys
end

-- Pipeline introspection and logging functions
local PipelineLogger = {}

-- Analyze and log the current pipeline topology
function PipelineLogger.LogTopology()
	local TT = (GG and GG.TeamTransfer) or TeamTransfer
	-- Log policy types and their registered policies
	for policyType, policies in pairs(TT.GetPolicies()) do
		Spring.Log("[PIPELINE]", "DEBUG", string.format("Policy Type: %s (%d policies)", policyType, #policies))

		-- Sort policies by dependencies for display
		local sortedPolicies = topologicalSort(policies)
		for i, entry in ipairs(sortedPolicies) do
			local deps = entry.dependsOn and table.concat(entry.dependsOn, ", ") or "none"
			Spring.Log("[PIPELINE]", "DEBUG", string.format("  %d. %s (depends on: %s)", i, entry.name, deps))
		end
	end
end

-- Analyze and log the current cache state
function PipelineLogger.LogCacheState()
	Spring.Log("[PIPELINE]", "DEBUG", "=== Predicate Cache Analysis ===")

	local cacheCount = 0
	local cacheByFrame = {}
	local cacheByScope = {}
	local cacheByType = {}

	-- Analyze cache entries
	for cacheKey, cacheData in pairs(predicateExposeCache) do
		cacheCount = cacheCount + 1

		-- Parse cache key: "scope_policyType_senderID_receiverID_frame_..."
		local parts = {}
		for part in string.gmatch(cacheKey, "([^_]+)") do
			table.insert(parts, part)
		end

		if #parts >= 5 then
			local scope = parts[1]
			local policyType = parts[2]
			local frame = parts[5]

			cacheByFrame[frame] = (cacheByFrame[frame] or 0) + 1
			cacheByScope[scope] = (cacheByScope[scope] or 0) + 1
			cacheByType[policyType] = (cacheByType[policyType] or 0) + 1
		end
	end

	Spring.Log("[PIPELINE]", "INFO",string.format("Total cache entries: %d", cacheCount))

	-- Log cache distribution
	Spring.Log("[PIPELINE]", "INFO","Cache by scope:")
	for scope, count in pairs(cacheByScope) do
		Spring.Log("[PIPELINE]", "INFO",string.format("  %s: %d entries", scope, count))
	end

	Spring.Log("[PIPELINE]", "INFO","Cache by policy type:")
	for policyType, count in pairs(cacheByType) do
		Spring.Log("[PIPELINE]", "INFO",string.format("  %s: %d entries", policyType, count))
	end

	Spring.Log("[PIPELINE]", "INFO","Cache by frame:")
	for frame, count in pairs(cacheByFrame) do
		Spring.Log("[PIPELINE]", "INFO",string.format("  Frame %s: %d entries", frame, count))
	end
end

-- Analyze a specific cache entry in detail
function PipelineLogger.LogCacheEntry(predicateScope, policyType, senderTeamID, receiverTeamID)
	local springRepo = ServiceRegistry.SpringRepository()
	local gameFrame = springRepo.GetGameFrame()
	local cacheKey, senderResources, receiverResources = generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)

	Spring.Log("[PIPELINE]", "DEBUG", string.format("=== Cache Entry Analysis: %s ===", cacheKey))

	local cacheData = predicateExposeCache[cacheKey]
	if cacheData then
		Spring.Log("[PIPELINE]", "DEBUG", "Cache HIT - Entry exists")

		-- Log expose data structure
		if cacheData.metal then
			Spring.Log("[PIPELINE]", "DEBUG", string.format("Metal: canShare=%s, maxAmount=%.1f, blockReason=%s",
				tostring(cacheData.metal.canShareMetal), cacheData.metal.maxMetalShareAmount or 0, cacheData.metal.blockReason or "none"))
		end
		if cacheData.energy then
			Spring.Log("[PIPELINE]", "DEBUG", string.format("Energy: canShare=%s, maxAmount=%.1f, blockReason=%s",
				tostring(cacheData.energy.canShareEnergy), cacheData.energy.maxEnergyShareAmount or 0, cacheData.energy.blockReason or "none"))
		end
		if cacheData.canShareUnits ~= nil then
			Spring.Log("[PIPELINE]", "DEBUG", string.format("Units: canShare=%s, blockReason=%s",
				tostring(cacheData.canShareUnits), cacheData.blockReason or "none"))
		end
	else
		Spring.Log("[PIPELINE]", "DEBUG", "Cache MISS - Entry would be generated")

		-- Log the context that would be used
		Spring.Log("[PIPELINE]", "DEBUG", string.format("Context: %s %s transfer from team %d to team %d",
			predicateScope, policyType, senderTeamID, receiverTeamID))

		if senderResources and receiverResources then
			Spring.Log("[PIPELINE]", "DEBUG", string.format("Sender resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
				senderResources.metal.current, senderResources.metal.storage,
				senderResources.energy.current, senderResources.energy.storage))
			Spring.Log("[PIPELINE]", "DEBUG", string.format("Receiver resources: Metal=%.1f/%.1f (slider=%.2f), Energy=%.1f/%.1f (slider=%.2f)",
				receiverResources.metal.current, receiverResources.metal.storage, receiverResources.metal.shareSlider,
				receiverResources.energy.current, receiverResources.energy.storage, receiverResources.energy.shareSlider))
		end
	end
end

-- Generate a comprehensive pipeline report
function PipelineLogger.LogFullReport()
	Spring.Log("[PIPELINE]", "DEBUG", "=== COMPREHENSIVE TEAM TRANSFER TeamTransfer ===")
	local springRepo = ServiceRegistry.SpringRepository()
	Spring.Log("[PIPELINE]", "DEBUG", string.format("Generated at game frame: %d", springRepo.GetGameFrame()))

	PipelineLogger.LogTopology()
	Spring.Log("[PIPELINE]", "DEBUG", "")
	PipelineLogger.LogCacheState()

	Spring.Log("[PIPELINE]", "DEBUG", "=== END TeamTransfer ===")
end

local function isNonPlayerTeam(teamID)
	local teamRepo = ServiceRegistry.TeamRepository()
	local _, _, _, isAiTeam = teamRepo.GetTeamInfo(teamID)
	if isAiTeam then
		return true
	end
	return false
end

local function mergeExposeData(existing, incoming)
    if not existing then return incoming end
    if not incoming then return existing end
    local out = {}
    -- Copy existing
    for key, value in pairs(existing) do
        out[key] = value
    end
    -- Merge incoming
    for key, value in pairs(incoming) do
        if type(value) ~= "function" then
            local old = out[key]
            if type(value) == "table" and type(old) == "table" then
                -- Recursively merge tables
                out[key] = mergeExposeData(old, value)
            elseif key == "canShareMetal" or key == "canShareEnergy" or key == "canShareUnits"
                or key == "allowGuardCommands" or key == "allowRepairCommands" or key == "allowReclaimCommands" then
                out[key] = (old == nil) and value or (old and value)
            elseif key == "amountSendable" or key == "amountRemainingAllowance"
                or key == "maxMetalShareAmount" or key == "maxEnergyShareAmount" then
                if type(old) == "number" and type(value) == "number" then
                    out[key] = math.min(old, value)
                else
                    out[key] = value or old
                end
            elseif key == "_policyData" then
                out._policyData = out._policyData or {}
                for k2, v2 in pairs(value) do out._policyData[k2] = v2 end
            elseif key == "blockReason" then
                out.blockReason = out.blockReason or value
            else
                out[key] = value
            end
        end
    end
    return out
end

local function evaluatePolicy(policy, ctx)
	local preds = policy.predicates
	local ok = true
	for j = 1, #preds do
		local pred = preds[j]
		local predFn = type(pred) == "function" and pred or pred.fn
		if not predFn(ctx) then
			ok = false
			break
		end
	end

	if ok and policy.handler then
		local res = policy.handler(ctx)
		return true, res
	end
	return false, nil
end

local function evaluatePolicies(policyType, ctx)
	local TT = (GG and GG.TeamTransfer) or TeamTransfer
	local entries
	if TT and TT.GetPolicies then
		entries = TT.GetPolicies()[policyType]
	else
		entries = (FluentPolicy and FluentPolicy.GetPolicies and FluentPolicy.GetPolicies()[policyType]) or {}
	end


	if entries and #entries > 0 then
		for i, entry in ipairs(entries) do
			-- Policy found: " .. tostring(entry.name or "unnamed")
		end
	else
	end

	local out = {}
	if not entries then
		return out
	end

	for _, policy in ipairs(entries) do
		local ok, result = evaluatePolicy(policy, ctx)
		-- Only log resource transfer policy execution for debugging
		if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
		end
		
		if result and result.deny then
			return { deny = true }
		end
		if result and result.expose then
			out = mergeExposeData(out, result.expose)
		end
		if result and result.allow ~= nil then
			out.allow = out.allow and result.allow
		end
	end
	
	return out
end

---@see luaui/types/team_transfer.lua Pipeline.RunResourceTransfer
function Pipeline:RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	local resourceName = (resourceType == SharedEnums.ResourceType.METAL) and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
	local maxShare = 0
	local receiverCur = 0
	if resourceName == SharedEnums.ResourceType.METAL or resourceName == SharedEnums.ResourceType.ENERGY then
		maxShare, receiverCur = self.teamRepo.ComputeMaxShare(receiverTeamId, resourceName)
	end
	local clampedAmount = math.min(math.max(amount, 0), maxShare)
	-- Determine the transfer category based on resource type
	local transferCategory = (resourceName == SharedEnums.ResourceType.METAL) and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
	
	local ctx = self:buildPolicyContext(senderTeamId, receiverTeamId)
	
	-- Run pre-process hooks to let policies augment context
	ctx = PolicyHooks.RunPreProcess(ctx)
	
	local res = evaluatePolicies(transferCategory, ctx)
	
	-- Run post-process hooks for state updates/cleanup
	PolicyHooks.RunPostProcess(ctx, res)
	-- Pipeline just returns the expose data - orchestrator handles the rest
	if type(res) == "table" and res.expose then
		Spring.Log("[PIPELINE]", "debug",string.format("[PIPELINE] Returning expose data for senderTeamId=%d", senderTeamId))
		return res.expose
	end
	
	-- No expose data generated
	return nil
end

-- Make computeTakeBypass global so it can be accessed from calculateDefaultUnitTransfer
function computeTakeBypass(fromTeamID, toTeamID)
	if ServiceRegistry.TeamRepository().AreAlliedTeams(fromTeamID, toTeamID) then
		local teamRepo = ServiceRegistry.TeamRepository()
		local playerList = teamRepo.GetPlayerList()
		for _, playerID in ipairs(playerList) do
			local _, active, spectator, teamID = teamRepo.GetPlayerInfo(playerID, false)
			if active and not spectator and teamID == fromTeamID then
				return false
			end
		end
		return true
	end
	return false
end

-- Commands are executed directly in policies via RegisterPostTransfer hooks

---@see luaui/types/team_transfer.lua Pipeline.RunTeamEvent
function Pipeline:RunTeamEvent(eventType, teamID, playerID, gameFrame)
	-- Calculate default expose data for all transfer categories
	local defaultMetalTransfer = calculateDefaultMetalTransfer(teamID, teamID)
	local defaultEnergyTransfer = calculateDefaultEnergyTransfer(teamID, teamID)
	local defaultUnitTransfer = calculateDefaultUnitTransfer(teamID, teamID)
	local defaultCommandValidation = calculateDefaultCommandValidation(teamID, teamID)
	local defaultTeamEvents = calculateDefaultTeamEvents(teamID)
	
	---@type TeamTransferPolicyContext
	local ctx = {
		type = SharedEnums.TransferCategory.TeamEvents,
		eventType = eventType,
		senderTeamId = teamID,
		receiverTeamId = teamID, -- Team events are self-referential
		playerID = playerID,
		gameFrame = gameFrame,
		areAlliedTeams = true, -- Self is always allied
		isCheatingEnabled = ServiceRegistry.SpringRepository().IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(teamID),
		receiverIsNonPlayer = isNonPlayerTeam(teamID),
		-- Pre-calculated default expose data for all categories
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
	}

	local res = evaluatePolicies(SharedEnums.TransferCategory.TeamEvents, ctx)
	if type(res) == "table" then
		-- Commands are handled via RegisterPostTransfer hooks in policies
	end
end

-- Cache for predicate-based expose trees
local predicateExposeCache = {}

-- Generate cache key from predicate combination and team context
local function generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE] generatePredicateCacheKeyWithResources called with:")
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   predicateScope: " .. tostring(predicateScope))
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   policyType: " .. tostring(policyType))
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   senderTeamID: " .. tostring(senderTeamID))
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   receiverTeamID: " .. tostring(receiverTeamID))
	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   gameFrame: " .. tostring(gameFrame))

	-- Validate team IDs before proceeding
	if not senderTeamID or senderTeamID < 0 then
		Spring.Log("[PIPELINE]", "error","[PIPELINE] generatePredicateCacheKeyWithResources called with invalid senderTeamID: " .. tostring(senderTeamID))
		return "invalid_sender", nil, nil
	end

	if not receiverTeamID or receiverTeamID < 0 then
		Spring.Log("[PIPELINE]", "error","[PIPELINE] generatePredicateCacheKeyWithResources called with invalid receiverTeamID: " .. tostring(receiverTeamID))
		return "invalid_receiver", nil, nil
	end

	Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE] Team ID validation passed, proceeding to get resource data")

	-- Round down to nearest 10th frame for less aggressive cache invalidation
	-- This gives ~3 frames of cache life at 30 FPS (0.1 seconds)
	local roundedFrame = math.floor(gameFrame / 10) * 10

	-- Get complete resource data for both teams (single Spring API calls)
	-- Handle cases where SharingUtils might not be available (test environment)
	local teamRepo = ServiceRegistry.TeamRepository()
	local function defaultResources()
		return {
			metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
			energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
		}
	end
	local senderResources = (teamRepo and teamRepo.GetTeamResourcesData and teamRepo.GetTeamResourcesData(senderTeamID)) or defaultResources()
	local receiverResources = (teamRepo and teamRepo.GetTeamResourcesData and teamRepo.GetTeamResourcesData(receiverTeamID)) or defaultResources()

	-- Create hash of relevant context including both teams
	local contextStr = string.format("%s_%s_%d_%d_%d_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f", 
		predicateScope, policyType, senderTeamID, receiverTeamID, roundedFrame, 
		senderResources.metal.current, senderResources.metal.storage, 
		senderResources.energy.current, senderResources.energy.storage,
		receiverResources.metal.current, receiverResources.metal.storage, 
		receiverResources.energy.current, receiverResources.energy.storage)
	return contextStr, senderResources, receiverResources
end

local function convertToSharedOutputTypes(rawExpose, policyType, senderTeamID, receiverTeamID, receiverResources)
  if policyType == SharedEnums.TransferCategory.MetalTransfer then
    local metal = rawExpose[SharedEnums.TransferCategory.MetalTransfer]
    return metal or calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
  elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
    local energy = rawExpose[SharedEnums.TransferCategory.EnergyTransfer]
    return energy or calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
  elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
    local unit = rawExpose[SharedEnums.TransferCategory.UnitTransfer]
    return unit or calculateDefaultUnitTransfer(senderTeamID, receiverTeamID)
  elseif policyType == SharedEnums.TransferCategory.CommandValidation then
    local cmd = rawExpose[SharedEnums.TransferCategory.CommandValidation]
    return cmd or calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
  else
    error("Unknown transfer type: " .. tostring(policyType))
  end
end

-- Evaluate all policies for a given predicate combination and return combined expose data
local function evaluatePredicateCombination(pipeline, predicateScope, policyType, senderTeamID, receiverTeamID, senderResources, receiverResources)
	local TT = (GG and GG.TeamTransfer) or TeamTransfer

	local policiesTable
	if TT and TT.GetPolicies then
		policiesTable = TT.GetPolicies()
	else
		-- Fallback to ServiceRegistry for test environments
		policiesTable = ServiceRegistry.PolicyRepository().GetPolicies()
	end

	if not policiesTable then
		return {}
	end

	local entries = policiesTable[policyType]
	if not entries then
		-- Return defaults when no policies are found
		local defaults = {}
		if policyType == SharedEnums.TransferCategory.MetalTransfer then
			defaults = { canShare = false, maxMetalShareAmount = 0, blockReason = "No metal sharing policies found" }
		elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
			defaults = { canShare = false, maxEnergyShareAmount = 0, blockReason = "No energy sharing policies found" }
		elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
			defaults = { canShareUnits = false, blockReason = "No unit sharing policies found" }
		elseif policyType == SharedEnums.TransferCategory.CommandValidation then
			defaults = { allowGuardCommands = false, allowRepairCommands = false, allowReclaimCommands = false, blockReason = "No command policies found" }
		end
		return defaults
	end

	-- Get pre-sorted policies from repository (cached)
	entries = ServiceRegistry.PolicyRepository().GetSortedPolicies(policyType)

	-- Create execution plan data structure
	local springRepo = ServiceRegistry.SpringRepository()
	local plan = {
		gameFrame = springRepo.GetGameFrame(),
		policyType = policyType,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		predicateScope = predicateScope,
		rules = {},
		context = {},
		activePolicies = {},
	}

	local ctx = pipeline:buildPolicyContext(senderTeamID, receiverTeamID)

	-- Store context in plan
	plan.context = ctx

	-- Helper function to build human-readable rule names
	local function buildHumanReadableRuleName(entry, policyType)
		local baseName

		if policyType == SharedEnums.TransferCategory.CommandValidation then
			if entry.commandFlag then
				baseName = string.format("policy:Allied():Command(%s)", entry.commandFlag:gsub("allow", ""):gsub("Commands", ""))
			else
				baseName = "policy:Allied():Commands()"
			end
		elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
			baseName = "policy:Allied():UnitTransfers()"
		elseif policyType == SharedEnums.TransferCategory.MetalTransfer then
			baseName = "policy:Allied():MetalTransfers()"
		elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
			baseName = "policy:Allied():EnergyTransfers()"
		else
			baseName = entry.name or "unknown_rule"
		end

		local name = baseName

		-- Add condition information if available
		if entry.conditions and #entry.conditions > 0 then
			local conditionNames = {}
			for _, condition in ipairs(entry.conditions) do
				if condition.type == "positive" then
					table.insert(conditionNames, "When(bothStorages)")
				elseif condition.type == "negative" then
					table.insert(conditionNames, "WhenNot(bothStorages)")
				elseif condition.type == "inverse" then
					-- This is an inverse condition from the fluent policy
					table.insert(conditionNames, "WhenNot(bothStorages)")
				end
			end
			if #conditionNames > 0 then
				name = name .. ":" .. table.concat(conditionNames, ":")
			end
		end

		-- Add the action (Allow/Deny)
		if entry.inverse then
			name = name .. ":Deny()"
		else
			name = name .. ":Allow()"
		end

		return name
	end

	-- Helper function to extract conditions from the fluent API structure
	local function extractConditionsFromEntry(entry, policyType)
		local conditions = {}

		-- Add scope condition (Allied/Enemy)
		local scopeCondition = {
			name = "Allied()",
			type = "scope"
		}
		
		-- Check predicates for scope
		if entry.predicates then
			for _, pred in ipairs(entry.predicates) do
				if pred.name == "areAlliedTeams" or pred.name == "targetAllied" then
					scopeCondition.name = "Allied()"
					break
				elseif pred.name == "areEnemyTeams" or pred.name == "targetEnemy" then
					scopeCondition.name = "Enemy()"
					break
				end
			end
		end
		table.insert(conditions, scopeCondition)

		-- Add category/type condition
		if policyType == SharedEnums.TransferCategory.CommandValidation then
			if entry.commandFlag then
				local cmdType = entry.commandFlag:gsub("allow", ""):gsub("Commands", "")
				table.insert(conditions, {
					name = cmdType .. "()",
					type = "scope"
				})
			else
				table.insert(conditions, {
					name = "Commands()",
					type = "scope"
				})
			end
		elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
			table.insert(conditions, {
				name = "UnitTransfers()",
				type = "scope"
			})
		elseif policyType == SharedEnums.TransferCategory.MetalTransfer then
			table.insert(conditions, {
				name = "MetalTransfers()",
				type = "scope"
			})
		elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
			table.insert(conditions, {
				name = "EnergyTransfers()",
				type = "scope"
			})
		end

		-- Add When conditions
		if entry.conditions and #entry.conditions > 0 then
			for _, condition in ipairs(entry.conditions) do
				if condition.type == "positive" then
					table.insert(conditions, {
						name = "When(bothStorages)",
						type = "evaluative",
						passed = true  -- Will be evaluated
					})
				elseif condition.type == "negative" then
					table.insert(conditions, {
						name = "WhenNot(bothStorages)",
						type = "evaluative",
						passed = true  -- Will be evaluated
					})
				elseif condition.type == "inverse" then
					-- This is an inverse condition from the fluent policy
					table.insert(conditions, {
						name = "WhenNot(bothStorages)",
						type = "evaluative",
						passed = true  -- Will be evaluated
					})
				end
			end
		end

		-- Add the action (Allow/Deny)
		if entry.inverse then
			table.insert(conditions, {
				name = "Deny()",
				type = "action"
			})
		else
			table.insert(conditions, {
				name = "Allow()",
				type = "action"
			})
		end

		return conditions
	end

	-- Evaluate policies and collect expose data
	local combinedExpose = {}

	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local policyName = entry.name or ("policy_" .. i)


		-- Create rule info for plan - focus on rule definition, not execution state
		local ruleInfo = {
			name = buildHumanReadableRuleName(entry, policyType),
			conditions = extractConditionsFromEntry(entry, policyType),
			outcome = nil
		}

		-- Evaluate each condition based on predicates
		local allConditionsPassed = true
		
		-- Update condition evaluation based on predicates
		for _, condition in ipairs(ruleInfo.conditions) do
			if condition.type == "evaluative" then
				-- Only evaluative conditions have a pass/fail state
				if entry.conditions then
					for _, entryCondition in ipairs(entry.conditions) do
						local condPassed = entryCondition.fn and entryCondition.fn(ctx) or false
						condition.passed = condPassed
						if not condPassed then
							allConditionsPassed = false
						end
					end
				end
			end
			-- Scope and action conditions don't have 'passed' - they're descriptive
		end

		-- Check if all predicates match for this combination
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			local predResult = predFn(ctx)

			if not predResult then
				ok = false
				allConditionsPassed = false
				break
			end
		end

		if ok and allConditionsPassed then
			-- Run the policy handler to get expose data
			ctx.lastResult = { allow = true }
			local res = entry.handler(ctx)
			ruleInfo.outcome = res

			if res and res.expose then
				-- Merge expose data from this policy using mergeExposeData function
				combinedExpose = mergeExposeData(combinedExpose, res.expose)
			end
		end

		-- Add rule info to plan
		table.insert(plan.rules, ruleInfo)
	end
	
	-- Convert to strongly-typed output format
	local finalResult = convertToSharedOutputTypes(combinedExpose, policyType, senderTeamID, receiverTeamID, receiverResources)

	-- Don't store overarching result in plan - each rule has its own outcome
	-- plan.result = finalResult

	return finalResult, plan
end

-- Duplicate function definition removed - using the one defined above

-- Initialize/evaluate policies for a given context (direct access to evaluatePolicies)
---@see luaui/types/team_transfer.lua Pipeline.Initialize
function Pipeline:Initialize(policyType, senderTeamID, receiverTeamID, options)
	options = options or {}
	receiverTeamID = receiverTeamID or senderTeamID -- Default to self for state evaluation
	
	local ctx = self:buildPolicyContext(senderTeamID, receiverTeamID)
	
	return evaluatePolicies(policyType, ctx)
end

-- Pipeline Validation Methods

---Validate unit transfer using pipeline and validators
---@see luaui/types/team_transfer.lua Pipeline.ValidateUnitTransfer
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param unitID number? The unit ID being transferred
---@param unitDefID number? The unit definition ID
---@return boolean isValid Whether the transfer is valid
function Pipeline:ValidateUnitTransfer(senderTeamID, receiverTeamID, unitID, unitDefID)
	-- Get expose data for this team pair
	local exposeData = self:GetExpose(senderTeamID, receiverTeamID, SharedEnums.TransferCategory.UnitTransfer)
	
	if not exposeData or not exposeData.canShareUnits then
		return false
	end
	
	-- Create context for validators
	local ctx = {
		type = SharedEnums.TransferCategory.UnitTransfer,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		unitID = unitID,
		unitDefID = unitDefID,
		areAlliedTeams = ServiceRegistry.TeamRepository().AreAlliedTeams(senderTeamID, receiverTeamID),
		gameFrame = ServiceRegistry.SpringRepository().GetGameFrame(),
		isCheatingEnabled = ServiceRegistry.SpringRepository().IsCheatingEnabled(),
	}
	
	-- Run validators with expose results
	local exposeResults = {
		[SharedEnums.TransferCategory.UnitTransfer] = exposeData
	}
	
	return PolicyHooks.RunValidators(ctx, exposeResults)
end

-- Query expose data for a specific transfer category (automatically determines allied/enemy scope)
---@see luaui/types/team_transfer.lua Pipeline.GetExpose
---@param senderTeamID number Team ID sending the transfer
---@param receiverTeamID number Team ID receiving the transfer
---@param transferCategory TransferCategory The transfer category to query
---@return table The strongly-typed expose result based on transferCategory and active policies
function Pipeline:GetExpose(senderTeamID, receiverTeamID, transferCategory)
	-- Automatically determine scope from team relationship
	local areAllied = self.teamRepo.AreAlliedTeams(senderTeamID, receiverTeamID)
	local scope = areAllied and SharedEnums.Scope.Allied or SharedEnums.Scope.Enemy

	local springRepo = self.springRepo
	local gameFrame = springRepo.GetGameFrame()

	-- Get resource data and cache key in one call (avoiding duplicate Spring API calls)
	local cacheKey, senderResources, receiverResources = generatePredicateCacheKeyWithResources(scope, transferCategory, senderTeamID, receiverTeamID, gameFrame)

	-- Check cache first (disabled - cache key doesn't include unit data)
	-- TODO: Implement proper caching that includes unit composition in cache key
	-- if predicateExposeCache[cacheKey] then
	-- 	return predicateExposeCache[cacheKey]
	-- end

	-- Cache miss - evaluate predicate combination for specific team pair
	local combinedExpose, plan = evaluatePredicateCombination(self, scope, transferCategory, senderTeamID, receiverTeamID, senderResources, receiverResources)

	-- Cache the result (disabled)
	-- predicateExposeCache[cacheKey] = combinedExpose

	-- Clean old cache entries (keep entries from last 5 rounded frames ~1.5 seconds at 30 FPS)
	local roundedFrame = math.floor(gameFrame / 10) * 10
	local keepFrames = {}
	for i = 0, 4 do -- Keep 5 frames worth of cache
		keepFrames[roundedFrame - (i * 10)] = true
	end

	for key, _ in pairs(predicateExposeCache) do
		local found = false
		for keepFrame, _ in pairs(keepFrames) do
			if string.find(key, "_" .. keepFrame .. "_") then
				found = true
				break
			end
		end
		if not found then
			predicateExposeCache[key] = nil
		end
	end

	return combinedExpose, plan
end

---@class CommandValidationResultWrapper
---@field allowGuardCommands boolean
---@field allowRepairCommands boolean
---@field allowReclaimCommands boolean
---@field blockReason string?
local CommandValidationResultWrapper = {}

---Get the allowGuardCommands value
---@param self CommandValidationResultWrapper
---@return boolean
function CommandValidationResultWrapper.GetAllowGuardCommands(self)
	return self.allowGuardCommands
end

---Get the allowRepairCommands value
---@param self CommandValidationResultWrapper
---@return boolean
function CommandValidationResultWrapper.GetAllowRepairCommands(self)
	return self.allowRepairCommands
end

---Get the allowReclaimCommands value
---@param self CommandValidationResultWrapper
---@return boolean
function CommandValidationResultWrapper.GetAllowReclaimCommands(self)
	return self.allowReclaimCommands
end

---Get the blockReason value
---@param self CommandValidationResultWrapper
---@return string?
function CommandValidationResultWrapper.GetBlockReason(self)
	return self.blockReason
end

---Create a command validation result with static methods for F12 navigation
---@param allowGuardCommands boolean
---@param allowRepairCommands boolean  
---@param allowReclaimCommands boolean
---@param blockReason string?
---@return table
function Pipeline.CreateCommandValidationResult(allowGuardCommands, allowRepairCommands, allowReclaimCommands, blockReason)
	local result = {
		allowGuardCommands = allowGuardCommands,
		allowRepairCommands = allowRepairCommands,
		allowReclaimCommands = allowReclaimCommands,
		blockReason = blockReason,
	}
	-- Data-only: do not attach any function fields
	return result
end

-- Static property accessor functions for F12 navigation
---Get allowGuardCommands property - F12 navigation target
---@return boolean
function Pipeline.GetAllowGuardCommands()
	return true -- This is just for F12 navigation, actual value comes from runtime
end

---Get allowRepairCommands property - F12 navigation target  
---@return boolean
function Pipeline.GetAllowRepairCommands()
	return true -- This is just for F12 navigation, actual value comes from runtime
end

---Get allowReclaimCommands property - F12 navigation target
---@return boolean
function Pipeline.GetAllowReclaimCommands()
	return true -- This is just for F12 navigation, actual value comes from runtime
end

---Get blockReason property - F12 navigation target
---@return string?
function Pipeline.GetBlockReason()
	return nil -- This is just for F12 navigation, actual value comes from runtime
end

---@class CombinedExposeOutputWrapper
---@field CommandValidation CommandValidationResultWrapper
---@field UnitTransfer table
---@field MetalTransfer table
---@field EnergyTransfer table
local CombinedExposeOutputWrapper = {}

---Get CommandValidation results
---@param self CombinedExposeOutputWrapper
---@return CommandValidationResultWrapper
function CombinedExposeOutputWrapper.GetCommandValidation(self)
	return self.CommandValidation
end

---Get UnitTransfer results
---@param self CombinedExposeOutputWrapper
---@return table
function CombinedExposeOutputWrapper.GetUnitTransfer(self)
	return self.UnitTransfer
end

---Get MetalTransfer results
---@param self CombinedExposeOutputWrapper
---@return table
function CombinedExposeOutputWrapper.GetMetalTransfer(self)
	return self.MetalTransfer
end

---Get EnergyTransfer results
---@param self CombinedExposeOutputWrapper
---@return table
function CombinedExposeOutputWrapper.GetEnergyTransfer(self)
	return self.EnergyTransfer
end

-- Legacy compatibility wrapper - maps old QueryExpose calls to new predicate-based system
---@param senderTeamID number
---@param receiverTeamID number
---@return CombinedExposeOutputWrapper
---@return table
function Pipeline:QueryExpose(senderTeamID, receiverTeamID)
	-- For backward compatibility, return combined expose data for all categories
	local result = {}
	local lastPlan = nil

	-- Query each category and add to result
	local categories = {
		SharedEnums.TransferCategory.CommandValidation,
		SharedEnums.TransferCategory.UnitTransfer,
		SharedEnums.TransferCategory.MetalTransfer,
		SharedEnums.TransferCategory.EnergyTransfer
	}

	for _, category in ipairs(categories) do
		local exposeData
		if category == SharedEnums.TransferCategory.CommandValidation then
			-- For command validation, use a direct evaluation without complex resource data
			local ctx = {
				type = category,
				senderTeamId = senderTeamID,
				receiverTeamId = receiverTeamID,
				areAlliedTeams = self.teamRepo.AreAlliedTeams(senderTeamID, receiverTeamID),
				isCheatingEnabled = self.springRepo.IsCheatingEnabled(),
				gameFrame = self.springRepo.GetGameFrame(),
				defaultCommandValidation = calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
			}

			-- Provide repositories in ctx for policy When/Use predicates
			ctx.repositories = {
				SpringRepository = self.springRepo,
				TeamRepository = self.teamRepo,
				UnitRepository = self.unitRepo
			}

			-- Get policies table
			local policiesTable = self.policyRepo.GetPolicies()

			-- Evaluate command validation policies directly
			local combinedExpose = {}
			local entries = policiesTable and policiesTable[category]
			if entries then
				for i = 1, #entries do
					local entry = entries[i]
					local preds = entry.predicates
					local ok = true
					for j = 1, #preds do
						local pred = preds[j]
						local predFn = type(pred) == "function" and pred or pred.fn
						if not predFn(ctx) then
							ok = false
							break
						end
					end

					if ok and entry.handler then
						local res = entry.handler(ctx)
						if res and res.expose then
							combinedExpose = mergeExposeData(combinedExpose, res.expose)
						end
					end
				end
			end

			-- Provide defaults if no policies applied
			exposeData = combinedExpose[SharedEnums.TransferCategory.CommandValidation] or {
				allowGuardCommands = false,
				allowRepairCommands = false,
				allowReclaimCommands = false,
				blockReason = "No policies allowed these commands"
			}
		else
			-- For other categories, use GetExpose to automatically determine scope
			exposeData, lastPlan = self:GetExpose(senderTeamID, receiverTeamID, category)
		end

		if exposeData then
			-- Add the category-specific data to the combined result
			if category == SharedEnums.TransferCategory.CommandValidation then
				result.CommandValidation = exposeData
			elseif category == SharedEnums.TransferCategory.UnitTransfer then
				result.UnitTransfer = exposeData
			elseif category == SharedEnums.TransferCategory.MetalTransfer then
				result.MetalTransfer = exposeData
			elseif category == SharedEnums.TransferCategory.EnergyTransfer then
				result.EnergyTransfer = exposeData
			end
		end
	end

	-- Do not attach wrapper accessors to result to keep it data-only
	-- result.GetCommandValidation = CombinedExposeOutputWrapper.GetCommandValidation
	-- result.GetUnitTransfer = CombinedExposeOutputWrapper.GetUnitTransfer
	-- result.GetMetalTransfer = CombinedExposeOutputWrapper.GetMetalTransfer
	-- result.GetEnergyTransfer = CombinedExposeOutputWrapper.GetEnergyTransfer

	return result, lastPlan
end

-- Expose pipeline introspection functions
Pipeline.Debug = {
	LogTopology = PipelineLogger.LogTopology,
	LogCacheState = PipelineLogger.LogCacheState,
	LogCacheEntry = PipelineLogger.LogCacheEntry,
	LogFullReport = PipelineLogger.LogFullReport,
}


Spring.Log("[PIPELINE]", "DEBUG",  "[PIPELINE] pipeline.lua initialization completed successfully")
Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE] Available pipeline functions:")
local pipelineFunctions = {"RunAllowResourceTransfer", "RunAllowUnitTransfer", "RunAllowCommand", "RunTeamEvent", "QueryExpose", "GetExpose", "Initialize"}
for _, funcName in ipairs(pipelineFunctions) do
	if Pipeline[funcName] then
		Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   ✓ " .. funcName .. " available")
	else
		Spring.Log("[PIPELINE]", "DEBUG", "[PIPELINE]   ✗ " .. funcName .. " missing (not implemented yet)")
	end
end

-- Deferred policies will be executed when the first pipeline instance is created

return Pipeline
