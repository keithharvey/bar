-- Avoid creating a separate API instance; use GG.TeamTransfer when available
-- Shared logging utility
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
Logger.SetLogMode("NONE")  -- Set to "NONE" to disable all logging, "ERROR" for errors only, "DEBUG" for all

local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

LogDebug("[PIPELINE] Starting pipeline.lua initialization")
LogDebug("[PIPELINE] Including dependencies...")

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
LogDebug("[PIPELINE] Loaded api_gadgets.lua")

local State = VFS.Include("luarules/gadgets/team_transfer/state.lua")
LogDebug("[PIPELINE] Loaded state.lua")

local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")
LogDebug("[PIPELINE] Loaded policy_hooks.lua")

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
LogDebug("[PIPELINE] Loaded shared_enums.lua")

local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")
LogDebug("[PIPELINE] Loaded sharing_utils.lua")

local Pipeline = {}
LogDebug("[PIPELINE] Pipeline object created")



-- Default Expose Data Calculation Functions
-- These provide strongly-typed default calculations that policies can use or override

---Calculate default metal transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultMetalTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultMetalTransferResult Default metal transfer calculations
local function calculateDefaultMetalTransfer(senderTeamID, receiverTeamID)
	local senderMetal = Spring.GetTeamResources(senderTeamID, "metal")
	local receiverMetal = Spring.GetTeamResources(receiverTeamID, "metal")
	local receiverMetalStorage = Spring.GetTeamResources(receiverTeamID, "metal", "storage")
	
	-- Calculate receiver's available capacity and sender's sendable amount
	local maxMetalShareAmount = math.max(0, receiverMetalStorage - receiverMetal)
	local amountSendable = math.min(senderMetal, maxMetalShareAmount)
	local canShareMetal = amountSendable > 0
	
	---@type DefaultMetalTransferResult
	return {
		amountSendable = amountSendable,
		canShare = canShareMetal
	}
end

---Calculate default energy transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultEnergyTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultEnergyTransferResult Default energy transfer calculations
local function calculateDefaultEnergyTransfer(senderTeamID, receiverTeamID)
	local senderEnergy = Spring.GetTeamResources(senderTeamID, "energy")
	local receiverEnergy = Spring.GetTeamResources(receiverTeamID, "energy")
	local receiverEnergyStorage = Spring.GetTeamResources(receiverTeamID, "energy", "storage")
	
	-- Calculate receiver's available capacity and sender's sendable amount
	local maxEnergyShareAmount = math.max(0, receiverEnergyStorage - receiverEnergy)
	local amountSendable = math.min(senderEnergy, maxEnergyShareAmount)
	local canShareEnergy = amountSendable > 0
	
	---@type DefaultEnergyTransferResult
	return {
		amountSendable = amountSendable,
		canShare = canShareEnergy
	}
end

---Calculate default unit transfer data for pipeline context
---@see luaui/types/team_transfer.lua DefaultUnitTransferResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param selectedUnitIDs number[]? Selected unit IDs for transfer
---@return DefaultUnitTransferResult Default unit transfer calculations
local function calculateDefaultUnitTransfer(senderTeamID, receiverTeamID, selectedUnitIDs)
	-- Check if unit sharing is generally allowed based on team relationship
	local areAllied = Spring.AreTeamsAllied(senderTeamID, receiverTeamID)
	local canShareUnits = areAllied -- Default: only allow sharing to allies
	
	-- Calculate take bypass (receiver has no active players)
	local takeBypass = false
	if areAllied then
		takeBypass = computeTakeBypass(senderTeamID, receiverTeamID)
	end
	
	---@type DefaultUnitTransferResult
	return {
		canShareUnits = canShareUnits,
		takeBypass = takeBypass
	}
end

