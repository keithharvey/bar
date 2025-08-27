---@class TeamTransferGadget : Gadget
local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer',
		desc    = 'Loads TeamTransfer API and policies, handles Allow* callins, exposes via GG.TeamTransfer',
		author  = 'Devin',
		layer   = -1001,
		enabled = true,
	}
end
Spring.Log("team transfer", LOG.ERROR,"[Team Transfer]!!!!!! INSIDE")



-- Only load in synced context to prevent policy loading in unsynced context
if not gadgetHandler:IsSyncedCode() then
	return
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
	local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
	local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")
	local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
	
	-- Make pipeline available globally to avoid circular dependencies
_G.TeamTransferPipeline = Pipeline

-- Handle widget transfer requests via SyncAction
local function handleWidgetTransferRequest(actionName, data)
	if actionName == "TeamTransferShareEnergy" then
		-- Execute energy sharing with policy validation
		local maxAmount = Pipeline.RunAllowResourceTransfer(
			data.senderTeamID, data.receiverTeamID, 
			SharedEnums.ResourceType.ENERGY, data.amount
		)
		if maxAmount > 0 then
			local finalAmount = math.min(data.amount, maxAmount)
			Spring.ShareResources(data.receiverTeamID, "energy", finalAmount)
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..finalAmount..':name='..data.receiverName)
			PolicyHooks.NotifyPostTransfer({
				senderTeamID = data.senderTeamID,
				receiverTeamID = data.receiverTeamID,
				resourceType = "energy",
				amount = finalAmount
			})
		end
		
	elseif actionName == "TeamTransferShareMetal" then
		-- Execute metal sharing with policy validation
		local maxAmount = Pipeline.RunAllowResourceTransfer(
			data.senderTeamID, data.receiverTeamID, 
			SharedEnums.ResourceType.METAL, data.amount
		)
		if maxAmount > 0 then
			local finalAmount = math.min(data.amount, maxAmount)
			Spring.ShareResources(data.receiverTeamID, "metal", finalAmount)
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveMetal:amount='..finalAmount..':name='..data.receiverName)
			PolicyHooks.NotifyPostTransfer({
				senderTeamID = data.senderTeamID,
				receiverTeamID = data.receiverTeamID,
				resourceType = "metal",
				amount = finalAmount
			})
		end
		
	elseif actionName == "TeamTransferShareUnits" then
		-- Execute unit sharing with policy validation
		local allowedUnits = {}
		for _, unitID in ipairs(data.selectedUnitIDs) do
			if Spring.ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == data.senderTeamID then
				local allowed = Pipeline.RunAllowUnitTransfer(data.senderTeamID, data.receiverTeamID, unitID)
				if allowed then
					allowedUnits[#allowedUnits + 1] = unitID
				end
			end
		end
		
		local sharedCount = 0
		for _, unitID in ipairs(allowedUnits) do
			if Spring.TransferUnit(unitID, data.receiverTeamID, false) then
				sharedCount = sharedCount + 1
			end
		end
		
		if sharedCount > 0 then
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveUnits:count='..sharedCount..':name='..data.receiverName)
			PolicyHooks.NotifyPostTransfer({
				senderTeamID = data.senderTeamID,
				receiverTeamID = data.receiverTeamID,
				unitIDs = allowedUnits,
				sharedCount = sharedCount
			})
		end
	end
end

-- Register SyncAction handler for widget requests
if gadgetHandler and gadgetHandler.RegisterSyncAction then
	gadgetHandler:RegisterSyncAction("TeamTransfer", handleWidgetTransferRequest)
end

-- Spring function shortcuts
local spGetPlayerInfo = Spring.GetPlayerInfo

-- Player monitoring state
local monitorPlayers = {}

-- Debounced cache invalidation system
local teamsNeedingCacheUpdate = {}
local cacheUpdateScheduled = false

function gadget:Initialize()
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Initialize starting...")
	
	---@type TeamTransferGadgetAPI
	GG.TeamTransfer = {
		-- External API - what other code actually needs
		RegisterPolicy = TeamTransfer.RegisterPolicy,
		Enums = SharedEnums,
		UnitSharing = TeamTransfer.UnitSharing,
		
		-- Hook registration interface
		RegisterInitialize = PolicyHooks.RegisterInitialize,
		RegisterPreProcess = PolicyHooks.RegisterPreProcess,
		RegisterPostTransfer = PolicyHooks.RegisterPostTransfer,
		RegisterValidator = PolicyHooks.RegisterValidator,
		NotifyPostTransfer = PolicyHooks.NotifyPostTransfer,
		
		-- Debug interface for console commands
		Debug = Pipeline.Debug,
	}
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "GG.TeamTransfer set up, loading policies...")
	
	local policyDir = "luarules/gadgets/team_transfer/policies/"
	local policyFiles = VFS.DirList(policyDir, "*.lua")
	Spring.Log("team transfer", LOG.ERROR, "[Team Transfer] policies found=" .. tostring(#policyFiles) .. " dir=" .. policyDir)
	for _, policyFile in ipairs(policyFiles) do
		Spring.Log("team transfer", LOG.ERROR, "[Team Transfer] including policy=" .. policyFile)
		VFS.Include(policyFile)
		Spring.Log("team transfer", LOG.ERROR, "[Team Transfer] included policy=" .. policyFile)
	end
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Policies loaded, initializing pipeline...")
	
	-- Skip initialization during loading to prevent circular dependencies
	-- Cache will be populated lazily on first actual usage
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Deferring team cache initialization until after full load")
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Pipeline initialized, setting up player monitoring...")
	
	-- Initialize player monitoring
	local players = Spring.GetPlayerList()
	for _, playerID in pairs(players) do
		local _, active, spec, teamID = spGetPlayerInfo(playerID, false)
		local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
		if isDead == 0 and not isAiTeam then
			if active and not spec then
				monitorPlayers[playerID] = true 
			end
		end
	end

	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Player monitoring set up, registering commands...")
	-- Register only the commands this gadget needs to check to avoid CMD.ANY autoregistration
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Initialize completed successfully!")
end

-- Debug chat command for manual cache initialization
function gadget:GotChatMsg(msg, playerID)
	if msg == "!teamtransfer init" then
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Manual initialization requested by player " .. playerID .. " (team " .. teamID .. ")")
		TeamTransfer.InitializeCache() -- Initialize all teams
		return true
	elseif msg:match("^!teamtransfer init (%d+)$") then
		local targetTeam = tonumber(msg:match("^!teamtransfer init (%d+)$"))
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Manual initialization for team " .. targetTeam .. " requested by player " .. playerID .. " (team " .. teamID .. ")")
		TeamTransfer.InitializeCache(targetTeam)
		return true
	elseif msg == "!teamtransfer test" then
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Manual pipeline test requested by player " .. playerID .. " (team " .. teamID .. ")")
		-- Test both ResourceTransfer and UnitTransfer pipelines
		queryTeamResourceState(teamID)
	elseif msg == "!teamtransfer pipeline" then
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Pipeline state dump requested by player " .. playerID .. " (team " .. teamID .. ")")
		GG.TeamTransfer.Debug.LogFullReport()
		return true
	elseif msg == "!teamtransfer cache" then
		local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Cache state dump requested by player " .. playerID .. " (team " .. teamID .. ")")
		GG.TeamTransfer.Debug.LogCacheState()
		return true
	end
	return false
end

local function queryTeamResourceState(teamID)
	-- Query team state for both resource and unit transfers
	-- Policies will expose state for all relevant resources (metal, energy, etc.)
	TeamTransfer.QueryTeamState(teamID, TeamTransfer.PolicyType.ResourceTransfer)
	TeamTransfer.QueryTeamState(teamID, TeamTransfer.PolicyType.UnitTransfer)
end

-- Schedule cache update for a team (debounced)
local function scheduleTeamCacheUpdate(teamID)
	teamsNeedingCacheUpdate[teamID] = true
	if not cacheUpdateScheduled then
		cacheUpdateScheduled = true
		-- Update cache in ~1 second to debounce rapid events
		Spring.Echo("TEAM TRANSFER DEBUG: Scheduled cache update for team " .. teamID .. " in ~1 second")
	end
end

-- Process all pending cache updates
local function processPendingCacheUpdates()
	if not cacheUpdateScheduled then return end
	
	for teamID, _ in pairs(teamsNeedingCacheUpdate) do
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Updating cache for team " .. teamID)
		-- Invalidate and rebuild cache for this team
		TeamTransfer.InitializeCache(teamID)
		queryTeamResourceState(teamID) -- Refresh expose data
	end
	
	-- Clear pending updates
	teamsNeedingCacheUpdate = {}
	cacheUpdateScheduled = false
end

local function initializeTeamStates()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		-- Pre-populate resource transfer state for UI
		queryTeamResourceState(teamID)
	end
end

-- Engine hooks to keep cache updated
function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	-- Unit transfer affects both teams' cache - schedule debounced update
	scheduleTeamCacheUpdate(newTeam)
	if newTeam ~= oldTeam then
		scheduleTeamCacheUpdate(oldTeam)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	-- Unit transfer affects both teams' cache - schedule debounced update
	scheduleTeamCacheUpdate(newTeam)
	if newTeam ~= oldTeam then
		scheduleTeamCacheUpdate(oldTeam)
	end
end

function gadget:TeamDied(teamID)
	-- Team death affects sharing rules - schedule cache update
	scheduleTeamCacheUpdate(teamID)
end

-- Functions already defined above, initialization already called



function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "AllowResourceTransfer callin triggered: " .. tostring(senderTeamId) .. " -> " .. tostring(receiverTeamId) .. " " .. tostring(resourceType) .. " " .. tostring(amount))
	
	-- Run the pipeline for the actual transfer
	local result = Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	
	-- Event-driven cache invalidation: schedule updates for affected teams after transfer
	if result then -- Transfer was allowed
		scheduleTeamCacheUpdate(senderTeamId) -- Sender's state changed (resources sent)
		if senderTeamId ~= receiverTeamId then
			scheduleTeamCacheUpdate(receiverTeamId) -- Receiver's state changed (resources received)
		end
	end
	
	return result
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	return Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	return Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
end

-- Player monitoring for team abandonment events
local monitorPlayers = {}

function gadget:GameFrame(gameFrame)
	-- Process debounced cache updates every 30 frames (~1 second at 30 FPS)
	if gameFrame % 30 == 0 then
		processPendingCacheUpdates()
	end
	
	-- Refresh cache periodically (every 5 seconds) to handle edge cases
	if gameFrame % 150 == 0 then
		local teamList = Spring.GetTeamList()
		for _, teamID in ipairs(teamList) do
			scheduleTeamCacheUpdate(teamID)
		end
	end
end

function gadget:PlayerAdded(playerID)
	local _, active, spec, teamID = spGetPlayerInfo(playerID, false)
	local leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
	if isDead == 0 and not isAiTeam then
		if active and not spec then
			monitorPlayers[playerID] = true
		end
	end
end

function gadget:PlayerRemoved(playerID, reason)
	local _, _, spec, teamID = spGetPlayerInfo(playerID, false)
	if monitorPlayers[playerID] and not spec then
		Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, Spring.GetGameFrame())
	end
	monitorPlayers[playerID] = nil
