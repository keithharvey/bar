-- The deal's context and the lookups the placement fact needs. Pure: specs hand in tables.

local PolygonLib = VFS.Include("common/lib_polygon.lua")

---@class MexRegionsClaimsLib
local Claims = {}

---@class MexRegionsTeamStart
---@field teamID integer
---@field x number
---@field z number

---Every team's view of every region, nearest first: what the claims pipeline decides over.
---Teams come in the order the deal goes round.
---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsClaimsContext
function Claims.Context(teams, regions)
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local dx, dz = region.centerX - team.x, region.centerZ - team.z
			ranked[j] =
				{ name = region.name, group = region.group, distance = math.sqrt(dx * dx + dz * dz), ordinal = 0 }
		end
		table.sort(ranked, function(a, b)
			if a.distance ~= b.distance then
				return a.distance < b.distance
			end
			return a.name < b.name
		end)
		for ordinal, entry in ipairs(ranked) do
			entry.ordinal = ordinal
		end
		views[i] = { teamID = team.teamID, startX = team.x, startZ = team.z, regions = ranked }
	end
	return { teams = views, regions = regions }
end

---The region a point lies in, if any.
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

---The team holding the region a point lies in; nil outside every region or in an unclaimed one.
---@param regions MexRegion[]
---@param claims MexRegionsClaims
---@param x number
---@param z number
---@return integer|nil
function Claims.OwnerAt(regions, claims, x, z)
	local region = Claims.RegionAt(regions, x, z)
	return region and claims[region.name] or nil
end

---Region names per team, in layout order, for the log and the chat.
---@param regions MexRegion[]
---@param claims MexRegionsClaims
---@return table<integer, string[]|nil>
function Claims.Holdings(regions, claims)
	local holdings = {} ---@type table<integer, string[]|nil>
	for _, region in ipairs(regions) do
		local teamID = claims[region.name]
		if teamID ~= nil then
			holdings[teamID] = holdings[teamID] or {}
			table.insert(holdings[teamID], region.name)
		end
	end
	return holdings
end

return Claims
