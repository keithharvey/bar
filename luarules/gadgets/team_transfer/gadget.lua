local gadget = gadget ---@type Gadget
-- Repositories
local PolicyRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/policy_repository.lua")
local SpringRepository = VFS.Include("luarules/gadgets/repositories/spring_repository.lua")
local SharingModeRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/sharing_mode_repository.lua")
-- Team Transfer Main Gadget
local TeamTransferService = VFS.Include("luarules/gadgets/team_transfer/team_transfer_service.lua")

-- Logging
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
local LogDebug = Logger.LogDebug
local LogError = Logger.LogError

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

if gadgetHandler:IsSyncedCode() then
	---@type TeamTransferService
	local TeamTransfer

	function gadget:Initialize()
		local springRepo = SpringRepository.new()
		local policyRepo = PolicyRepository.new()
		local sharingModeRepo = SharingModeRepository.new()

		TeamTransfer = TeamTransferService.new(springRepo, policyRepo, sharingModeRepo, nil)
		GG.TeamTransfer = TeamTransfer

		RegisterGlobals()
	end
	
	function RegisterGlobals()
		gadgetHandler:RegisterGlobal("TeamTransfer_TransferUnits", function(receiverTeamId, unitIDs)
			local senderTeamId = Spring.GetMyTeamID()
			GG.TeamTransfer:TransferUnits(senderTeamId, receiverTeamId, unitIDs)
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
	
	function gadget:GameFrame(frameNum)
		if TeamTransfer and TeamTransfer.GameFrame then
			TeamTransfer:GameFrame(frameNum)
		end
	end
	
	function gadget:PlayerChanged(playerID)
		-- Cache is maintained automatically every 300 frames
	end

	function gadget:PlayerAdded(playerID)
		-- Cache is maintained automatically every 300 frames
	end

	function gadget:PlayerRemoved(playerID, reason)
		-- Cache is maintained automatically every 300 frames
	end

	-- Spring callback implementations
	function gadget:AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
		local resourceTypeEnum = (resourceType == "metal") and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
		local allowed = TeamTransfer:ValidateResourceTransfer(oldTeamID, newTeamID, resourceTypeEnum, amount)
		return allowed
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeamID, newTeamID, capture)
		if capture then
			return true  -- Captures always allowed
		end
		
		local allowed = TeamTransfer:ValidateUnitTransfer(oldTeamID, newTeamID, unitID, unitDefID)
		return allowed
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		-- Use team transfer service for command validation

		local allowed, reason = TeamTransfer:ValidateCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID)
		return allowed
	end


	-- Gadget API methods
	--------------------------------

	-- Resource transfer API methods
	function gadget:SetTeamResource(senderTeamID, receiverTeamID, resourceType, desiredAmount)
		local result = TeamTransfer:TransferResource(senderTeamID, receiverTeamID, resourceType, desiredAmount)
		-- Unpack expressive service result for Spring engine expectations
		if result.success then
			return true, result.sent, result.received
		else
			return false, 0, 0, result.reason or result.blockReason or "Transfer failed"
		end
	end

	-- Simple resource addition without transfer logic
	function gadget:AddTeamResource(teamID, resourceType, amount)
		if TeamTransfer and TeamTransfer.AddTeamResource then
			local result = TeamTransfer:AddTeamResource(teamID, resourceType, amount)
			-- Unpack expressive service result for Spring engine expectations
			if result.success then
				return true, result.received
			else
				return false, 0
			end
		end
		return false, 0
	end

	-- Unit transfer methods
	function gadget:TransferUnits(senderTeamID, receiverTeamID, unitIds, given)
		if TeamTransfer and TeamTransfer.TransferUnits then
			local result = TeamTransfer:TransferUnits(senderTeamID, receiverTeamID, unitIds, given)
			-- Unpack expressive service result for Spring engine expectations
			return result.success
		end
		return false
	end


else
	Spring.Echo("[TEAMTRANSFER] UNSYNCED - Unsynced side loading")


	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TeamTransferExposeUpdate", function(_, teamID, exposeData)
			LogError(string.format("[TEAMTRANSFER] UNSYNCED - Received TeamTransferExposeUpdate for team %d", teamID))
			
			if Script.LuaUI("TeamTransferExposeUpdate") then
				LogError(string.format("[TEAMTRANSFER] UNSYNCED - Forwarding to widgets via Script.LuaUI"))
				Script.LuaUI.TeamTransferExposeUpdate(teamID, exposeData)
			end
		end)
	end
end
