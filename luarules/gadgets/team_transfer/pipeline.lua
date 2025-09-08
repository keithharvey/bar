---@class TeamTransferPipeline
---@field RunAllowResourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: "metal"|"energy", amount: number): table?
---@field ValidateUnitTransfer fun(senderTeamID: number, receiverTeamID: number, unitID: number?, unitDefID: number?): boolean
---@field RunTeamEvent fun(eventType: string, teamID: number, playerID: number?, gameFrame: number): table?
---@field QueryExpose fun(senderTeamID: number, receiverTeamID: number): CombinedExposeOutput
---@field QueryExposeByPredicates fun(predicateScope: PredicateScope, policyType: TransferCategory, senderTeamID: number, receiverTeamID: number): CombinedExposeOutput?
---@field Initialize fun(policyType: TransferCategory, senderTeamID: number, receiverTeamID: number, options: table?): table

-- Avoid creating a separate API instance; use GG.TeamTransfer when available
-- All VFS.Includes at the top
local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
local Repository = VFS.Include("luarules/gadgets/team_transfer/unit_repository.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")
local FluentPolicy = VFS.Include("luarules/gadgets/team_transfer/fluent_policy.lua")
local ResultDefaults = VFS.Include("luarules/gadgets/team_transfer/result_defaults.lua")

-- Shared logging utility
Logger.SetLogMode("NONE")  -- Set to "NONE" to disable all logging, "ERROR" for errors only, "DEBUG" for all

local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

LogDebug("[PIPELINE] Starting pipeline.lua initialization")
LogDebug("[PIPELINE] Including dependencies...")

