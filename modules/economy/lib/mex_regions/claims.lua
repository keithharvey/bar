local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared

---@class MexRegionsClaimsLib the pure steps of the deal, so the policy reads as the rule and the spec can check each step
local Claims = {}

---@class MexRegionsRanked one region as a team sees it
---@field region MexRegion
---@field distance number elmos from where the team starts to the region's centre

---@class MexRegionsTeamView a team and the regions ranked from where it starts
---@field team MexRegionsTeamStart
---@field regions MexRegionsRanked[] nearest first

---@param regions MexRegion[]
---@return string[] problems what the regions module finds wrong with the layout, each naming its region
function Claims.Problems(regions)
	local problems = {} ---@type string[]
	for _, region in ipairs(regions) do
		for _, problem in ipairs(Regions.Check(Enums.Types.MexRegion, region, regions)) do
			problems[#problems + 1] = region.id .. ": " .. problem
		end
	end
	return problems
end

---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsTeamView[] in the teams' order
function Claims.Rank(teams, regions)
	local centres = {} ---@type table<MexRegion, { x: number, z: number }>
	for _, region in ipairs(regions) do
		local x, z = Geometry.Centroid(region.vertices)
		centres[region] = { x = x, z = z }
	end
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local centre = centres[region]
			ranked[j] = { region = region, distance = Geometry.Distance(centre.x, centre.z, team.x, team.z) }
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

---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@return table<string, string[]> byRegion # the keys of the spots inside each region, by region id
---@return string[] open # the keys of the spots no region covers
function Claims.SpotsIn(regions, spots)
	local byRegion = {} ---@type table<string, string[]>
	local open = {} ---@type string[]
	for _, spot in ipairs(spots) do
		local key = Shared.SpotKey(spot.x, spot.z)
		local covered = false
		for _, region in ipairs(regions) do
			if Geometry.Contains(spot.x, spot.z, region.vertices) then
				byRegion[region.id] = byRegion[region.id] or {}
				table.insert(byRegion[region.id], key)
				covered = true
			end
		end
		if not covered then
			open[#open + 1] = key
		end
	end
	return byRegion, open
end

---@param regions MexRegion[]
---@param holders table<string, integer> the team holding each region, by region id
---@return table<integer, string[]|nil> the ids of each team's regions in layout order, by team
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