end

-- Console command interface for pipeline debugging
function gadget:TextCommand(command)
	if command == "pipeline_topology" then
		GG.TeamTransfer.Debug.LogTopology()
		return true
	elseif command == "pipeline_cache" then
		GG.TeamTransfer.Debug.LogCacheState()
		return true
	elseif command == "pipeline_report" then
		GG.TeamTransfer.Debug.LogFullReport()
		return true
	elseif string.match(command, "^pipeline_entry%s+") then
		-- Parse: pipeline_entry <scope> <policyType> <senderID> <receiverID>
		local parts = {}
		for part in string.gmatch(command, "%S+") do
			table.insert(parts, part)
		end
		
		if #parts == 5 then
			local scope = parts[2]
			local policyType = parts[3]
			local senderID = tonumber(parts[4])
			local receiverID = tonumber(parts[5])
			
			if senderID and receiverID then
				GG.TeamTransfer.Debug.LogCacheEntry(scope, policyType, senderID, receiverID)
				return true
			end
		end
		
		Spring.Log("PIPELINE DEBUG", "info", "Usage: pipeline_entry <scope> <policyType> <senderID> <receiverID>")
		Spring.Log("PIPELINE DEBUG", "info", "Example: pipeline_entry allied resource_transfer 0 1")
		return true
	end
	
	return false
end

-- Initialize team caches after game starts (safe from circular dependencies)
function gadget:GameStart()
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Game started, initializing team caches now")
	
	-- Now it's safe to initialize team caches
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		local _, _, isDead, isAI = Spring.GetTeamInfo(teamID)
		if not isDead then
			-- Initialize both resource and unit transfer pipelines for this team
			TeamTransfer.InitializeCache(teamID)
			Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Initialized cache for team " .. teamID)
		end
	end
	
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Team transfer system fully active")
end