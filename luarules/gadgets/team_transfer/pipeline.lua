-- Avoid creating a separate API instance; use GG.TeamTransfer when available
local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Resources = VFS.Include("luarules/gadgets/team_transfer/resources.lua")
local State = VFS.Include("luarules/gadgets/team_transfer/state.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local Pipeline = {}

-- Pipeline introspection and logging functions
local PipelineLogger = {}

-- Analyze and log the current pipeline topology
function PipelineLogger.LogTopology()
	local TT = (GG and GG.TeamTransfer) or TeamTransfer
	Spring.Log("PIPELINE TOPOLOGY", "info", "=== Team Transfer Pipeline Architecture ===")
	
	-- Log policy types and their registered policies
	for policyType, policies in pairs(TT.GetPolicies()) do
		Spring.Log("PIPELINE TOPOLOGY", "info", string.format("Policy Type: %s (%d policies)", policyType, #policies))
		
		-- Sort policies by dependencies for display
		local sortedPolicies = topologicalSort(policies)
		for i, entry in ipairs(sortedPolicies) do
			local deps = entry.dependsOn and table.concat(entry.dependsOn, ", ") or "none"
			Spring.Log("PIPELINE TOPOLOGY", "info", string.format("  %d. %s (depends on: %s)", i, entry.name, deps))
		end
	end
end

-- Analyze and log the current cache state
function PipelineLogger.LogCacheState()
	Spring.Log("PIPELINE CACHE", "info", "=== Predicate Cache Analysis ===")
	
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
	
	Spring.Log("PIPELINE CACHE", "info", string.format("Total cache entries: %d", cacheCount))
	
	-- Log cache distribution
	Spring.Log("PIPELINE CACHE", "info", "Cache by scope:")
	for scope, count in pairs(cacheByScope) do
		Spring.Log("PIPELINE CACHE", "info", string.format("  %s: %d entries", scope, count))
	end
	
	Spring.Log("PIPELINE CACHE", "info", "Cache by policy type:")
	for policyType, count in pairs(cacheByType) do
		Spring.Log("PIPELINE CACHE", "info", string.format("  %s: %d entries", policyType, count))
	end
	
	Spring.Log("PIPELINE CACHE", "info", "Cache by frame:")
	for frame, count in pairs(cacheByFrame) do
		Spring.Log("PIPELINE CACHE", "info", string.format("  Frame %s: %d entries", frame, count))
	end
end

-- Analyze a specific cache entry in detail
function PipelineLogger.LogCacheEntry(predicateScope, policyType, senderTeamID, receiverTeamID)
	local gameFrame = Spring.GetGameFrame()
	local cacheKey, senderResources, receiverResources = generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)
	
	Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("=== Cache Entry Analysis: %s ===", cacheKey))
	
	local cacheData = predicateExposeCache[cacheKey]
	if cacheData then
		Spring.Log("PIPELINE CACHE ENTRY", "info", "Cache HIT - Entry exists")
		
		-- Log expose data structure
		if cacheData.metal then
			Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Metal: canShare=%s, maxAmount=%.1f, blockReason=%s", 
				tostring(cacheData.metal.canShareMetal), cacheData.metal.maxMetalShareAmount or 0, cacheData.metal.blockReason or "none"))
		end
		if cacheData.energy then
			Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Energy: canShare=%s, maxAmount=%.1f, blockReason=%s", 
				tostring(cacheData.energy.canShareEnergy), cacheData.energy.maxEnergyShareAmount or 0, cacheData.energy.blockReason or "none"))
		end
		if cacheData.canShareUnits ~= nil then
			Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Units: canShare=%s, blockReason=%s", 
				tostring(cacheData.canShareUnits), cacheData.blockReason or "none"))
		end
	else
		Spring.Log("PIPELINE CACHE ENTRY", "info", "Cache MISS - Entry would be generated")
		
		-- Log the context that would be used
		Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Context: %s %s transfer from team %d to team %d", 
			predicateScope, policyType, senderTeamID, receiverTeamID))
		
		if senderResources and receiverResources then
			Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Sender resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f", 
				senderResources.metal.current, senderResources.metal.storage,
				senderResources.energy.current, senderResources.energy.storage))
			Spring.Log("PIPELINE CACHE ENTRY", "info", string.format("Receiver resources: Metal=%.1f/%.1f (slider=%.2f), Energy=%.1f/%.1f (slider=%.2f)", 
				receiverResources.metal.current, receiverResources.metal.storage, receiverResources.metal.shareSlider,
				receiverResources.energy.current, receiverResources.energy.storage, receiverResources.energy.shareSlider))
		end
	end
