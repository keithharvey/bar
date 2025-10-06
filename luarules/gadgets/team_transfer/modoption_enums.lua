-- Mod Options for Team Transfer Framework
-- This file can be safely included from both synced and unsynced contexts

---@class TeamTransferModOptions
local M = {}

M.Options = {
	-- Unit sharing options
	UnitSharingMode = "unit_sharing_mode",
	BuildingUnlocksSharing = "building_unlocks_sharing",

	-- Resource sharing options
	TaxResourceSharingAmount = "tax_resource_sharing_amount",
	PlayerMetalSendThreshold = "player_metal_send_threshold",
	PlayerEnergySendThreshold = "player_energy_send_threshold",

	-- Allied construction options
	AlliedAssist = "allied_assist",
	AlliedReclaim = "allied_reclaim",

	-- System options
	SharingMode = "sharing_mode",
}

return M