---Calculate default command validation data for pipeline context
---@see luaui/types/team_transfer.lua DefaultCommandValidationResult
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return DefaultCommandValidationResult Default command validation
local function calculateDefaultCommandValidation(senderTeamID, receiverTeamID)
	local areAllied = Spring.AreTeamsAllied(senderTeamID, receiverTeamID)
	
	---@type DefaultCommandValidationResult
	return {
		allowGuardCommands = areAllied, -- Default: allow guard commands to allies
		allowRepairCommands = areAllied, -- Default: allow repair commands to allies
		allowReclaimCommands = areAllied -- Default: allow reclaim commands to allies
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
	local gameFrame = Spring.GetGameFrame()
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
	LogInfo(string.format("Generated at game frame: %d", Spring.GetGameFrame()))

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

-- Topological sort for dependency-based policy ordering
local function topologicalSort(entries)
	local sorted = {}
	local visited = {}
	local visiting = {}
	
	local function visit(entry)
		if visiting[entry.name] then
			error("Circular dependency detected involving policy: " .. entry.name)
		end
		if visited[entry.name] then
			return
		end
		
		visiting[entry.name] = true
		
		-- Visit all dependencies first
		if entry.dependencies then
			for _, depName in ipairs(entry.dependencies) do
				for _, depEntry in ipairs(entries) do
					if depEntry.name == depName then
						visit(depEntry)
						break
					end
				end
			end
		end
		
		visiting[entry.name] = nil
		visited[entry.name] = true
		sorted[#sorted + 1] = entry
	end
	
	-- Visit all entries
	for _, entry in ipairs(entries) do
		visit(entry)
	end
	
	return sorted
end

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
	if teamID == Spring.GetGaiaTeamID() then
		return true
	end
	local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID)
	if isAiTeam then
		return true
	end
	if Spring.GetTeamLuaAI(teamID) ~= nil then
		return true
	end
	return false
end

local function mergeExposeData(existing, incoming)
    if not existing then return incoming end
    if not incoming then return existing end
    local out = existing
    for key, value in pairs(incoming) do
        local old = out[key]
        if key == "canShareMetal" or key == "canShareEnergy" or key == "canShareUnits"
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
    return out
end

local function evaluatePolicies(policyType, ctx)
	local TT = (GG and GG.TeamTransfer) or TeamTransfer
	local entries = TT.GetPolicies()[policyType]

	LogDebug("Pipeline called for type: " .. tostring(policyType))
	LogDebug("Found " .. tostring(#(entries or {})) .. " policies for type: " .. tostring(policyType))

	if entries and #entries > 0 then
		for i, entry in ipairs(entries) do
			LogDebug("Policy " .. i .. ": " .. tostring(entry.name or "unnamed"))
		end
	else
		LogDebug("No policies found for type: " .. tostring(policyType))
	end

	-- Sort policies by dependencies using topological sort
	entries = topologicalSort(entries)

	logPipelinePlan(policyType, ctx, entries)
	
	local finalResult = { allow = true } -- Default to allowing if no policy intervenes
	
	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local policyName = entry.name or ("policy_" .. i)
		
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			local predName = type(pred) == "function" and ("predicate_" .. j) or (pred.name or "anon")
			local predResult = predFn(ctx)
			
			-- Debug predicate evaluation for enemy policies
			if policyName and string.find(policyName, "ENEMY") then
				LogDebug("Policy " .. policyName .. " predicate " .. predName .. " = " .. tostring(predResult) .. " (areAlliedTeams=" .. tostring(ctx.areAlliedTeams) .. ")")
			end
			
			if not predResult then
				ok = false
				break
			end
		end
		
		if ok then
			-- Only log resource transfer policy execution for debugging
			if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
				LogDebug("Running policy handler " .. tostring(i) .. " (" .. policyName .. ")")
			end
			
			-- Pass the current result to the next policy in the dependsOn chain
			ctx.lastResult = finalResult
			local res = entry.handler(ctx)
			
			if res then
				if res.deny then
					return { deny = true }
				end
				if res.expose then
					finalResult.expose = finalResult.expose or {}
					for category, data in pairs(res.expose) do
						finalResult.expose[category] = mergeExposeData(finalResult.expose[category], data)
					end
				end
				if res.allow ~= nil then finalResult.allow = finalResult.allow and res.allow end
			end
		end
	end
	
	return finalResult
end

---@see luaui/types/team_transfer.lua Pipeline.RunResourceTransfer
function Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	LogDebug("RunAllowResourceTransfer called: " .. tostring(senderTeamId) .. " -> " .. tostring(receiverTeamId) .. " " .. tostring(resourceType) .. " " .. tostring(amount))
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
		cumulativeMetal = State.GetCumulativeMetalSent(senderTeamId),
		areAlliedTeams = Spring.AreTeamsAllied(senderTeamId, receiverTeamId),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamId),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamId),
		gameFrame = Spring.GetGameFrame(),
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

local function computeTakeBypass(fromTeamID, toTeamID)
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
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
		isCheatingEnabled = Spring.IsCheatingEnabled(),
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

	local senderResources = SharingUtils.GetTeamResourcesData(senderTeamID)

	local receiverResources = SharingUtils.GetTeamResourcesData(receiverTeamID)
	
	-- Create hash of relevant context including both teams
	local contextStr = string.format("%s_%s_%d_%d_%d_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f", 
		predicateScope, policyType, senderTeamID, receiverTeamID, roundedFrame, 
		senderResources.metal.current, senderResources.metal.storage, 
		senderResources.energy.current, senderResources.energy.storage,
		receiverResources.metal.current, receiverResources.metal.storage, 
		receiverResources.energy.current, receiverResources.energy.storage)
	return contextStr, senderResources, receiverResources
end

-- Convert raw expose data to strongly-typed shared output format
local function convertToSharedOutputTypes(rawExpose, policyType, senderTeamID, receiverTeamID, receiverResources)
	if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
		-- Handle both metal and energy transfer data
		---@type PolicyMetalTransferExpose
		local metalData = rawExpose[SharedEnums.TransferCategory.MetalTransfer] or {}
		---@type PolicyEnergyTransferExpose
		local energyData = rawExpose[SharedEnums.TransferCategory.EnergyTransfer] or {}

		-- Use provided resource data instead of calling Spring APIs
		-- Share slider determines what portion of storage the receiver is willing to accept
		local maxMetalShareAmount = math.max(0, (receiverResources.metal.storage * receiverResources.metal.shareSlider) - receiverResources.metal.current)
		local maxEnergyShareAmount = math.max(0, (receiverResources.energy.storage * receiverResources.energy.shareSlider) - receiverResources.energy.current)

		---@type ResourceTransferExposeOutput
		return {
			metal = {
				maxMetalShareAmount = maxMetalShareAmount,
				canShareMetal = maxMetalShareAmount > 0 and (metalData.amountSendable or 0) > 0,
				blockReason = (maxMetalShareAmount <= 0) and "No metal storage space available" or
							 ((metalData.amountSendable or 0) <= 0) and (metalData.blockReason or "Metal sharing blocked by policy") or nil,
				taxRate = metalData.taxRate,
				metalThreshold = metalData.metalThreshold,
				amountAlreadySent = metalData.amountAlreadySent,
				amountRemainingAllowance = metalData.amountRemainingAllowance,
			},
			energy = {
				maxEnergyShareAmount = maxEnergyShareAmount,
				canShareEnergy = maxEnergyShareAmount > 0 and (energyData.amountSendable or 0) > 0,
				blockReason = (maxEnergyShareAmount <= 0) and "No energy storage space available" or
							 ((energyData.amountSendable or 0) <= 0) and (energyData.blockReason or "Energy sharing blocked by policy") or nil,
				taxRate = energyData.taxRate,
				energyThreshold = energyData.energyThreshold,
				amountAlreadySent = energyData.amountAlreadySent,
				amountRemainingAllowance = energyData.amountRemainingAllowance,
			}
		}
	elseif policyType == SharedEnums.TransferCategory.UnitTransfer then
		---@type PolicyUnitTransferExpose
		local unitData = rawExpose[SharedEnums.TransferCategory.UnitTransfer] or {}

		---@type UnitTransferExposeOutput
		return {
			canShareUnits = unitData.canShareUnits == true,
			shareableUnitCount = unitData.shareableUnitCount,
			unshareableUnitCount = unitData.unshareableUnitCount,
			blockReason = unitData.blockReason,
		}
	else
		-- Unknown transfer type - return empty data
		return {}
	end
end

-- Evaluate all policies for a given predicate combination and return combined expose data
local function evaluatePredicateCombination(predicateScope, policyType, senderTeamID, receiverTeamID, senderResources, receiverResources)
	local TT = (GG and GG.TeamTransfer) or TeamTransfer

	if not TT then
		LogError("[PIPELINE] TT is nil! GG.TeamTransfer and TeamTransfer are both nil")
		LogError("[PIPELINE] This suggests GG.TeamTransfer hasn't been set up yet by the main gadget")
		return {}
	end

	if not TT.GetPolicies then
		LogError("[PIPELINE] TT.GetPolicies is nil! TT = " .. tostring(TT))
		LogError("[PIPELINE] TT type: " .. type(TT))
		LogError("[PIPELINE] TT keys: " .. (TT and table.concat(tableKeys(TT), ", ") or "none"))
		return {}
	end

	local policiesTable = TT.GetPolicies()
	if not policiesTable then
		LogError("[PIPELINE] TT.GetPolicies() returned nil")
		return {}
	end

	local entries = policiesTable[policyType]
	if not entries then
		LogError("[PIPELINE] No entries found for policyType: " .. tostring(policyType))
		LogError("[PIPELINE] Available policy types: " .. table.concat(tableKeys(policiesTable), ", "))
		return {}
	end

	LogDebug("[PIPELINE] Retrieved " .. tostring(#entries) .. " entries for policyType: " .. tostring(policyType))
	
	-- Sort policies by dependencies using topological sort
	entries = topologicalSort(entries)
	
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
		gameFrame = Spring.GetGameFrame(),
		areAlliedTeams = (predicateScope == SharedEnums.Scope.Allied),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamID),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamID),
		-- Pre-calculated default expose data that policies can use or override
		defaultMetalTransfer = defaultMetalTransfer,
		defaultEnergyTransfer = defaultEnergyTransfer,
		defaultUnitTransfer = defaultUnitTransfer,
		defaultCommandValidation = defaultCommandValidation,
		defaultTeamEvents = defaultTeamEvents,
	}
	
	-- Add additional context for resource transfers using provided resource data
	if policyType == SharedEnums.TransferCategory.MetalTransfer or policyType == SharedEnums.TransferCategory.EnergyTransfer then
		-- Use the resource data already collected to avoid duplicate Spring API calls
		ctx.maxStorageShare = receiverResources.metal.storage - receiverResources.metal.current
		ctx.receiverCur = receiverResources.metal.current
		ctx.cumulativeMetal = State.GetCumulativeMetalSent(senderTeamID)
	end

	-- Evaluate policies and collect expose data
	local combinedExpose = {}
	
	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local policyName = entry.name or ("policy_" .. i)
		
		-- Check if all predicates match for this combination
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			if not predFn(ctx) then
				ok = false
				break
			end
		end
		
		if ok then
			-- Run the policy handler to get expose data
			ctx.lastResult = { allow = true }
			local res = entry.handler(ctx)
			
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
	end
	
	-- Convert to strongly-typed output format
	return convertToSharedOutputTypes(combinedExpose, policyType, senderTeamID, receiverTeamID, receiverResources)
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
		gameFrame = Spring.GetGameFrame(),
		areAlliedTeams = Spring.AreTeamsAllied(senderTeamID, receiverTeamID),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
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
	local scope = Spring.AreTeamsAllied(senderTeamID, receiverTeamID) and SharedEnums.Scope.Allied or SharedEnums.Scope.Enemy
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
		areAlliedTeams = Spring.AreTeamsAllied(senderTeamID, receiverTeamID),
		gameFrame = Spring.GetGameFrame(),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
	}
	
	-- Run validators with expose results
	local exposeResults = {
		[SharedEnums.TransferCategory.UnitTransfer] = exposeData
	}
	
	return PolicyHooks.RunValidators(ctx, exposeResults)