local Pipeline = {}
LogDebug("[PIPELINE] Pipeline object created")

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
		blockReason = "No policies allowed metal sharing"
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
		blockReason = "No policies allowed energy sharing"
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
	return Pipeline.CreateCommandValidationResult(false, false, false, "No policies allowed these commands")
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
	LogInfo("=== Team Transfer Pipeline Architecture ===")

	-- Log policy types and their registered policies
	for policyType, policies in pairs(TT.GetPolicies()) do
		LogInfo(string.format("Policy Type: %s (%d policies)", policyType, #policies))

		-- Sort policies by dependencies for display
		local sortedPolicies = topologicalSort(policies)
		for i, entry in ipairs(sortedPolicies) do
			local deps = entry.dependsOn and table.concat(entry.dependsOn, ", ") or "none"
			LogInfo(string.format("  %d. %s (depends on: %s)", i, entry.name, deps))
		end
	end
end

-- Analyze and log the current cache state
function PipelineLogger.LogCacheState()
	LogInfo("=== Predicate Cache Analysis ===")

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

	LogInfo(string.format("Total cache entries: %d", cacheCount))

	-- Log cache distribution
	LogInfo("Cache by scope:")
	for scope, count in pairs(cacheByScope) do
		LogInfo(string.format("  %s: %d entries", scope, count))
	end

	LogInfo("Cache by policy type:")
	for policyType, count in pairs(cacheByType) do
		LogInfo(string.format("  %s: %d entries", policyType, count))
	end

	LogInfo("Cache by frame:")
	for frame, count in pairs(cacheByFrame) do
		LogInfo(string.format("  Frame %s: %d entries", frame, count))
	end
end

-- Analyze a specific cache entry in detail
function PipelineLogger.LogCacheEntry(predicateScope, policyType, senderTeamID, receiverTeamID)
	local springRepo = ServiceRegistry.SpringRepository()
	local gameFrame = springRepo.GetGameFrame()
	local cacheKey, senderResources, receiverResources = generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)

	LogInfo(string.format("=== Cache Entry Analysis: %s ===", cacheKey))

	local cacheData = predicateExposeCache[cacheKey]
	if cacheData then
		LogInfo("Cache HIT - Entry exists")

		-- Log expose data structure
		if cacheData.metal then
			LogInfo(string.format("Metal: canShare=%s, maxAmount=%.1f, blockReason=%s",
				tostring(cacheData.metal.canShareMetal), cacheData.metal.maxMetalShareAmount or 0, cacheData.metal.blockReason or "none"))
		end
		if cacheData.energy then
			LogInfo(string.format("Energy: canShare=%s, maxAmount=%.1f, blockReason=%s",
				tostring(cacheData.energy.canShareEnergy), cacheData.energy.maxEnergyShareAmount or 0, cacheData.energy.blockReason or "none"))
		end
		if cacheData.canShareUnits ~= nil then
			LogInfo(string.format("Units: canShare=%s, blockReason=%s",
				tostring(cacheData.canShareUnits), cacheData.blockReason or "none"))
		end
	else
		LogInfo("Cache MISS - Entry would be generated")

		-- Log the context that would be used
		LogInfo(string.format("Context: %s %s transfer from team %d to team %d",
			predicateScope, policyType, senderTeamID, receiverTeamID))

		if senderResources and receiverResources then
			LogInfo(string.format("Sender resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
				senderResources.metal.current, senderResources.metal.storage,
				senderResources.energy.current, senderResources.energy.storage))
			LogInfo(string.format("Receiver resources: Metal=%.1f/%.1f (slider=%.2f), Energy=%.1f/%.1f (slider=%.2f)",
				receiverResources.metal.current, receiverResources.metal.storage, receiverResources.metal.shareSlider,
				receiverResources.energy.current, receiverResources.energy.storage, receiverResources.energy.shareSlider))
		end
	end
end

-- Generate a comprehensive pipeline report
function PipelineLogger.LogFullReport()
	LogInfo("=== COMPREHENSIVE TEAM TRANSFER TeamTransfer ===")
	local springRepo = ServiceRegistry.SpringRepository()
	LogInfo(string.format("Generated at game frame: %d", springRepo.GetGameFrame()))

	PipelineLogger.LogTopology()
	LogInfo("")
	PipelineLogger.LogCacheState()

	LogInfo("=== END TeamTransfer ===")
end

-- Helper function to get player name for a team
local function getPlayerNameForTeam(teamID)
	local playerList = Spring.GetPlayerList()
	for i = 1, #playerList do
		local playerID = playerList[i]
		local name, active, spectator, playerTeamID = Spring.GetPlayerInfo(playerID)
		if active and not spectator and playerTeamID == teamID then
			return name
		end
	end
	return nil
end

-- Topological sort moved to PolicyRepository

local function logPipelinePlan(policyType, ctx, sortedEntries)
	local entries = sortedEntries
	
	LogDebug("=== TeamTransfer for " .. tostring(policyType) .. " ===")
	-- Show relevant context fields based on policy type
	local contextStr = "Context: "
	if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer or policyType == SharedEnums.TransferCategory.UnitTransfer then
		contextStr = contextStr .. "areAlliedTeams=" .. tostring(ctx.areAlliedTeams) .. ", senderTeamId=" .. tostring(ctx.senderTeamId) .. ", receiverTeamId=" .. tostring(ctx.receiverTeamId)
	elseif policyType == SharedEnums.TransferCategory.CommandValidation then
		contextStr = contextStr .. "unitID=" .. tostring(ctx.unitID) .. ", cmdID=" .. tostring(ctx.cmdID) .. ", teamID=" .. tostring(ctx.teamID)
	else
		contextStr = contextStr .. "type=" .. tostring(policyType)
	end
	LogDebug(contextStr)
	LogDebug("")
	
	-- Get team and player info for context
	local teamInfo = ""
	if ctx.senderTeamId then
		local playerList = Spring.GetPlayerList(ctx.senderTeamId, true)
		local playerName = playerList and playerList[1] and Spring.GetPlayerInfo(playerList[1], false) or "Unknown"
		teamInfo = " (Team " .. ctx.senderTeamId .. " - " .. playerName .. ")"
	end
	
	-- Show dependency tree structure
	LogDebug("DEPENDENCY TREE" .. teamInfo .. ":")
	for i = 1, #entries do
		local entry = entries[i]
		local policyName = entry.name or ("policy_" .. i)

		-- Create tree visualization (ASCII-safe)
		local treePrefix = ""
		if i == #entries then
			treePrefix = "+-- "
		else
			treePrefix = "|-- "
		end

		-- Show dependencies with arrows
		local depsStr = ""
		if entry.dependencies and #entry.dependencies > 0 then
			depsStr = " <- [" .. table.concat(entry.dependencies, ", ") .. "]"
		end

		LogDebug(treePrefix .. policyName .. depsStr)
	end
	LogDebug("")
	
	-- Show execution plan with predicates
	LogDebug("EXECUTION PLAN" .. teamInfo .. ":")
	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local policyName = entry.name or ("policy_" .. i)
		
		-- Simple predicate description
		local predNames = {}
		for j = 1, #preds do
			local pred = preds[j]
			if type(pred) == "function" then
				predNames[j] = "predicate_" .. j
			else
				predNames[j] = pred.name or ("predicate_" .. j)
			end
		end
		
		LogDebug("Policy " .. i .. " (" .. policyName .. "): " .. #preds .. " predicates [" .. table.concat(predNames, ", ") .. "]")
		
		-- Check if predicates match
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			local predName = type(pred) == "function" and ("predicate_" .. j) or (pred.name or "anon")
			
			if not predFn(ctx) then
				ok = false
				LogDebug("  -> [X] Predicate " .. j .. " (" .. predName .. ") = FALSE")
				break
			else
				LogDebug("  -> [OK] Predicate " .. j .. " (" .. predName .. ") = TRUE")
			end
		end
		
		if ok then
			LogDebug("  -> [GO] Policy " .. i .. " (" .. policyName .. ") WILL EXECUTE")
		else
			LogDebug("  -> [SKIP] Policy " .. i .. " (" .. policyName .. ") SKIPPED (predicate failed)")
		end
	end
	LogDebug("=== END TeamTransfer ===")
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
function Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	local resourceName = (resourceType == SharedEnums.ResourceType.METAL) and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
	local maxShare = 0
	local receiverCur = 0
	if resourceName == SharedEnums.ResourceType.METAL or resourceName == SharedEnums.ResourceType.ENERGY then
		maxShare, receiverCur = SharingUtils.ComputeMaxShare(receiverTeamId, resourceName)
	end
	local clampedAmount = math.min(math.max(amount, 0), maxShare)
	-- Determine the transfer category based on resource type
	local transferCategory = (resourceName == SharedEnums.ResourceType.METAL) and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
	
	-- Calculate default expose data for all transfer categories
	local defaultMetalTransfer = calculateDefaultMetalTransfer(senderTeamId, receiverTeamId)
	local defaultEnergyTransfer = calculateDefaultEnergyTransfer(senderTeamId, receiverTeamId)
	local defaultUnitTransfer = calculateDefaultUnitTransfer(senderTeamId, receiverTeamId)
	local defaultCommandValidation = calculateDefaultCommandValidation(senderTeamId, receiverTeamId)
	local defaultTeamEvents = calculateDefaultTeamEvents(senderTeamId)

	---@type TeamTransferPolicyContext
	local ctx = {
		type = transferCategory,
		senderTeamId = senderTeamId,
		receiverTeamId = receiverTeamId,
		resource = resourceName,
		amount = amount,
		amountClamped = clampedAmount,
		maxShare = maxShare,
		receiverCur = receiverCur,
		cumulativeMetal = Repository.GetCumulativeMetalSent(senderTeamId),
		areAlliedTeams = ServiceRegistry.TeamRepository().AreAlliedTeams(senderTeamId, receiverTeamId),
		isCheatingEnabled = ServiceRegistry.SpringRepository().IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamId),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamId),
		gameFrame = ServiceRegistry.SpringRepository().GetGameFrame(),
		-- Pre-calculated default expose data that policies can use or override
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
	}
	-- Run pre-process hooks to let policies augment context
	ctx = PolicyHooks.RunPreProcess(ctx)
	
	local res = evaluatePolicies(transferCategory, ctx)
	
	-- Run post-process hooks for state updates/cleanup
	PolicyHooks.RunPostProcess(ctx, res)
	-- Pipeline just returns the expose data - orchestrator handles the rest
	if type(res) == "table" and res.expose then
		LogDebug(string.format("[PIPELINE] Returning expose data for senderTeamId=%d", senderTeamId))
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
function Pipeline.RunTeamEvent(eventType, teamID, playerID, gameFrame)
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
	LogDebug("[PIPELINE] generatePredicateCacheKeyWithResources called with:")
	LogDebug("[PIPELINE]   predicateScope: " .. tostring(predicateScope))
	LogDebug("[PIPELINE]   policyType: " .. tostring(policyType))
	LogDebug("[PIPELINE]   senderTeamID: " .. tostring(senderTeamID))
	LogDebug("[PIPELINE]   receiverTeamID: " .. tostring(receiverTeamID))
	LogDebug("[PIPELINE]   gameFrame: " .. tostring(gameFrame))

	-- Validate team IDs before proceeding
	if not senderTeamID or senderTeamID < 0 then
		LogError("[PIPELINE] generatePredicateCacheKeyWithResources called with invalid senderTeamID: " .. tostring(senderTeamID))
		return "invalid_sender", nil, nil
	end

	if not receiverTeamID or receiverTeamID < 0 then
		LogError("[PIPELINE] generatePredicateCacheKeyWithResources called with invalid receiverTeamID: " .. tostring(receiverTeamID))
		return "invalid_receiver", nil, nil
	end

	LogDebug("[PIPELINE] Team ID validation passed, proceeding to get resource data")

	-- Round down to nearest 10th frame for less aggressive cache invalidation
	-- This gives ~3 frames of cache life at 30 FPS (0.1 seconds)
	local roundedFrame = math.floor(gameFrame / 10) * 10

	-- Get complete resource data for both teams (single Spring API calls)
	-- Handle cases where SharingUtils might not be available (test environment)
	local senderResources = SharingUtils.GetTeamResourcesData(senderTeamID)
	local receiverResources = SharingUtils.GetTeamResourcesData(receiverTeamID)

	-- If SharingUtils fails (e.g., in test environment), provide mock data
	if not senderResources or not senderResources.metal then
		senderResources = {
			metal = { current = 1000, storage = 2000, pull = 0, income = 0, expense = 0, shareSlider = 1 },
			energy = { current = 1000, storage = 2000, pull = 0, income = 0, expense = 0, shareSlider = 1 }
		}
	end

	if not receiverResources or not receiverResources.metal then
		receiverResources = {
			metal = { current = 1000, storage = 2000, pull = 0, income = 0, expense = 0, shareSlider = 1 },
			energy = { current = 1000, storage = 2000, pull = 0, income = 0, expense = 0, shareSlider = 1 }
		}
	end

	
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
  -- If rawExpose is nil or empty, return defaults for denial
  if not rawExpose or (type(rawExpose) == "table" and next(rawExpose) == nil) then
    if policyType == SharedEnums.TransferCategory.MetalTransfer then
      return { canShare = false, maxMetalShareAmount = 0, blockReason = "No policies executed" }
    elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
      return { canShare = false, maxEnergyShareAmount = 0, blockReason = "No policies executed" }
    elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
      return { canShareUnits = false, blockReason = "No policies executed" }
    elseif policyType == SharedEnums.TransferCategory.CommandValidation then
      return { allowGuardCommands = false, allowRepairCommands = false, allowReclaimCommands = false, blockReason = "No policies executed" }
    end
  end

  -- Extract the specific category data from rawExpose
  if policyType == SharedEnums.TransferCategory.MetalTransfer then
    local metal = rawExpose[SharedEnums.TransferCategory.MetalTransfer]
    return metal or { canShare = false, maxMetalShareAmount = 0, blockReason = "No metal sharing policies executed" }
  elseif policyType == SharedEnums.TransferCategory.EnergyTransfer then
    local energy = rawExpose[SharedEnums.TransferCategory.EnergyTransfer]
    return energy or { canShare = false, maxEnergyShareAmount = 0, blockReason = "No energy sharing policies executed" }
  elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
    local unit = rawExpose[SharedEnums.TransferCategory.UnitTransfer]
    return unit or { canShareUnits = false, blockReason = "No unit sharing policies executed" }
  elseif policyType == SharedEnums.TransferCategory.CommandValidation then
    local cmd = rawExpose[SharedEnums.TransferCategory.CommandValidation]
    return cmd or { allowGuardCommands = false, allowRepairCommands = false, allowReclaimCommands = false, blockReason = "No command policies executed" }
  else
    error("Unknown transfer type: " .. tostring(policyType))
  end