end

-- Generate a comprehensive pipeline report
function PipelineLogger.LogFullReport()
	Spring.Log("PIPELINE REPORT", "info", "=== COMPREHENSIVE TEAM TRANSFER PIPELINE REPORT ===")
	Spring.Log("PIPELINE REPORT", "info", string.format("Generated at game frame: %d", Spring.GetGameFrame()))
	
	PipelineLogger.LogTopology()
	Spring.Log("PIPELINE REPORT", "info", "")
	PipelineLogger.LogCacheState()
	
	Spring.Log("PIPELINE REPORT", "info", "=== END PIPELINE REPORT ===")
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
	
	Spring.Log("PIPELINE PLAN", "info", "=== PIPELINE PLAN for " .. tostring(policyType) .. " ===")
	-- Show relevant context fields based on policy type
	local contextStr = "Context: "
	if policyType == "ResourceTransfer" or policyType == "UnitTransfer" then
		contextStr = contextStr .. "areAlliedTeams=" .. tostring(ctx.areAlliedTeams) .. ", senderTeamId=" .. tostring(ctx.senderTeamId) .. ", receiverTeamId=" .. tostring(ctx.receiverTeamId)
	elseif policyType == "Command" then
		contextStr = contextStr .. "unitID=" .. tostring(ctx.unitID) .. ", cmdID=" .. tostring(ctx.cmdID) .. ", teamID=" .. tostring(ctx.teamID)
	else
		contextStr = contextStr .. "type=" .. tostring(policyType)
	end
	Spring.Log("PIPELINE PLAN", "info", contextStr)
	Spring.Log("PIPELINE PLAN", "info", "")
	
	-- Get team and player info for context
	local teamInfo = ""
	if ctx.senderTeamId then
		local playerList = Spring.GetPlayerList(ctx.senderTeamId, true)
		local playerName = playerList and playerList[1] and Spring.GetPlayerInfo(playerList[1], false) or "Unknown"
		teamInfo = " (Team " .. ctx.senderTeamId .. " - " .. playerName .. ")"
	end
	
	-- Show dependency tree structure
	Spring.Log("PIPELINE PLAN", "info", "DEPENDENCY TREE" .. teamInfo .. ":")
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
		
		Spring.Log("PIPELINE PLAN", "info", treePrefix .. policyName .. depsStr)
	end
	Spring.Log("PIPELINE PLAN", "info", "")
	
	-- Show execution plan with predicates
	Spring.Log("PIPELINE PLAN", "info", "EXECUTION PLAN" .. teamInfo .. ":")
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
		
		Spring.Log("PIPELINE PLAN", "info", "Policy " .. i .. " (" .. policyName .. "): " .. #preds .. " predicates [" .. table.concat(predNames, ", ") .. "]")
		
		-- Check if predicates match
		local ok = true
		for j = 1, #preds do
			local pred = preds[j]
			local predFn = type(pred) == "function" and pred or pred.fn
			local predName = type(pred) == "function" and ("predicate_" .. j) or (pred.name or "anon")
			
			if not predFn(ctx) then
				ok = false
				Spring.Log("PIPELINE PLAN", "info", "  -> [X] Predicate " .. j .. " (" .. predName .. ") = FALSE")
				break
			else
				Spring.Log("PIPELINE PLAN", "info", "  -> [OK] Predicate " .. j .. " (" .. predName .. ") = TRUE")
			end
		end
		
		if ok then
			Spring.Log("PIPELINE PLAN", "info", "  -> [GO] Policy " .. i .. " (" .. policyName .. ") WILL EXECUTE")
		else
			Spring.Log("PIPELINE PLAN", "info", "  -> [SKIP] Policy " .. i .. " (" .. policyName .. ") SKIPPED (predicate failed)")
		end
	end
	Spring.Log("PIPELINE PLAN", "info", "=== END PIPELINE PLAN ===")
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

local function evaluatePolicies(policyType, ctx)
	local TT = (GG and GG.TeamTransfer) or TeamTransfer
	local entries = TT.GetPolicies()[policyType]

	-- Sort policies by dependencies using topological sort
	entries = topologicalSort(entries)
	
	Spring.Log("PIPELINE DEBUG", "error", "Pipeline called for type: " .. tostring(policyType))
	
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
				Spring.Log("PIPELINE DEBUG", "error", "Policy " .. policyName .. " predicate " .. predName .. " = " .. tostring(predResult) .. " (areAlliedTeams=" .. tostring(ctx.areAlliedTeams) .. ")")
			end
			
			if not predResult then
				ok = false
				break
			end
		end
		
		if ok then
			-- Only log resource transfer policy execution for debugging
			if policyType == "ResourceTransfer" then
				Spring.Log("PIPELINE DEBUG", "error", "Running policy handler " .. tostring(i) .. " (" .. policyName .. ")")
			end
			
			-- Pass the current result to the next policy in the dependsOn chain
			ctx.lastResult = finalResult
			local res = entry.handler(ctx)
			
			if res then
				-- An explicit deny from any policy is a hard stop
				if res.deny then
					return { deny = true }
				end
				
				-- Merge the results, allowing the current policy to override previous ones
				for k, v in pairs(res) do
					finalResult[k] = v
				end
			end
		end
	end
	
	return finalResult
end

function Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	Spring.Log("PIPELINE DEBUG", "error", "RunAllowResourceTransfer called: " .. tostring(senderTeamId) .. " -> " .. tostring(receiverTeamId) .. " " .. tostring(resourceType) .. " " .. tostring(amount))
	local resourceName = (resourceType == SharedEnums.ResourceType.METAL) and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
	local maxShare = 0
	local receiverCur = 0
	if resourceName == SharedEnums.ResourceType.METAL or resourceName == SharedEnums.ResourceType.ENERGY then
		maxShare, receiverCur = Resources.ComputeMaxShare(receiverTeamId, resourceName)
	end
	local clampedAmount = math.min(math.max(amount, 0), maxShare)
	local ctx = {
		type = SharedEnums.PolicyType.ResourceTransfer,
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
	}
	-- Run pre-process hooks to let policies augment context
	ctx = PolicyHooks.RunPreProcess(ctx)
	
	local res = evaluatePolicies(SharedEnums.PolicyType.ResourceTransfer, ctx)
	
	-- Run post-process hooks for state updates/cleanup
	PolicyHooks.RunPostProcess(ctx, res)
	if type(res) == "table" then
			if res.applyTransfer then
		local sent = res.applyTransfer.sent or 0
		local received = res.applyTransfer.received or 0
		Spring.SetTeamResource(receiverTeamId, resourceName, receiverCur + received)
		local sCur = select(1, Spring.GetTeamResources(senderTeamId, resourceName))
		Spring.SetTeamResource(senderTeamId, resourceName, sCur - sent)
		if resourceName == 'metal' and res.applyTransfer.updateCumulativeMetal then
			local newCum = State.AddCumulativeMetalSent(senderTeamId, sent)
			Spring.SetTeamRulesParam(senderTeamId, "metal_share_cumulative_sent", newCum)
		end
		
		-- Handle messaging after successful transfer
		if resourceName == 'metal' and sent > 0 then
			local receiverName = getPlayerNameForTeam(receiverTeamId)
			if receiverName then
				-- Send basic transfer message
				Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveMetal:amount='..sent..':name='..receiverName)
				
				-- Send threshold-specific message if applicable (check tax policy first)
				local taxData = res.expose and res.expose.taxAndThreshold
				local preventData = res.expose and res.expose.preventExcessiveShare
				local policyData = taxData or preventData
				
				if policyData and policyData.threshold and policyData.threshold > 0 then
					local newCumulative = (policyData.amountAlreadySent or 0) + sent
					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sentMetalThreshold:amount='..sent..':cumulative='..newCumulative..':threshold='..math.floor(policyData.threshold))
				else
					Spring.SendLuaRulesMsg('msg:ui.playersList.chat.sentMetalSimple:amount='..sent)
				end
			end
		end
		
		if res.expose then
			-- Send expose data to UI for strongly-typed access
			Spring.SendToUnsynced("TeamTransferExposeUpdate", senderTeamId, res.expose)
		end
		return false
	end
		if res.allow ~= nil then
			return res.allow
		end
		if res.deny ~= nil then
			return not res.deny
		end
	elseif type(res) == "boolean" then
		return res
	end

	return true
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

function Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	local ctx = {
		type = SharedEnums.PolicyType.UnitTransfer,
		unitID = unitID,
		unitDefID = unitDefID,
		fromTeamID = fromTeamID,
		toTeamID = toTeamID,
		capture = capture,
		takeBypassAllowed = computeTakeBypass(fromTeamID, toTeamID),
		areAlliedTeams = Spring.AreTeamsAllied(fromTeamID, toTeamID),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		fromIsNonPlayer = isNonPlayerTeam(fromTeamID),
		toIsNonPlayer = isNonPlayerTeam(toTeamID),
	}

	local res = evaluatePolicies(SharedEnums.PolicyType.UnitTransfer, ctx)
	if type(res) == "table" then
		-- Execute standardized command applications
		if res.applyCommands then
			local commands = res.applyCommands
			
			-- Clear load orders from specified units
			if commands.ClearLoad then
				for _, unitID in ipairs(commands.ClearLoad) do
					local ok, queue = pcall(Spring.GetUnitCommands, unitID)
					if ok and queue and #queue > 0 then
						Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { 'alt' })
					end
				end
			end
			
			-- Clear self-destruct orders from specified units
			if commands.ClearSelfD then
				for _, unitID in ipairs(commands.ClearSelfD) do
					if Spring.GetUnitSelfDTime(unitID) > 0 then
						Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
					end
				end
			end
			
			-- Clear self-destruct orders from all units in specified teams
			if commands.ClearTeamSelfD then
				for _, teamID in ipairs(commands.ClearTeamSelfD) do
					local units = Spring.GetTeamUnits(teamID)
					for i = 1, #units do
						local unitID = units[i]
						if Spring.GetUnitSelfDTime(unitID) > 0 then
							Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
						end
					end
				end
			end
			
			-- Remove specific commands from units
			if commands.RemoveCommands then
				for _, cmd in ipairs(commands.RemoveCommands) do
					if cmd.unitID and cmd.cmdID then
						local options = cmd.options or {}
						Spring.GiveOrderToUnit(cmd.unitID, CMD.REMOVE, { cmd.cmdID }, options)
					end
				end
			end
			
			-- Give new commands to units
			if commands.GiveCommands then
				for _, cmd in ipairs(commands.GiveCommands) do
					if cmd.unitID and cmd.cmdID then
						local params = cmd.params or {}
						local options = cmd.options or {}
						Spring.GiveOrderToUnit(cmd.unitID, cmd.cmdID, params, options)
					end
				end
			end
		end

		if res.allow ~= nil then return res.allow end
		if res.deny ~= nil then return not res.deny end
	elseif type(res) == "boolean" then
		return res
	end
	return true