end

-- Query expose data by predicate combination with caching (team-aware)
---@see luaui/types/team_transfer.lua Pipeline.QueryExposeByPredicates
---@param predicateScope "allied"|"enemy" The predicate scope
---@param policyType TransferCategory Use SharedEnums.TransferCategory values (MetalTransfer, EnergyTransfer, or UnitTransfer)
---@param senderTeamID number Team ID sending the transfer
---@param receiverTeamID number Team ID receiving the transfer
---@return MetalTransferExposeOutput|EnergyTransferExposeOutput|UnitTransferExposeOutput? Strongly-typed expose data for the specific sender->receiver combination
function Pipeline.QueryExposeByPredicates(predicateScope, policyType, senderTeamID, receiverTeamID)
	local gameFrame = Spring.GetGameFrame()
	
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

-- Legacy compatibility wrapper - maps old QueryExpose calls to new predicate-based system
---@deprecated Use Pipeline.QueryExposeByPredicates instead
function Pipeline.QueryExpose(policyType, senderTeamID)
	-- For now, just query allied scope with self as receiver to maintain compatibility
	-- TODO: This should be enhanced to query all team pairs, but for now we need it working
	return Pipeline.QueryExposeByPredicates(SharedEnums.Scope.Allied, policyType, senderTeamID, senderTeamID)
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

return Pipeline