end

-- Evaluate all policies for a given predicate combination and return combined expose data
local function evaluatePredicateCombination(predicateScope, policyType, senderTeamID, receiverTeamID, senderResources, receiverResources)
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
		policies = {},
		context = {},
		result = {}
	}
	
	-- Calculate default expose data for all transfer categories
	local defaultMetalTransfer = calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
	local defaultEnergyTransfer = calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
	local defaultUnitTransfer = calculateDefaultUnitTransfer(senderTeamID, receiverTeamID)
	local defaultCommandValidation = calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
	local defaultTeamEvents = calculateDefaultTeamEvents(senderTeamID)

	-- Create a context for the predicate combination with specific receiver
	---@type TeamTransferPolicyContext
	local ctx = {
		type = policyType,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		amount = 0, -- State query, not actual transfer
		resource = nil, -- State query - not a specific resource transfer
		gameFrame = ServiceRegistry.SpringRepository().GetGameFrame(),
		areAlliedTeams = (predicateScope == SharedEnums.Scope.Allied),
		isCheatingEnabled = ServiceRegistry.SpringRepository().IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamID),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamID),
		-- Pre-calculated default expose data that policies can use or override
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
	}

	-- Store context in plan
	plan.context = {
		areAlliedTeams = ctx.areAlliedTeams,
		isCheatingEnabled = ctx.isCheatingEnabled,
		senderIsNonPlayer = ctx.senderIsNonPlayer,
		receiverIsNonPlayer = ctx.receiverIsNonPlayer,
		senderResources = senderResources,
		receiverResources = receiverResources
	}
	
	-- Add additional context for resource transfers using provided resource data
	if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
		-- Use the resource data already collected to avoid duplicate Spring API calls
		-- Provide defaults if resource data is not available

		-- TODO: this is not complete. we need to get the max storage share for energy as well.
		if receiverResources and receiverResources.metal then
			ctx.maxStorageShare = receiverResources.metal.storage - receiverResources.metal.current
			ctx.receiverCur = receiverResources.metal.current
		else
			ctx.maxStorageShare = 1000  -- Default storage share
			ctx.receiverCur = 1000      -- Default current amount
		end
		ctx.cumulativeMetal = Repository.GetCumulativeMetalSent(senderTeamID)
	end

	-- Evaluate policies and collect expose data
	local combinedExpose = {}
	
	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local policyName = entry.name or ("policy_" .. i)

		-- Create policy info for plan
		local policyInfo = {
			name = policyName,
			index = i,
			predicates = {},
			predicatesPassed = true,
			executed = false,
			result = nil,
			dependencies = entry.dependencies or {}
		}

		-- Check if all predicates match for this combination
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			local predResult = predFn(ctx)

			-- Store predicate info in plan
			table.insert(policyInfo.predicates, {
				name = pred.name or ("predicate_" .. j),
				passed = predResult
			})

			if not predResult then
				ok = false
				policyInfo.predicatesPassed = false
				break
			end
		end

		if ok then
			-- Run the policy handler to get expose data
			ctx.lastResult = { allow = true }
			local res = entry.handler(ctx)
			policyInfo.executed = true
			policyInfo.result = res


			if res and res.expose then
				-- Merge expose data from this policy
				for category, data in pairs(res.expose) do
					if not combinedExpose[category] then
						combinedExpose[category] = {}
					end

					-- Merge policy data
					for key, value in pairs(data) do
						if key == "_policyData" then
							-- Merge policy-specific data
							if not combinedExpose[category]._policyData then
								combinedExpose[category]._policyData = {}
							end
							for policyKey, policyValue in pairs(value) do
								combinedExpose[category]._policyData[policyKey] = policyValue
							end
						else
							-- Direct merge for other data
							combinedExpose[category][key] = value
						end
					end
				end
			end
		end

		-- Add policy info to plan
		table.insert(plan.policies, policyInfo)
	end
	
	-- Convert to strongly-typed output format
	local finalResult = convertToSharedOutputTypes(combinedExpose, policyType, senderTeamID, receiverTeamID, receiverResources)

	-- Store final result in plan
	plan.result = finalResult

	return finalResult
