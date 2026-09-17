local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Sources = VFS.Include("modules/economy/lib/mex_regions/sources.lua") ---@type MexRegionSources
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
local state = VFS.Include("modules/economy/state.lua") ---@type EconomyState

---@class EconomyMexRegionsApi
local MexRegions = {
	---@param springRepo Spring
	---@return MexRegion[]|nil regions
	---@return string source
	---@return string|nil reason
	Load = function(springRepo)
		local regions, source, reason =
			Sources.Load(springRepo.GetModOptions(), Game.mapName, Game.mapSizeX, Game.mapSizeZ)
		state.mexRegions = regions
		state.mexRegionsSource = source
		return regions, source, reason
	end,

	---@return MexRegion[] the loaded layout's regions; none before Load
	Regions = function()
		return state.mexRegions or {}
	end,

	---@param teams MexRegionsTeamStart[]
	---@param springRepo Spring
	---@param spots { x: number, z: number }[] the map's metal spots
	---@return MexRegionsDeal
	Deal = function(teams, springRepo, spots)
		local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines
		local regions = state.mexRegions or {}
		---@type MexRegionsDealContext
		local ctx = { regions = regions, spots = spots or {}, teams = teams }
		local deal = ModuleHandler.Evaluate(pipelines.mex_regions, ctx)
		state.mexDeal = deal
		springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, deal.regions))

		local holdings = Claims.Holdings(regions, deal.regions)
		local keysOf = {} ---@type table<integer, string[]>
		for key, teamID in pairs(deal.spots) do
			keysOf[teamID] = keysOf[teamID] or {}
			table.insert(keysOf[teamID], key)
		end
		for _, team in ipairs(teams) do
			local keys = keysOf[team.teamID] or {}
			table.sort(keys)
			Shared.Holdings.Write(springRepo, team.teamID, { regions = holdings[team.teamID] or {}, spots = keys })
		end
		return deal
	end,

	---@return table<integer, string[]|nil> teamID -> the ids of the regions it holds
	Holdings = function()
		return Claims.Holdings(state.mexRegions or {}, state.mexDeal and state.mexDeal.regions or {})
	end,
}

---@class EconomyApi
return {
	MexRegions = MexRegions,
}
