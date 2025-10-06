-- Shared enums for Team Transfer Framework
-- This file can be safely included from both synced and unsynced contexts

---@class TeamTransferSharedEnums
local M = {}

M.TransferCategory = {
	MetalTransfer = "metal_transfer",
	EnergyTransfer = "energy_transfer",
	UnitTransfer = "unit_transfer",
	GuardTransfer = "guard_transfer",
	RepairTransfer = "repair_transfer",
	ReclaimTransfer = "reclaim_transfer",
}

M.Policies = {
	AlliedReclaim = "allied_reclaim",
	AssistAlly = "assist_ally",
	BuildingUnlocksSharing = "building_unlocks_sharing",
	EnemyReclaim = "enemy_reclaim",
	SystemCleanup = "system_cleanup",
	TaxResourceSharing = "tax_resource_sharing",
	TaxRate = "tax_resource_sharing_rate",
	UnitSharingMode = "unit_sharing_mode",
}

M.BlockReason = {
	NoPolicy = "no_policy",
	PolicyDenied = "policy_denied",
	UnitSharingMode = "unit_sharing_mode",
	AssistAlly = "assist_ally",
}

M.Scope = {
	Allied = "allied",
	Enemy = "enemy",
}


M.ResourceType = {
	METAL = "metal",
	ENERGY = "energy",
}

---@alias SharingMode
---| "no_sharing"
---| "building_unlocks"
---| "limited_sharing"
---| "enabled"
---| "customize"

M.SharingModes = {
	NoSharing = "no_sharing",
	BuildingUnlocks = "building_unlocks",
	LimitedSharing = "limited_sharing",
	Enabled = "enabled",
	Customize = "customize",
}

M.UnitSharingMode = {
	CombatUnits = "combat_units",
	CombatT2Cons = "combat_t2cons",
	Disabled = "disabled",
	Economic = "economic",
	EconomicPlusBuildings = "economic_buildings",
	Enabled = "enabled",
	T2Cons = "t2cons"
}

M.AssistAllyMode = {
	Disabled = "disabled",
	Enabled = "enabled"
}

M.AlliedReclaimMode = {
	Disabled = "disabled",
	Enabled = "enabled"
}

M.BuildingUnlocksSharingMode = {
	Disabled = "disabled",
	Enabled = "enabled"
}

M.UnitType = {
	Economic = "economic",
	Combat = "combat",
	T2Constructor = "t2cons",
	Utility = "utility"
}



return M
