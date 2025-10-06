local gadget = gadget ---@type Gadget
-- Repositories
local PolicyRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/policy_repository.lua")
local SpringRepository = VFS.Include("luarules/gadgets/repositories/spring_repository.lua")
local SharingModeRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/sharing_mode_repository.lua")
-- Team Transfer Main Gadget
local TeamTransferService = VFS.Include("luarules/gadgets/team_transfer/team_transfer_service.lua")


local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

function gadget:GetInfo()
	return {
		name = "Team Transfer Main",
		desc = "Manages team resource and unit transfer policies and coordination",
		author = "Daniel Harvey",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

Spring.Echo("[TEAMTRANSFER] About to check synced code")

if gadgetHandler:IsSyncedCode() then
	Spring.Echo("[TEAMTRANSFER] SYNCED - Entering synced block")

	-- Synced variables
	local TeamTransfer

	function gadget:Initialize()
		local springRepo = SpringRepository.new()

		-- Create repositories
		local sharingMode = springRepo:GetModOptions()[ModOptions.Options.SharingMode]
		local sharingModeRepo = SharingModeRepository.new()
		local config = sharingModeRepo:LoadSharingMode(sharingMode)

		local policyRepo = PolicyRepository.new()

		TeamTransfer = TeamTransferService.new(springRepo, policyRepo, sharingModeRepo, nil)

		GG.TeamTransfer = TeamTransfer
		TeamTransfer:RunPolicyInitializeHandlers()
		LogError("[TEAMTRANSFER] SYNCED - Initialize complete")
	end
	
	-- Cache refresh tracking
	local lastCacheRefresh = 0
	local CACHE_REFRESH_INTERVAL = 300
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
				TeamTransfer:Initialize()
				lastTeamCount = #currentTeams
				lastAllianceState = currentAlliances
			end
			
			lastCacheRefresh = frameNum
		end

		-- Forward GameFrame to service for cache maintenance
		if TeamTransfer and TeamTransfer.GameFrame then
			TeamTransfer:GameFrame(frameNum)
		end
	end
	
	function gadget:PlayerChanged(playerID)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerChanged %d, refreshing cache", playerID))
		if TeamTransfer and TeamTransfer.Initialize then
			TeamTransfer:Initialize()
		end
	end
	
	function gadget:PlayerAdded(playerID)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerAdded %d, refreshing cache", playerID))
		if TeamTransfer and TeamTransfer.Initialize then
			TeamTransfer:Initialize()
		end
	end
	
	function gadget:PlayerRemoved(playerID, reason)
		LogDebug(string.format("[TEAMTRANSFER] SYNCED - PlayerRemoved %d, refreshing cache", playerID))
		if TeamTransfer and TeamTransfer.Initialize then
			TeamTransfer:Initialize()
		end
	end

	-- Spring callback implementations
	function gadget:AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
		LogDebug(string.format("[TEAMTRANSFER] AllowResourceTransfer called - %s->%s, type=%s, amount=%s", 
			tostring(oldTeamID), tostring(newTeamID), tostring(resourceType), tostring(amount)))
		
		if TeamTransfer and TeamTransfer.ValidateResourceTransfer then
			local resourceTypeEnum = (resourceType == "metal") and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
			local allowed = TeamTransfer:ValidateResourceTransfer(oldTeamID, newTeamID, resourceTypeEnum, amount)
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
		
		if TeamTransfer and TeamTransfer.ValidateUnitTransfer then
			local allowed = TeamTransfer:ValidateUnitTransfer(oldTeamID, newTeamID, unitID, unitDefID)
			LogDebug(string.format("[TEAMTRANSFER] AllowUnitTransfer result: %s", tostring(allowed)))
			return allowed
		end
		return true
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		LogDebug(string.format("[TEAMTRANSFER] AllowCommand called - unitID=%s, teamID=%s, cmdID=%s, playerID=%s", 
			tostring(unitID), tostring(teamID), tostring(cmdID), tostring(playerID)))
		return true
	end

	-- Resource transfer API methods
	function gadget:SetTeamResource(senderTeamID, receiverTeamID, resourceType, desiredAmount)
		if TeamTransfer and TeamTransfer.TransferResource then
			local result = TeamTransfer:TransferResource(senderTeamID, receiverTeamID, resourceType, desiredAmount)
			-- Unpack expressive service result for Spring engine expectations
			if result.success then
				return true, result.sent, result.received
			else
				return false, 0, 0, result.reason
			end
		end
		return false, 0, 0, "TeamTransfer service not available"
	end

	-- Simple resource addition without transfer logic
	function gadget:AddTeamResource(teamID, resourceType, amount)
		if TeamTransfer and TeamTransfer.AddTeamResource then
			return TeamTransfer:AddTeamResource(teamID, resourceType, amount)
		end
		return false, 0
	end

	-- Unit transfer methods
	function gadget:TransferUnits(senderTeamID, receiverTeamID, unitIds, given)
		return TeamTransfer:TransferUnits(senderTeamID, receiverTeamID, unitIds, given)
	end


else
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
			
			-- Forward to widgets using Script.LuaUI
			if Script.LuaUI("TeamTransferExposeUpdate") then
				LogError(string.format("[TEAMTRANSFER] UNSYNCED - Forwarding to widgets via Script.LuaUI"))
				Script.LuaUI.TeamTransferExposeUpdate(teamID, exposeData)
			else
				LogError("[TEAMTRANSFER] UNSYNCED - Script.LuaUI.TeamTransferExposeUpdate not available")
			end
		end)
		
		LogError("[TEAMTRANSFER] UNSYNCED - AddSyncAction registered for TeamTransferExposeUpdate")

		-- Register clean unsynced wrappers for widgets
		gadgetHandler:RegisterGlobal("TeamTransfer_ShareUnits", function(receiverTeamID, unitIDs)
			if type(receiverTeamID) ~= "number" or type(unitIDs) ~= "table" then return end
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				if type(unitID) == "number" and Spring.ValidUnitID(unitID) and GG.TeamTransfer then
					Spring.TransferUnit(unitID, receiverTeamID, false)
				end
			end
		end)

		gadgetHandler:RegisterGlobal("TeamTransfer_AddResource", function(teamID, resourceType, amount)
			if type(teamID) ~= "number" or type(amount) ~= "number" then return end
			if GG.TeamTransfer and GG.TeamTransfer.AddTeamResource then
				return GG.TeamTransfer:AddTeamResource(teamID, resourceType, amount)
			end
		end)

		gadgetHandler:RegisterGlobal("TeamTransfer_ShareResource", function(senderTeamID, receiverTeamID, resourceType, amount)
			if type(senderTeamID) ~= "number" or type(receiverTeamID) ~= "number" or type(amount) ~= "number" then return end
			if GG.TeamTransfer and GG.TeamTransfer.TransferResource then
				return GG.TeamTransfer:TransferResource(senderTeamID, receiverTeamID, resourceType, amount)
			end
		end)
	end

	function gadget:RecvLuaMsg(msg, playerID)
		LogDebug(string.format("[TEAMTRANSFER] RecvLuaMsg called - playerID=%s, msg=%s", tostring(playerID), tostring(msg)))
		if not msg or type(msg) ~= "string" then
			LogDebug("[TEAMTRANSFER] RecvLuaMsg - Invalid message format")
			return false
		end

		-- Manual cache test function
		if msg == "test_cache_refresh" then
			LogError("[TEAMTRANSFER] MANUAL - Cache refresh test triggered by player " .. playerID)
			if GG.TeamTransfer and GG.TeamTransfer.RunPolicyInitializeHandlers then
				GG.TeamTransfer:RunPolicyInitializeHandlers()
				LogError("[TEAMTRANSFER] MANUAL - Cache refresh completed")
			else
				LogError("[TEAMTRANSFER] MANUAL - TeamTransfer.Initialize not available")
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
				
				LogError(string.format("[TEAMTRANSFER] CACHE DEBUG - Created DUMMY cache entry %s with test data", cacheKey))
				return true
			end
		end
		
		LogDebug("[TEAMTRANSFER] RecvLuaMsg - Message not handled")
		return false
	end
end
