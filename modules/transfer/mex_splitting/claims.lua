local Regions = require("modules/regions/api")
local Shared = require("modules/transfer/mex_splitting/shared")

---@class MexRegionsClaimsLib
local Claims = {}

---@class MexRegionsRanked
---@field region MexRegion
---@field distance number

---@class MexRegionsTeamView
---@field team MexRegionsTeamStart
---@field regions MexRegionsRanked[]

---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsTeamView[]
function Claims.Rank(teams, regions)
	local centres = {} ---@type table<MexRegion, { x: number, z: number }>
	for _, region in ipairs(regions) do
		local x, z = Regions.Geometry.Centroid(region.vertices)
		centres[region] = { x = x, z = z }
	end
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local centre = centres[region]
			ranked[j] = { region = region, distance = Regions.Geometry.Distance(centre.x, centre.z, team.x, team.z) }
		end
		table.sort(ranked, function(a, b)
			if a.distance ~= b.distance then
				return a.distance < b.distance
			end
			return a.region.id < b.region.id
		end)
		views[i] = { team = team, regions = ranked }
	end
	return views
end

---@class MexRegionsStart the teams seated at one start of the layout, and its ordinal there
---@field ordinal integer
---@field teams MexRegionsTeamView[]

---@param views MexRegionsTeamView[]
---@return MexRegionsStart[] by ordinal
function Claims.Seat(views)
	local byOrdinal = {} ---@type table<integer, MexRegionsStart>
	local starts = {} ---@type MexRegionsStart[]
	for _, view in ipairs(views) do
		local ordinal = view.team.allyTeamID + 1 -- the layout counts starts from 1
		local start = byOrdinal[ordinal]
		if start == nil then
			start = { ordinal = ordinal, teams = {} }
			byOrdinal[ordinal] = start
			starts[#starts + 1] = start
		end
		table.insert(start.teams, view)
	end
	table.sort(starts, function(a, b)
		return a.ordinal < b.ordinal
	end)
	return starts
end

---@param starts MexRegionsStart[]
---@return fun(region: MexRegion): boolean
function Claims.OfStart(starts)
	local seated = {} ---@type table<integer, boolean>
	for _, start in ipairs(starts) do
		seated[start.ordinal] = true
	end
	return function(region)
		return seated[region.team] == true
	end
end

---@param ordinal integer
---@return fun(region: MexRegion): boolean
function Claims.OwnedBy(ordinal)
	return function(region)
		return region.team == ordinal
	end
end

---@param takers fun(region: MexRegion): boolean
---@return fun(region: MexRegion): boolean
function Claims.Not(takers)
	return function(region)
		return not takers(region)
	end
end

---Deals round the teams until nobody can take: each team in turn takes the nearest region still free that it may take.
---@param teams MexRegionsTeamView[]
---@param held table<string, integer> region id -> team; written
---@param mayTake fun(region: MexRegion): boolean
function Claims.Round(teams, held, mayTake)
	local function take(view)
		for _, ranked in ipairs(view.regions) do
			if held[ranked.region.id] == nil and mayTake(ranked.region) then
				held[ranked.region.id] = view.team.teamID
				return true
			end
		end
		return false
	end
	local took = true
	while took do
		took = false
		for _, view in ipairs(teams) do
			took = take(view) or took
		end
	end
end

---@param teams MexRegionsTeamStart[]
---@param held table<string, integer>
---@return MexRegionsTeamStart[] the teams holding no region
function Claims.EmptyHanded(teams, held)
	local holding = {} ---@type table<integer, boolean>
	for _, teamID in pairs(held) do
		holding[teamID] = true
	end
	local out = {}
	for _, team in ipairs(teams) do
		if not holding[team.teamID] then
			out[#out + 1] = team
		end
	end
	return out
end

---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@param held table<string, integer>
---@return table<string, integer[]> the teams holding each spot, by spot key; a spot two regions cover is held by both
function Claims.SpotHolders(regions, spots, held)
	local byRegion = Claims.SpotsIn(regions, spots)
	local holders = {} ---@type table<string, integer[]>
	for _, region in ipairs(regions) do
		local teamID = held[region.id]
		for _, key in ipairs(teamID and byRegion[region.id] or {}) do
			holders[key] = holders[key] or {}
			if not table.contains(holders[key], teamID) then
				table.insert(holders[key], teamID)
			end
		end
	end
	return holders
end

---The keys of the spots inside each region, by region id.
---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@return table<string, string[]>
function Claims.SpotsIn(regions, spots)
	local byRegion = {} ---@type table<string, string[]>
	for _, spot in ipairs(spots) do
		for _, region in ipairs(regions) do
			if Regions.Contains(spot.x, spot.z, region.vertices) then
				byRegion[region.id] = byRegion[region.id] or {}
				table.insert(byRegion[region.id], Shared.SpotKey(spot.x, spot.z))
			end
		end
	end
	return byRegion
end

---@param regions MexRegion[]
---@param holders table<string, integer>
---@return table<integer, string[]|nil>
function Claims.Holdings(regions, holders)
	local holdings = {} ---@type table<integer, string[]|nil>
	for _, region in ipairs(regions) do
		local teamID = holders[region.id]
		if teamID ~= nil then
			holdings[teamID] = holdings[teamID] or {}
			table.insert(holdings[teamID], region.id)
		end
	end
	return holdings
end

return Claims