end

local function isComplete(u)
	local _,_,_,_,buildProgress=Spring.GetUnitHealth(u)
	return (buildProgress and buildProgress>=1) or false
end

function Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	local targetID = cmdParams and cmdParams[1] or nil
	local targetTeam = targetID and Spring.GetUnitTeam(targetID) or nil
	local targetUnitDefID = targetID and Spring.GetUnitDefID(targetID) or nil
	local targetUnitDef = targetUnitDefID and UnitDefs[targetUnitDefID] or nil
	local targetAllied = (targetTeam ~= nil) and Spring.AreTeamsAllied(unitTeam, targetTeam) and (unitTeam ~= targetTeam) or false

	local ctx = {
		type = SharedEnums.PolicyType.Command,
		unitID = unitID,
		unitDefID = unitDefID,
		unitTeam = unitTeam,
		cmdID = cmdID,
		cmdParams = cmdParams,
		cmdOptions = cmdOptions,
		cmdTag = cmdTag,
		synced = synced,
		targetID = targetID,
		targetTeam = targetTeam,
		targetUnitDef = targetUnitDef,
		targetAllied = targetAllied,
		targetIsComplete = targetID and isComplete(targetID) or true,
	}

	local res = evaluatePolicies(SharedEnums.PolicyType.Command, ctx)
	if type(res) == "table" then
		if res.allow ~= nil then return res.allow end
		if res.deny ~= nil then return not res.deny end
	elseif type(res) == "boolean" then
		return res
	end
	return true
