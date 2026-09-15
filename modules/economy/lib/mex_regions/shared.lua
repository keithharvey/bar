-- What Map Assigned publishes for every Lua state to read back, typed, the way transfer's
-- factors are: one record per team on a team rules param. Written once, at the deal, so it
-- is as static as the map; widgets colour from it and the placement fact reads it.

local Published = VFS.Include("modules/published.lua")

---@class MexRegionsShared
local Shared = {}

---@class MexHoldingsRecord one team's share of the deal
---@field regions string[] the region names the team holds
---@field spots string[] the metal spots inside those regions, as "<x>x<z>" keys; a mex is judged by the spot it mines

---A spot's key on the wire and in lookups: its centre, whole elmos, joined by a character the
---published list codec does not use (it splits fields on ":" and items on ",").
---@param x number
---@param z number
---@return string
function Shared.SpotKey(x, z)
	return math.floor(x + 0.5) .. "x" .. math.floor(z + 0.5)
end

Shared.Holdings = Published.PerTeam("mex_holdings", {
	regions = Published.List,
	spots = Published.List,
})

---Spot key -> holding team, from every team's published record. Rebuilt only when a record
---changes, so an ask costs a lookup.
local cache = { signature = nil, byKey = {} }
---@param springRepo Spring
---@param teamIDs integer[]
---@return table<string, integer>
function Shared.HolderBySpot(springRepo, teamIDs)
	local parts = {}
	for i, teamID in ipairs(teamIDs) do
		parts[i] = tostring(springRepo.GetTeamRulesParam(teamID, Shared.Holdings.key) or "")
	end
	local signature = table.concat(parts, "|")
	if cache.signature == signature then
		return cache.byKey
	end
	local byKey = {} ---@type table<string, integer>
	for _, teamID in ipairs(teamIDs) do
		local record = Shared.Holdings.Read(springRepo, teamID) ---@type MexHoldingsRecord|nil
		if record and record.spots then
			for _, key in ipairs(record.spots) do
				byKey[key] = teamID
			end
		end
	end
	cache.signature = signature
	cache.byKey = byKey
	return byKey
end

return Shared
