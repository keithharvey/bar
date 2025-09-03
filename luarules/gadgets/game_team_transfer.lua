local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Team Transfer Main",
		desc = "Manages team resource and unit transfer policies and coordination",
		author = "BAR Team",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

Spring.Echo("[TEAMTRANSFER] About to check synced code")

if gadgetHandler:IsSyncedCode() then
	Spring.Echo("[TEAMTRANSFER] SYNCED - Entering synced block")

	-- Load logging functions
	local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
	local LogDebug = Logger.LogDebug
	local LogError = Logger.LogError

	-- Synced variables
	local TeamTransfer

	function gadget:Initialize()
		LogError("[TEAMTRANSFER] SYNCED - Initialize called")
		
		-- Load the main API and Pipeline
		LogDebug("[TEAMTRANSFER] SYNCED - Loading API and Pipeline modules")
		TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
		local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
		
		-- Expose both API and Pipeline globally
		LogDebug("[TEAMTRANSFER] SYNCED - Exposing API and Pipeline globally")
		_G.TeamTransfer = TeamTransfer
		_G.TeamTransferPipeline = Pipeline
		GG.TeamTransfer = TeamTransfer
		GG.TeamTransferPipeline = Pipeline
		
		-- Expose AllowedUnits cache for widgets to access
		if TeamTransfer and TeamTransfer.UnitSharing then
			GG.TeamTransfer.AllowedUnits = TeamTransfer.UnitSharing.getAllowedUnits and TeamTransfer.UnitSharing.getAllowedUnits() or {}
			LogDebug("[TEAMTRANSFER] SYNCED - Exposed AllowedUnits cache to GG.TeamTransfer.AllowedUnits")
		end
		
		-- Set up SendToUnsynced function for the API
		if TeamTransfer and TeamTransfer.SetSendToUnsynced then
			LogDebug("[TEAMTRANSFER] SYNCED - Setting up SendToUnsynced function")
			-- Use the global SendToUnsynced function available in synced gadget context
			TeamTransfer.SetSendToUnsynced(SendToUnsynced)
		else
			LogError("[TEAMTRANSFER] SYNCED - SetSendToUnsynced method not available")
		end
		
		-- Initialize the system
		if TeamTransfer and TeamTransfer.InitializeCache then
			LogDebug("[TEAMTRANSFER] SYNCED - Initialize cache")
			-- Force initialization for all teams to ensure GUI has data for all possible receivers
			local allTeams = Spring.GetTeamList()
			LogError(string.format("[TEAMTRANSFER] CACHE DEBUG - Forcing cache init for all teams: [%s]", table.concat(allTeams, ", ")))
			-- Call InitializeCache() without parameters to initialize for all teams
			TeamTransfer.InitializeCache()
		else
			LogError("[TEAMTRANSFER] SYNCED - Initialize cache failed - TeamTransfer or InitializeCache method not available")
		end
		
		-- Load policies (simplified for now)
		LogDebug("[TEAMTRANSFER] SYNCED - Loading policies")
		
		-- Load policies with error handling
		local policies = {
			"luarules/gadgets/team_transfer/policies/unit_sharing_mode.lua",
			"luarules/gadgets/team_transfer/policies/allied_reclaim.lua", 
			"luarules/gadgets/team_transfer/policies/enemy_transfer.lua"
		}
		
		for _, policyPath in ipairs(policies) do
			LogDebug("[TEAMTRANSFER] SYNCED - Loading policy: " .. policyPath)
			local success, err = pcall(function()
				VFS.Include(policyPath)
			end)
			if success then
				LogDebug("[TEAMTRANSFER] SYNCED - Successfully loaded: " .. policyPath)
			else
				LogError("[TEAMTRANSFER] SYNCED - Failed to load policy: " .. policyPath .. " - Error: " .. tostring(err))
			end
		end
		
		LogError("[TEAMTRANSFER] SYNCED - Initialize complete")
	end
	
	-- Cache refresh tracking
	local lastCacheRefresh = 0
	local CACHE_REFRESH_INTERVAL = 300 -- Refresh cache every 5 seconds (300 frames)
	local lastTeamCount = 0
	local lastAllianceState = {}
	
	function gadget:GameFrame(frameNum)
		-- Periodically refresh cache to pick up team/alliance changes
		if frameNum > 0 and frameNum - lastCacheRefresh > CACHE_REFRESH_INTERVAL then
			local currentTeams = Spring.GetTeamList()
			local teamCountChanged = #currentTeams ~= lastTeamCount
			
			-- Check if alliances have changed
			local allianceChanged = false
			local currentAlliances = {}
			for i, teamA in ipairs(currentTeams) do
				for j, teamB in ipairs(currentTeams) do
					if i ~= j then
						local key = teamA .. "_" .. teamB
						local allied = Spring.AreTeamsAllied(teamA, teamB)
						if lastAllianceState[key] ~= allied then
							allianceChanged = true
						end
						currentAlliances[key] = allied
					end
				end
			end
			
			-- TESTING: Force cache refresh every 5 seconds to test communication
			local forceRefresh = true  -- Remove this line once communication is verified
			
			if teamCountChanged or allianceChanged or forceRefresh then
				LogError(string.format("[TEAMTRANSFER] SYNCED - Cache refresh triggered - frame=%d, teamCount=%s, alliance=%s, forced=%s", 
					frameNum, tostring(teamCountChanged), tostring(allianceChanged), tostring(forceRefresh)))
				if TeamTransfer and TeamTransfer.InitializeCache then
					TeamTransfer.InitializeCache()
				end
				lastTeamCount = #currentTeams
				lastAllianceState = currentAlliances
			end
			
			lastCacheRefresh = frameNum
		end
	end
	
	function gadget:PlayerChanged(playerID)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerChanged %d, refreshing cache", playerID))
		-- Player changes can affect team composition, refresh cache
		if TeamTransfer and TeamTransfer.InitializeCache then
			TeamTransfer.InitializeCache()
		end
	end
	
	function gadget:PlayerAdded(playerID)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerAdded %d, refreshing cache", playerID))
		if TeamTransfer and TeamTransfer.InitializeCache then
			TeamTransfer.InitializeCache()
		end
	end
	
	function gadget:PlayerRemoved(playerID, reason)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerRemoved %d, refreshing cache", playerID))
		if TeamTransfer and TeamTransfer.InitializeCache then
			TeamTransfer.InitializeCache()
		end
	end