end

local function executeTeamCommands(commands)
	-- Clear load orders from specified units
	if commands.ClearLoad then
		for _, unitID in ipairs(commands.ClearLoad) do
			local ok, queue = pcall(Spring.GetUnitCommands, unitID)
			if ok and queue and #queue > 0 then
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { 'alt' })
			end
		end
	end
	
	-- Clear self-destruct orders from specified units
	if commands.ClearSelfD then
		for _, unitID in ipairs(commands.ClearSelfD) do
			if Spring.GetUnitSelfDTime(unitID) > 0 then
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.SELFD }, { 'alt' })
			end
		end
	end
end

function Pipeline.RunTeamEvent(eventType, teamID, playerID, gameFrame)
	local ctx = {
		type = SharedEnums.PolicyType.TeamEvent,
		eventType = eventType,
		teamID = teamID,
		playerID = playerID,
		gameFrame = gameFrame,
		isCheatingEnabled = Spring.IsCheatingEnabled(),
	}

	local res = evaluatePolicies(SharedEnums.PolicyType.TeamEvent, ctx)
	if type(res) == "table" then
		-- Execute team-level command applications
		if res.applyCommands then
			executeTeamCommands(res.applyCommands)
		end
	end
end

-- Cache for predicate-based expose trees
local predicateExposeCache = {}