end

-- Duplicate function definition removed - using the one defined above

-- Initialize/evaluate policies for a given context (direct access to evaluatePolicies)
---@see luaui/types/team_transfer.lua Pipeline.Initialize
function Pipeline.Initialize(policyType, senderTeamID, receiverTeamID, options)
	options = options or {}
	receiverTeamID = receiverTeamID or senderTeamID -- Default to self for state evaluation
	
	-- Calculate default expose data for all transfer categories
	local defaultMetalTransfer = calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
	local defaultEnergyTransfer = calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
	local defaultUnitTransfer = calculateDefaultUnitTransfer(senderTeamID, receiverTeamID, options.selectedUnitIDs)
	local defaultCommandValidation = calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
	local defaultTeamEvents = calculateDefaultTeamEvents(senderTeamID)
	
	---@type TeamTransferPolicyContext
	local ctx = {
		type = policyType,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		amount = options.amount or 0, -- Default to state query
		resource = options.resource,
		unitID = options.unitID,
		unitDefID = options.unitDefID,
		selectedUnitIDs = options.selectedUnitIDs,
		gameFrame = ServiceRegistry.SpringRepository().GetGameFrame(),
		areAlliedTeams = ServiceRegistry.TeamRepository().AreAlliedTeams(senderTeamID, receiverTeamID),
		isCheatingEnabled = ServiceRegistry.SpringRepository().IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamID),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamID),
		-- Pre-calculated default expose data that policies can use or override
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
	}
	
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
function Pipeline.ValidateUnitTransfer(senderTeamID, receiverTeamID, unitID, unitDefID)
	-- Get expose data for this team pair
	local scope = ServiceRegistry.TeamRepository().AreAlliedTeams(senderTeamID, receiverTeamID) and SharedEnums.Scope.Allied or SharedEnums.Scope.Enemy
	local exposeData = Pipeline.QueryExposeByPredicates(scope, SharedEnums.TransferCategory.UnitTransfer, senderTeamID, receiverTeamID)
	
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