else -- UNSYNCED
	Spring.Echo("[TEAMTRANSFER] UNSYNCED - Unsynced side loading")

	-- Load logging functions for unsynced side
	local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
	local LogDebug = Logger.LogDebug
	local LogError = Logger.LogError

	function gadget:Initialize()
		LogDebug("[TEAMTRANSFER] UNSYNCED - Initialize called")
		
		-- Set up sync action to receive cache updates from synced side
		gadgetHandler:AddSyncAction("TeamTransferExposeUpdate", function(_, teamID, exposeData)
			LogError(string.format("[TEAMTRANSFER] UNSYNCED - Received TeamTransferExposeUpdate for team %d", teamID))
			
			-- Forward to widgets using Script.LuaUI (the correct pattern!)
			if Script.LuaUI("TeamTransferExposeUpdate") then
				LogError(string.format("[TEAMTRANSFER] UNSYNCED - Forwarding to widgets via Script.LuaUI"))
				Script.LuaUI.TeamTransferExposeUpdate(teamID, exposeData)
			else
				LogError("[TEAMTRANSFER] UNSYNCED - Script.LuaUI.TeamTransferExposeUpdate not available")
			end
		end)
		
		LogError("[TEAMTRANSFER] UNSYNCED - AddSyncAction registered for TeamTransferExposeUpdate")
	end

	-- Gadget callbacks (outside the if/else blocks)
	function gadget:RecvLuaMsg(msg, playerID)
		LogDebug(string.format("[TEAMTRANSFER] RecvLuaMsg called - playerID=%s, msg=%s", tostring(playerID), tostring(msg)))
		if not msg or type(msg) ~= "string" then
			LogDebug("[TEAMTRANSFER] RecvLuaMsg - Invalid message format")
			return false
		end

		-- Manual cache test function
		if msg == "test_cache_refresh" then
			LogError("[TEAMTRANSFER] MANUAL - Cache refresh test triggered by player " .. playerID)
			if TeamTransfer and TeamTransfer.InitializeCache then
				TeamTransfer.InitializeCache()
				LogError("[TEAMTRANSFER] MANUAL - Cache refresh completed")
			else
				LogError("[TEAMTRANSFER] MANUAL - TeamTransfer.InitializeCache not available")
			end
			return true
		end

		local msgType, data = msg:match("^(%w+):(.+)$")
		LogDebug(string.format("[TEAMTRANSFER] RecvLuaMsg - msgType=%s, data=%s", tostring(msgType), tostring(data)))
		if msgType == "query_unit_pair" then
			local senderTeamID, receiverTeamID = data:match("^(%d+),(%d+)$")
			if senderTeamID and receiverTeamID then
				senderTeamID = tonumber(senderTeamID)
				receiverTeamID = tonumber(receiverTeamID)
				LogDebug(string.format("[TEAMTRANSFER] RecvLuaMsg - Processing query_unit_pair %d->%d", senderTeamID, receiverTeamID))
				
				-- Store dummy result for now
				if not GG.TeamTransferCache then
					GG.TeamTransferCache = {}
				end
				
				local cacheKey = string.format("team_%d_to_%d", senderTeamID, receiverTeamID)
				GG.TeamTransferCache[cacheKey] = {
					canShareMetal = false,
					canShareEnergy = false,
					canShareUnits = false,
					blockReason = senderTeamID == receiverTeamID and "Invalid: self-transfer" or "Test data"
				}
				LogDebug(string.format("[TEAMTRANSFER] RecvLuaMsg - Cached result for %s", cacheKey))
				
				-- CRITICAL CACHE DEBUGGING: Log the dummy cache creation
				LogError(string.format("[TEAMTRANSFER] CACHE DEBUG - Created DUMMY cache entry %s with test data", cacheKey))
				return true
			end
		end
		
		LogDebug("[TEAMTRANSFER] RecvLuaMsg - Message not handled")
		return false
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		LogDebug(string.format("[TEAMTRANSFER] AllowCommand called - unitID=%s, teamID=%s, cmdID=%s, playerID=%s", 
			tostring(unitID), tostring(teamID), tostring(cmdID), tostring(playerID)))
		if TeamTransfer and TeamTransfer.AllowCommand then
			return TeamTransfer.AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		end
		return true
	end

	function gadget:AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
		LogDebug(string.format("[TEAMTRANSFER] AllowResourceTransfer called - %s->%s, type=%s, amount=%s", 
			tostring(oldTeamID), tostring(newTeamID), tostring(resourceType), tostring(amount)))
		
		-- Use validator pattern: let policies decide based on current context
		if TeamTransfer and TeamTransfer.AllowResourceTransfer then
			local allowed = TeamTransfer.AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
			LogDebug(string.format("[TEAMTRANSFER] AllowResourceTransfer result: %s", tostring(allowed)))
			return allowed
		end
		return true
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeamID, newTeamID, capture)
		LogDebug(string.format("[TEAMTRANSFER] AllowUnitTransfer called - unitID=%s, %s->%s, capture=%s", 
			tostring(unitID), tostring(oldTeamID), tostring(newTeamID), tostring(capture)))
		
		if capture then
			return true  -- Captures always allowed
		end
		
		-- Use validator pattern: let policies decide based on current context
		if TeamTransfer and TeamTransfer.AllowUnitTransfer then
			local allowed = TeamTransfer.AllowUnitTransfer(unitID, unitDefID, oldTeamID, newTeamID, capture)
			LogDebug(string.format("[TEAMTRANSFER] AllowUnitTransfer result: %s", tostring(allowed)))
			return allowed
		end
		return true
	end
end