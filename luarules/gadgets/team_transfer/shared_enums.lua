-- Shared enums for Team Transfer Framework
-- This file can be safely included from both synced and unsynced contexts

---@class TeamTransferSharedEnums
local M = {}

M.Policies = {
	AlliedReclaim = "allied_reclaim",
	AssistAlly = "assist_ally",
	EnemyTransfer = "enemy_transfer",
	IdlePlayersCheck = "idle_players_check",
	MetalSendThreshold = "metal_send_threshold",
	PreventExcessiveShare = "prevent_excessive_share",
	SystemCleanup = "system_cleanup",
	TaxResourceSharing = "tax_resource_sharing",
	UnitSharingMode = "unit_sharing_mode",
}

M.PolicyType = {
	ResourceTransfer = "resource_transfer",
	UnitTransfer = "unit_transfer",
	Command = "command",
	TeamEvent = "team_event",
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

M.ResourceType = {
	Metal = "metal",
	Energy = "energy",
}

return M
