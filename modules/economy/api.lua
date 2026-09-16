local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Sources = VFS.Include("modules/economy/lib/mex_regions/sources.lua") ---@type MexRegionSources
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
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

	---@param teams MexRegionsTeamStart[]
	---@param springRepo Spring
	---@param spots { x: number, z: number }[] the map's metal spots
	---@return MexRegionsClaims
	Deal = function(teams, springRepo, spots)
		local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines
		local regions = state.mexRegions or {}
		local claims = ModuleHandler.Evaluate(pipelines.mex_regions, Claims.Context(teams, regions))
		state.mexClaims = claims
		springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, claims))

		local spotsOf = {} ---@type table<string, string[]> region id -> spot keys
		local unclaimed, twice = 0, 0
		for _, spot in ipairs(spots or {}) do
			local owners = 0
			for _, region in ipairs(regions) do
				local ring = {}
				for i, p in ipairs(region.polygon) do
					ring[i] = { x = p[1], z = p[2] }
				end
				if Geometry.Contains(spot.x, spot.z, ring) then
					owners = owners + 1
					spotsOf[region.id] = spotsOf[region.id] or {}
					table.insert(spotsOf[region.id], Shared.SpotKey(spot.x, spot.z))
				end
			end
			if owners == 0 then
				unclaimed = unclaimed + 1
			elseif owners > 1 then
				twice = twice + 1
			end
		end
		if unclaimed > 0 or twice > 0 then
			Spring.Log(
				"Mex Regions",
				LOG.WARNING,
				unclaimed .. " metal spot(s) lie in no region and " .. twice .. " in more than one"
			)
		end

		for _, team in ipairs(teams) do
			local held, keys = {}, {}
			for _, region in ipairs(regions) do
				if claims[region.id] == team.teamID then
					held[#held + 1] = region.id
					for _, key in ipairs(spotsOf[region.id] or {}) do
						keys[#keys + 1] = key
					end
				end
			end
			Shared.Holdings.Write(springRepo, team.teamID, { regions = held, spots = keys })
		end
		return claims
	end,

	---@return table<integer, string[]|nil>
	Holdings = function()
		return Claims.Holdings(state.mexRegions or {}, state.mexClaims or {})
	end,
}

---@class EconomyApi
return {
	MexRegions = MexRegions,
}
