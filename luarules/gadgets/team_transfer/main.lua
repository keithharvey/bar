local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Framework',
		desc    = 'Primary handler for Team Transfer policies/pipeline',
		author  = 'Devin',
		date    = 'Aug 2025',
		license = 'GNU GPL, v2 or later',
		layer   = -1000,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
local Pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
local PolicyManager = VFS.Include("luarules/gadgets/team_transfer/policy_manager.lua")

local function loadPolicyConfigurations()
	VFS.Include("luarules/gadgets/team_transfer/policies/enemy_transfer.lua")
	VFS.Include("luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua")
	VFS.Include("luarules/gadgets/team_transfer/policies/unit_sharing_mode.lua")
	VFS.Include("luarules/gadgets/team_transfer/policies/assist_ally.lua")
end

function gadget:Initialize()
	loadPolicyConfigurations()
	PolicyManager.applyPolicies()
	
	---@type TeamTransferAPI
	GG.TeamTransfer = {
		UnitSharing = TeamTransfer.UnitSharing,
		ResourceShareTax = TeamTransfer.ResourceShareTax,
		Predicates = TeamTransfer.Predicates,
		getUnitSharingMode = TeamTransfer.UnitSharing.getUnitSharingMode,
		isT2ConstructorDef = TeamTransfer.UnitSharing.isT2ConstructorDef,
		countUnshareable = TeamTransfer.UnitSharing.countUnshareable,
		shouldShowShareButton = TeamTransfer.UnitSharing.shouldShowShareButton,
		blockMessage = TeamTransfer.UnitSharing.blockMessage,
		computeTransfer = TeamTransfer.ResourceShareTax.computeTransfer,
	}
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