-- Generate cache key from predicate combination and team context
local function generatePredicateCacheKeyWithResources(predicateScope, policyType, senderTeamID, receiverTeamID, gameFrame)
	-- Round down to nearest 10th frame for less aggressive cache invalidation
	-- This gives ~3 frames of cache life at 30 FPS (0.1 seconds)
	local roundedFrame = math.floor(gameFrame / 10) * 10
	
	-- Get complete resource data for both teams (single Spring API calls)
	local sMCur, sMStor, sMPull, sMInc, sMExp, sMShare = Spring.GetTeamResources(senderTeamID, SharedEnums.ResourceType.METAL)
	local sECur, sEStor, sEPull, sEInc, sEExp, sEShare = Spring.GetTeamResources(senderTeamID, SharedEnums.ResourceType.ENERGY)
	local rMCur, rMStor, rMPull, rMInc, rMExp, rMShare = Spring.GetTeamResources(receiverTeamID, SharedEnums.ResourceType.METAL)
	local rECur, rEStor, rEPull, rEInc, rEExp, rEShare = Spring.GetTeamResources(receiverTeamID, SharedEnums.ResourceType.ENERGY)
	
	---@type TeamResourcesData
	local senderResources = {
		metal = { current = sMCur, storage = sMStor, pull = sMPull, income = sMInc, expense = sMExp, shareSlider = sMShare },
		energy = { current = sECur, storage = sEStor, pull = sEPull, income = sEInc, expense = sEExp, shareSlider = sEShare }
	}
	
	---@type TeamResourcesData  
	local receiverResources = {
		metal = { current = rMCur, storage = rMStor, pull = rMPull, income = rMInc, expense = rMExp, shareSlider = rMShare },
		energy = { current = rECur, storage = rEStor, pull = rEPull, income = rEInc, expense = rEExp, shareSlider = rEShare }
	}
	
	-- Create hash of relevant context including both teams
	local contextStr = string.format("%s_%s_%d_%d_%d_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f_%.0f", 
		predicateScope, policyType, senderTeamID, receiverTeamID, roundedFrame, 
		sMCur or 0, sMStor or 0, sECur or 0, sEStor or 0,
		rMCur or 0, rMStor or 0, rECur or 0, rEStor or 0)
	return contextStr, senderResources, receiverResources
