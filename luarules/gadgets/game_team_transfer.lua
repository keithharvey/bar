local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Framework',
		desc    = 'Loads TeamTransfer API and policies, handles Allow* callins, exposes via GG.TeamTransfer',
		author  = 'Devin',
		layer   = -1001,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")

function gadget:Initialize()
	---@type TeamTransferAPI
	GG.TeamTransfer = {
		RegisterPolicy = TeamTransfer.RegisterPolicy,
		PolicyType = TeamTransfer.PolicyType,
		UnitSharing = TeamTransfer.UnitSharing,
		ResourceShareTax = TeamTransfer.ResourceShareTax,
		Predicates = TeamTransfer.Predicates,
		MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS,
		IsSharingOption = TeamTransfer.IsSharingOption,
		Units = TeamTransfer.Units,
		getUnitSharingMode = TeamTransfer.UnitSharing.getUnitSharingMode,
		isT2ConstructorDef = TeamTransfer.UnitSharing.isT2ConstructorDef,
		countUnshareable = TeamTransfer.UnitSharing.countUnshareable,
		shouldShowShareButton = TeamTransfer.UnitSharing.shouldShowShareButton,
		blockMessage = TeamTransfer.UnitSharing.blockMessage,
		computeTransfer = TeamTransfer.ResourceShareTax.computeTransfer,
	}
	
	local policyFiles = VFS.DirList("luarules/gadgets/team_transfer/policies/", "*.lua")
	for _, policyFile in ipairs(policyFiles) do
		VFS.Include(policyFile)
	end
end

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	return Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	return Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	return Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
end
