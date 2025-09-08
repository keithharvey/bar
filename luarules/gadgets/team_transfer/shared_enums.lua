-- Shared enums for Team Transfer Framework
-- This file can be safely included from both synced and unsynced contexts

---@class TeamTransferSharedEnums
local M = {}

M.Policies = {
	AlliedReclaim = "allied_reclaim",
	AssistAlly = "assist_ally",
	BuildingUnlocksSharing = "building_unlocks_sharing",
	EnemyTransfer = "enemy_transfer",
	IdlePlayersCheck = "idle_players_check",
	MetalSendThreshold = "metal_send_threshold",
	PreventExcessiveShare = "prevent_excessive_share",
	SystemCleanup = "system_cleanup",
	TaxResourceSharing = "tax_resource_sharing",
	UnitSharingMode = "unit_sharing_mode",
}

M.Scope = {
	Allied = "allied",
	Enemy = "enemy",
}

M.TransferCategory = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer",
	CommandValidation = "command_validation",
	TeamEvents = "team_events",
}

function M.TransferCategoryToString(category)
	local map = {
		[M.TransferCategory.MetalTransfer] = "MetalTransfer",
		[M.TransferCategory.EnergyTransfer] = "EnergyTransfer",
		[M.TransferCategory.UnitTransfer] = "UnitTransfer",
		[M.TransferCategory.CommandValidation] = "CommandValidation",
		[M.TransferCategory.TeamEvents] = "TeamEvents",
	}
	return map[category] or "Unknown"
end

M.ResourceType = {
	METAL = "metal",
	ENERGY = "energy",
}

M.SharingOptions = {
	NoSharing = "no_sharing",
	BuildingUnlocks = "building_unlocks",
	LimitedSharing = "limited_sharing",
	Enabled = "enabled",
	Customize = "customize",
}

return M
