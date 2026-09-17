local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Sources = VFS.Include("modules/economy/lib/mex_regions/sources.lua") ---@type MexRegionSources
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
local TeamResourceData = VFS.Include("modules/economy/lib/team_resource_data.lua")
local ShareStats = VFS.Include("modules/economy/lib/share_stats.lua")
local state = VFS.Include("modules/economy/state.lua") ---@type EconomyState

---@param springRepo Spring
---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@param deal MexRegionsDeal
local function publish(springRepo, teams, regions, deal)
	springRepo.SetGameRulesParam(Deal.PARAM, Deal.Encode(regions, deal.regions))
	local holdings = Claims.Holdings(regions, deal.regions)
	local keysOf = {} ---@type table<integer, string[]>
	for key, holders in pairs(deal.spots) do
		for _, teamID in ipairs(holders) do
			keysOf[teamID] = keysOf[teamID] or {}
			table.insert(keysOf[teamID], key)
		end
	end
	for _, team in ipairs(teams) do
		local keys = keysOf[team.teamID] or {}
		table.sort(keys)
		Shared.Holdings.Write(springRepo, team.teamID, { regions = holdings[team.teamID] or {}, spots = keys })
	end
end

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
		state.mexTeams = teams
		state.mexGifted = {}
		publish(springRepo, teams, regions, deal)
		return deal
	end,

	---A team has left the match: its regions, and the spots in them, pass to one living ally.
	---@param departingTeamID integer
	---@param springRepo Spring
	---@return integer|nil heir the team that took them; nil when the team held nothing or nobody is left to take it
	Inherit = function(departingTeamID, springRepo)
		local deal, teams = state.mexDeal, state.mexTeams or {}
		local departing ---@type MexRegionsTeamStart|nil
		for _, team in ipairs(teams) do
			if team.teamID == departingTeamID then
				departing = team
			end
		end
		if deal == nil or departing == nil then
			return nil
		end
		local gifted = state.mexGifted or {}
		local heirs = {}
		for _, team in ipairs(teams) do
			local _, _, isDead = springRepo.GetTeamInfo(team.teamID, false)
			if
				team.teamID ~= departingTeamID
				and not isDead
				and springRepo.AreTeamsAllied(departingTeamID, team.teamID)
			then
				heirs[#heirs + 1] = { teamID = team.teamID, x = team.x, z = team.z, gifted = gifted[team.teamID] or 0 }
			end
		end
		local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines
		local heir = ModuleHandler.Evaluate(pipelines.mex_regions_heir, { departing = departing, heirs = heirs })
		if not heir then
			return nil
		end
		local moved = 0
		for id, holder in pairs(deal.regions) do
			if holder == departingTeamID then
				deal.regions[id] = heir
				moved = moved + 1
			end
		end
		if moved == 0 then
			return nil
		end
		for _, holders in pairs(deal.spots) do
			for i = #holders, 1, -1 do
				if holders[i] == departingTeamID then
					table.remove(holders, i)
					if not table.contains(holders, heir) then
						table.insert(holders, heir)
					end
				end
			end
		end
		gifted[heir] = (gifted[heir] or 0) + moved
		state.mexGifted = gifted
		publish(springRepo, teams, state.mexRegions or {}, deal)
		return heir
	end,

	---@return table<integer, string[]|nil> teamID -> the ids of the regions it holds
	Holdings = function()
		return Claims.Holdings(state.mexRegions or {}, state.mexDeal and state.mexDeal.regions or {})
	end,
}

---@param springRepo Spring
---@param teamID integer
---@param resource string
---@param sent number|nil
---@param received number|nil
---@return number|nil sent
---@return number|nil received
local function overlaySharing(springRepo, teamID, resource, sent, received)
	local s = ShareStats.Read(springRepo, teamID, resource)
	return s.sentRecent or sent, s.receivedRecent or received
end

---@class EconomyResourcesApi a team's resources as the economy sees them: the engine's numbers, with what redistribution sent and received laid over
local Resources = {
	---@param springRepo Spring
	---@param teamID integer
	---@param resource string
	Data = function(springRepo, teamID, resource)
		local d = TeamResourceData.Get(springRepo, teamID, resource)
		d.sent, d.received = overlaySharing(springRepo, teamID, resource, d.sent, d.received)
		return d
	end,

	---@param springRepo Spring
	---@param teamID integer
	---@param resource string
	---@return number|nil current
	---@return number|nil storage
	---@return number|nil pull
	---@return number|nil income
	---@return number|nil expense
	---@return number|nil share
	---@return number|nil sent what redistribution sent lately, laid over the engine's figure
	---@return number|nil received
	Get = function(springRepo, teamID, resource)
		local cur, stor, pull, inc, exp, share, sent, received = springRepo.GetTeamResources(teamID, resource)
		sent, received = overlaySharing(springRepo, teamID, resource, sent, received)
		return cur, stor, pull, inc, exp, share, sent, received
	end,

	---@param springRepo Spring
	---@param teamID integer
	---@param resource string
	---@param amount number
	Add = function(springRepo, teamID, resource, amount)
		local current = springRepo.GetTeamResources(teamID, resource) or 0
		return springRepo.SetTeamResource(teamID, resource, current + amount)
	end,
}

---@class EconomyApi
return {
	MexRegions = MexRegions,
	Resources = Resources,
}