end

-- Convert raw expose data to strongly-typed shared output format
local function convertToSharedOutputTypes(rawExpose, policyType, senderTeamID, receiverTeamID, receiverResources)
	if policyType == SharedEnums.PolicyType.ResourceTransfer then
		-- Handle both metal and energy transfer data
		local metalData = rawExpose[SharedEnums.TransferCategory.METAL_TRANSFER] or {}
		local energyData = rawExpose[SharedEnums.TransferCategory.ENERGY_TRANSFER] or {}
		
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
	elseif transferType == "unit" then
		local unitData = rawExpose[SharedEnums.TransferCategory.UNIT_TRANSFER] or {}
		
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
	local entries = TT.GetPolicies()[policyType]
	
	-- Sort policies by dependencies using topological sort
	entries = topologicalSort(entries)
	
	-- Create a mock context for the predicate combination with specific receiver
	local ctx = {
		type = policyType,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID,
		amount = 0, -- State query, not actual transfer
		resource = nil, -- State query - not a specific resource transfer
		senderResources = senderResources, -- Provide complete resource data
		receiverResources = receiverResources, -- Provide complete resource data
		gameFrame = Spring.GetGameFrame(),
		areAlliedTeams = (predicateScope == "allied"),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamID),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamID),
	}
	
	-- Add additional context for resource transfers using provided resource data
	if policyType == SharedEnums.PolicyType.ResourceTransfer then
		-- Use the resource data already collected to avoid duplicate Spring API calls
		ctx.maxStorageShare = receiverResources.metal.storage * receiverResources.metal.shareSlider - receiverResources.metal.current
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
function Pipeline.Initialize(policyType, senderTeamID, receiverTeamID, options)
	options = options or {}
	
	local ctx = {
		type = policyType,
		senderTeamId = senderTeamID,
		receiverTeamId = receiverTeamID or senderTeamID, -- Default to self for state evaluation
		amount = options.amount or 0, -- Default to state query
		resource = options.resource,
		unitID = options.unitID,
		unitDefID = options.unitDefID,
		gameFrame = Spring.GetGameFrame(),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
	}
	
	return evaluatePolicies(policyType, ctx)
end

-- Query expose data by predicate combination with caching (team-aware)
-- @param predicateScope "allied" or "enemy" 
-- @param policyType Use SharedEnums.PolicyType values (ResourceTransfer or UnitTransfer)
-- @param senderTeamID Team ID sending the transfer
-- @param receiverTeamID Team ID receiving the transfer
-- @return Strongly-typed expose data for the specific sender->receiver combination
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
	
	-- Clean old cache entries (keep only current rounded frame entries)
	local roundedFrame = math.floor(gameFrame / 10) * 10
	for key, _ in pairs(predicateExposeCache) do
		if not string.find(key, "_" .. roundedFrame .. "_") then
			predicateExposeCache[key] = nil
		end
	end
	
	return combinedExpose
end

-- Legacy compatibility wrapper - maps old QueryExpose calls to new predicate-based system
function Pipeline.QueryExpose(policyType, senderTeamID)
	-- Default to allied scope and self as receiver for legacy calls
	return Pipeline.QueryExposeByPredicates("allied", policyType, senderTeamID, senderTeamID)
end

-- Expose pipeline introspection functions
Pipeline.Debug = {
	LogTopology = PipelineLogger.LogTopology,
	LogCacheState = PipelineLogger.LogCacheState,
	LogCacheEntry = PipelineLogger.LogCacheEntry,
	LogFullReport = PipelineLogger.LogFullReport,
}

return Pipeline
