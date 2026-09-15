local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Sources = VFS.Include("modules/economy/lib/mex_regions/sources.lua") ---@type MexRegionSources
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local state = VFS.Include("modules/economy/state.lua") ---@type EconomyState

---@class EconomyMexRegionsApi
local MexRegions = {
	---Finds the map's layout and keeps its regions. Returns why there are none when there are none.
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

	---Runs the deal over the loaded regions, keeps the claims, and publishes them on a game rules
	---param so construction's spot holder fact, and any widget, can read the deal back.
	---@param teams MexRegionsTeamStart[]
	---@param springRepo Spring
	---@return MexRegionsClaims
	Deal = function(teams, springRepo)
		local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines
		local regions = state.mexRegions or {}
		local claims = ModuleHandler.Evaluate(pipelines.mex_regions, Claims.Context(teams, regions))
		state.mexClaims = claims
		springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, claims))
		return claims
	end,

	---Region names per team after the deal.
	---@return table<integer, string[]|nil>
	Holdings = function()
		return Claims.Holdings(state.mexRegions or {}, state.mexClaims or {})
	end,
}

---@class EconomyApi
return {
	MexRegions = MexRegions,
}
