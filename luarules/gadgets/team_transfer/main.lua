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

local function registerPolicies()
	VFS.Include("luarules/gadgets/team_transfer/game_enemy_transfer.lua")
	VFS.Include("luarules/gadgets/team_transfer/game_tax_resource_sharing.lua")
	VFS.Include("luarules/gadgets/team_transfer/game_unit_sharing_mode.lua")
	VFS.Include("luarules/gadgets/team_transfer/game_disable_assist_ally_construction.lua")
end

function gadget:Initialize()
	registerPolicies()
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
