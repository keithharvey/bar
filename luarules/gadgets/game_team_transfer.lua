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

-- Spring function shortcuts
local spGetPlayerInfo = Spring.GetPlayerInfo

-- Player monitoring state
local monitorPlayers = {}

function gadget:Initialize()
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "Initialize starting...")
	
	---@type TeamTransferAPI
	GG.TeamTransfer = {
		-- External API - what other code actually needs
		RegisterPolicy = TeamTransfer.RegisterPolicy,
		Enums = TeamTransfer.SharedEnums,
		UnitSharing = TeamTransfer.UnitSharing, -- Main unit sharing functionality
		
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
	
	-- Initialize the pipeline for all active teams
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		local _, _, isDead, isAI = Spring.GetTeamInfo(teamID)
		if not isDead then
			-- Initialize both resource and unit transfer pipelines for this team
			TeamTransfer.InitializeCache(teamID)
		end
	end
	
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
		TeamTransfer.QueryTeamState("ResourceTransfer", teamID)
		TeamTransfer.QueryTeamState("UnitTransfer", teamID)
		return true
	end
	return false
end

local function updateTeamResourceState(teamID)
	-- Query team state for both resource and unit transfers
	-- Policies will expose state for all relevant resources (metal, energy, etc.)
	TeamTransfer.QueryTeamState(teamID, TeamTransfer.PolicyType.ResourceTransfer)
	TeamTransfer.QueryTeamState(teamID, TeamTransfer.PolicyType.UnitTransfer)
end

local function initializeTeamStates()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		-- Pre-populate resource transfer state for UI
		updateTeamResourceState(teamID)
	end
end

-- Engine hooks to keep cache updated
function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	-- Unit transfer affects both teams' state
	updateTeamResourceState(newTeam)
	if newTeam ~= oldTeam then
		updateTeamResourceState(oldTeam)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	-- Unit transfer affects both teams' state  
	updateTeamResourceState(newTeam)
	if newTeam ~= oldTeam then
		updateTeamResourceState(oldTeam)
	end
end

function gadget:TeamDied(teamID)
	-- Team death might affect sharing rules
	updateTeamResourceState(teamID)
end

-- Functions already defined above, initialization already called



function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "AllowResourceTransfer callin triggered: " .. tostring(senderTeamId) .. " -> " .. tostring(receiverTeamId) .. " " .. tostring(resourceType) .. " " .. tostring(amount))
	
	-- Run the pipeline for the actual transfer
	local result = Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	
	-- Event-driven cache invalidation: update state for affected teams after transfer
	if result then -- Transfer was allowed
		updateTeamResourceState(senderTeamId) -- Sender's state changed (resources sent)
		if senderTeamId ~= receiverTeamId then
			updateTeamResourceState(receiverTeamId) -- Receiver's state changed (resources received)
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
	-- Refresh cache periodically (every 5 seconds) to handle edge cases
	if gameFrame % 150 == 0 then
		local teamList = Spring.GetTeamList()
		for _, teamID in ipairs(teamList) do
			updateTeamResourceState(teamID)
		end
	end
	
	-- Check player activity every 30 frames to reduce overhead
	if gameFrame % 30 == 0 then
		local active, spec, teamID
		for playerID, prevActive in pairs(monitorPlayers) do
			_, active, spec, teamID = spGetPlayerInfo(playerID, false)
			if spec then
				-- Player went spectator - trigger abandonment event
				Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, gameFrame)
				monitorPlayers[playerID] = nil
			elseif active ~= prevActive then
				if not active then
					-- Player disconnected - trigger abandonment event
					Pipeline.RunTeamEvent("PlayerAbandoned", teamID, playerID, gameFrame)
				elseif active and not prevActive then
					-- Player reconnected
					Pipeline.RunTeamEvent("PlayerReconnected", teamID, playerID, gameFrame)
				end
				monitorPlayers[playerID] = active
			end
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