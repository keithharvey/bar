local gadget = gadget ---@type Gadget
-- Repositories
local PolicyRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/policy_repository.lua")
local SpringRepository = VFS.Include("luarules/gadgets/repositories/spring_repository.lua")
local SharingModeRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/sharing_mode_repository.lua")
-- Team Transfer Main Gadget
local TeamTransferService = VFS.Include("luarules/gadgets/team_transfer/team_transfer_service.lua")

-- Logging
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

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

	function gadget:Shutdown()
		gadgetHandler:DeregisterGlobal("TeamTransfer_TransferUnits")
		gadgetHandler:DeregisterGlobal("TeamTransfer_AddResource")
		gadgetHandler:DeregisterGlobal("TeamTransfer_ShareResource")
	end

	function RegisterGlobals()
		gadgetHandler:RegisterGlobal("TeamTransfer_TransferUnits", function(receiverTeamId, unitIDs)
			local senderTeamId = Spring.GetMyTeamID()
			GG.TeamTransfer:TransferUnits(senderTeamId, receiverTeamId, unitIDs)
		end)

		gadgetHandler:RegisterGlobal("TeamTransfer_AddResource", function(teamID, resourceType, amount)
			return GG.TeamTransfer:AddTeamResource(teamID, resourceType, amount)
		end)

		gadgetHandler:RegisterGlobal("TeamTransfer_ShareResource", function(senderTeamID, receiverTeamID, resourceType, amount)
			return GG.TeamTransfer:TransferResource(senderTeamID, receiverTeamID, resourceType, amount)
		end)
	end

	----------------------------------
	-- Gadget/Widget API
	----------------------------------
	

	----------------------------------
	-- Spring Callbacks
	----------------------------------
	function gadget:AllowResourceTransfer(oldTeamID, newTeamID, resourceType, amount)
		local resourceTypeEnum = (resourceType == "metal") and SharedEnums.ResourceType.METAL or SharedEnums.ResourceType.ENERGY
		local allowed = TeamTransfer:ValidateResourceTransfer(oldTeamID, newTeamID, resourceTypeEnum, amount)
		return allowed
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeamID, newTeamID, capture)
		if capture then
			return true
		end
		
		local allowed = TeamTransfer:ValidateUnitTransfer(oldTeamID, newTeamID, unitID, unitDefID)
		return allowed
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		local allowed, reason = TeamTransfer:ValidateCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID)
		return allowed
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
else -- Unsynced code

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("TeamTransferExposeUpdate", function(_, teamID, exposeData)
			if Script.LuaUI("TeamTransferExposeUpdate") then
				Script.LuaUI.TeamTransferExposeUpdate(teamID, exposeData)
			end
		end)
	end
end
