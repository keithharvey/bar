local Geometry = require("modules/regions/lib/geometry")
local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local Problems = require("modules/regions/lib/problems")
local RegionEnums = require("modules/regions/enums")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class StartRegion: Region a team's start as drawn in the editor: a single position, or the area the positions lie in
---@field type "start"
---@field team integer start ordinal; start 1 is team 1
---@field name string|nil the area's label

---@class StartRegionsNamesStages start's stages on the regions module's naming, for the start type
---@field FromTeam string an unnamed start is named after its team

---@type StartRegionsNamesStages
local RegionsNames = PolicyBuilder.Contributes(Regions.Names, {
	FromTeam = "FromTeam",
})

Policies.On(Regions.Names).Apply(RegionsNames.FromTeam, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.Start then
		return
	end
	for i, region in ipairs(ctx.regions) do
		---@cast region StartRegion
		if region.team ~= nil then
			ctx.bases[i] = tostring(region.team)
		end
	end
end)

---@class StartRegionsSetStages start's stages on the regions module's set check, for the start type
---@field AreasDisjoint string no two start areas overlap; sharing an edge is allowed

---@type StartRegionsSetStages
local RegionsSet = PolicyBuilder.Contributes(Regions.CheckSet, {
	AreasDisjoint = "AreasDisjoint",
})

Policies.On(Regions.CheckSet).Apply(RegionsSet.AreasDisjoint, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.Start then
		return
	end
	local label = ctx.type.label:lower()
	for i, a in ipairs(ctx.regions) do
		for j, b in ipairs(ctx.regions) do
			if i ~= j and a.vertices and b.vertices and Geometry.Overlaps(a.vertices, b.vertices) then
				Problems.OfRegion(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
			end
		end
	end
end)

---@class StartRegionsDescribeStages start's stages on the regions module's description, for regions of any type
---@field NearestStart string the start whose region holds this one's centre, else the nearest start to it; adds nothing when the map has no starts

---@type StartRegionsDescribeStages
local RegionsDescribe = PolicyBuilder.Contributes(Regions.Describe, {
	NearestStart = "NearestStart",
})

Policies.On(Regions.Describe).Apply(RegionsDescribe.NearestStart, function(ctx)
	if ctx.type.key == RegionEnums.Types.Start then
		return
	end
	local Api = require("modules/regions/api")
	local cx, cz = Geometry.Centroid(ctx.region.vertices or {})
	local best = nil ---@type StartRegion|nil
	local bestD, inside = math.huge, false
	for _, start in ipairs(Api.All(RegionEnums.Types.Start)) do
		---@cast start StartRegion
		local vertices = start.vertices or {}
		if #vertices >= 3 and Geometry.Contains(cx, cz, vertices) then
			best, bestD, inside = start, 0, true
			break
		end
		local sx, sz = Geometry.Centroid(vertices)
		local d = Geometry.Distance(cx, cz, sx, sz)
		if d < bestD then
			best, bestD = start, d
		end
	end
	if best == nil then
		return
	end
	ctx.lines[#ctx.lines + 1] = {
		"Nearest start",
		inside and string.format("start %d holds the centre", best.team)
			or string.format("start %d, %.0f elmos from the centre", best.team, bestD),
	}
end)

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