-- Query expose data by predicate combination with caching (team-aware)
---@see luaui/types/team_transfer.lua Pipeline.QueryExposeByPredicates
---Query expose data by predicates for a specific policy type and team pair
---@param predicateScope PredicateScope "allied" or "enemy"
---@param policyType TransferCategory The transfer category to query
---@param senderTeamID number Team ID sending the transfer
---@param receiverTeamID number Team ID receiving the transfer
---@return CombinedExposeOutput? Strongly-typed expose data for the specific sender->receiver combination
function Pipeline.QueryExposeByPredicates(predicateScope, policyType, senderTeamID, receiverTeamID)
	local springRepo = ServiceRegistry.SpringRepository()
	local gameFrame = springRepo.GetGameFrame()
	
	-- Get resource data and cache key in one call (avoiding duplicate Spring API calls)
	local cacheKey, senderResources, receiverResources = generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)
	
	-- Check cache first
	if predicateExposeCache[cacheKey] then
		return predicateExposeCache[cacheKey]
	end
	
	-- Cache miss - evaluate predicate combination for specific team pair
	local combinedExpose = evaluatePredicateCombination(predicateScope, policyType, senderTeamID, receiverTeamID, senderResources, receiverResources)
	
	-- Cache the result
	predicateExposeCache[cacheKey] = combinedExpose
	
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
	
	return combinedExpose
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
---@deprecated Use Pipeline.QueryExposeByPredicates instead
---@param senderTeamID number
---@param receiverTeamID number
---@return CombinedExposeOutputWrapper
function Pipeline.QueryExpose(senderTeamID, receiverTeamID)
	-- For backward compatibility, return combined expose data for all categories
	local result = {}

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
				areAlliedTeams = ServiceRegistry.TeamRepository().AreAlliedTeams(senderTeamID, receiverTeamID),
				isCheatingEnabled = (function()
					local springRepo = ServiceRegistry.SpringRepository()
					if not springRepo then
						LogError("[PIPELINE] SpringRepository not found in service registry!")
						return false
					end
					if not springRepo.IsCheatingEnabled then
						LogError("[PIPELINE] SpringRepository missing IsCheatingEnabled method!")
						return false
					end
					return springRepo.IsCheatingEnabled()
				end)(),
				gameFrame = (function()
					local springRepo = ServiceRegistry.SpringRepository()
					if not springRepo then
						LogError("[PIPELINE] SpringRepository not found in service registry for GetGameFrame!")
						return 1
					end
					if not springRepo.GetGameFrame then
						LogError("[PIPELINE] SpringRepository missing GetGameFrame method!")
						return 1
					end
					return springRepo.GetGameFrame()
				end)(),
				defaultCommandValidation = calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
			}

			-- Get policies table
			local policiesTable = ServiceRegistry.PolicyRepository().GetPolicies()

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
			exposeData = combinedExpose[SharedEnums.TransferCategory.CommandValidation] or Pipeline.CreateCommandValidationResult(false, false, false, "No policies allowed these commands")
		else
			-- For other categories, use the full QueryExposeByPredicates
			exposeData = Pipeline.QueryExposeByPredicates(SharedEnums.Scope.Allied, category, senderTeamID, receiverTeamID)
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

	return result
end

-- Expose pipeline introspection functions
Pipeline.Debug = {
	LogTopology = PipelineLogger.LogTopology,
	LogCacheState = PipelineLogger.LogCacheState,
	LogCacheEntry = PipelineLogger.LogCacheEntry,
	LogFullReport = PipelineLogger.LogFullReport,
}

LogInfo("[PIPELINE] pipeline.lua initialization completed successfully")
LogDebug("[PIPELINE] Available pipeline functions:")
local pipelineFunctions = {"RunAllowResourceTransfer", "RunAllowUnitTransfer", "RunAllowCommand", "RunTeamEvent", "QueryExpose", "QueryExposeByPredicates", "Initialize"}
for _, funcName in ipairs(pipelineFunctions) do
	if Pipeline[funcName] then
		LogDebug("[PIPELINE]   ✓ " .. funcName .. " available")
	else
		LogError("[PIPELINE]   ✗ " .. funcName .. " missing")
	end
end

-- Execute any deferred policy registrations with current context
LogDebug("[PIPELINE] Executing deferred policy registrations")
local context = {
	Spring = _G.Spring,
	VFS = _G.VFS,
	UnitDefs = _G.UnitDefs
}
FluentPolicy.ExecuteDeferredPolicies(context)

return Pipeline
