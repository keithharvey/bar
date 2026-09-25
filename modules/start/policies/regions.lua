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

---@class StartRegionEnv the keys start's region stages read from the caller-supplied env (see RegionSetContext.env)
---@field starts { allyTeam: integer, x: number, z: number }[]|nil the map's start positions, when the caller has them

---@class StartRegionsDescribeStages start's stages on the regions module's description, for regions of any type
---@field NearestStart string the start inside the region, or else the nearest to its centre; adds nothing when env.starts is nil

---@type StartRegionsDescribeStages
local RegionsDescribe = PolicyBuilder.Contributes(Regions.Describe, {
	NearestStart = "NearestStart",
})

Policies.On(Regions.Describe).Apply(RegionsDescribe.NearestStart, function(ctx)
	local starts = (ctx.env --[[@as StartRegionEnv]]).starts
	if not starts or #starts == 0 then
		return
	end
	local vertices = ctx.region.vertices or {}
	for _, start in ipairs(starts) do
		if Geometry.Contains(start.x, start.z, vertices) then
			ctx.lines[#ctx.lines + 1] = { "Start", string.format("ally team %d starts inside", start.allyTeam) }
			return
		end
	end
	local cx, cz = Geometry.Centroid(vertices)
	local best, bestD = starts[1], math.huge
	for _, start in ipairs(starts) do
		local d = Geometry.Distance(cx, cz, start.x, start.z)
		if d < bestD then
			best, bestD = start, d
		end
	end
	ctx.lines[#ctx.lines + 1] =
		{ "Nearest start", string.format("ally team %d, %.0f elmos from the centre", best.allyTeam, bestD) }
end)

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
