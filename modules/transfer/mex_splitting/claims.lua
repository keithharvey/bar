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
