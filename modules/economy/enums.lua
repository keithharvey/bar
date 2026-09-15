local M = {}

M.ModOptions = {
	MexSplitting = "mex_splitting",
	MexRegionsLayout = "mex_regions_layout",
}

---@alias MexSplittingKey "none"|"map_assigned"|"shared"
---@class MexSplittingFields
---@field None "none" whoever builds the mex takes the spot
---@field MapAssigned "map_assigned" the map's regions are dealt to teams at start, and a mex only goes down in a region its team holds
---@field Shared "shared" every team's extraction pools and is split back evenly

---@type MexSplittingFields
M.MexSplitting = {
	None = "none",
	MapAssigned = "map_assigned",
	Shared = "shared",
}

return M
