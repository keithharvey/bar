
local PolygonLib = VFS.Include("common/lib_polygon.lua")

---@class MexRegionsClaimsLib
local Claims = {}

---@class MexRegionsTeamStart
---@field teamID integer
---@field allyTeam integer the start ordinal the team plays from: ally team 0 is 1
---@field x number
---@field z number

---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsClaimsContext
function Claims.Context(teams, regions)
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local dx, dz = region.centerX - team.x, region.centerZ - team.z
			ranked[j] = {
				id = region.id,
				name = region.name,
				team = region.team,
				group = region.group,
				distance = math.sqrt(dx * dx + dz * dz),
				ordinal = 0,
			}
		end
		table.sort(ranked, function(a, b)
			if a.distance ~= b.distance then
				return a.distance < b.distance
			end
			return a.id < b.id
		end)
		for ordinal, entry in ipairs(ranked) do
			entry.ordinal = ordinal
		end
		views[i] =
			{ teamID = team.teamID, allyTeam = team.allyTeam, startX = team.x, startZ = team.z, regions = ranked }
	end
	return { teams = views, regions = regions }
end

---@param regions MexRegion[]
---@param x number
---@param z number
---@return MexRegion|nil
function Claims.RegionAt(regions, x, z)
	for _, region in ipairs(regions) do
		if PolygonLib.PointInPolygon(x, z, region.polygon) then
			return region
		end
	end
	return nil
end

---@param regions MexRegion[]
---@param claims MexRegionsClaims
---@param x number
---@param z number
---@return integer|nil
function Claims.OwnerAt(regions, claims, x, z)
	local region = Claims.RegionAt(regions, x, z)
	return region and claims[region.id] or nil
end

---@param regions MexRegion[]
---@param claims MexRegionsClaims
---@return table<integer, string[]|nil>
function Claims.Holdings(regions, claims)
	local holdings = {} ---@type table<integer, string[]|nil>
	for _, region in ipairs(regions) do
		local teamID = claims[region.id]
		if teamID ~= nil then
			holdings[teamID] = holdings[teamID] or {}
			table.insert(holdings[teamID], region.id)
		end
	end
	return holdings
end

return Claims
