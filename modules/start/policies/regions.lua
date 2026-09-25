local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class StartRegion: Region a team's start as drawn in the editor: the area the team's positions lie in, or a point when only one position is drawn
---@field type "start"
---@field team integer start ordinal; start 1 is team 1
---@field name string|nil the area's label
---@field positions { x: number, z: number }[]|nil the team's start positions, in elmos, one per seat

---@class StartRegionsNamesStages start's stages on the regions module's naming, for the start type
---@field FromTeam string an unnamed start is named after its team

---@type StartRegionsNamesStages
local RegionsNames = PolicyBuilder.Contributes(Regions.Names, {
	FromTeam = "FromTeam",
})

Policies.On(Regions.Names).Apply(RegionsNames.FromTeam, function(ctx)
	if ctx.type.key ~= RegionsApi.Enums.Types.Start then
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
	if ctx.type.key ~= RegionsApi.Enums.Types.Start then
		return
	end
	local label = ctx.type.label:lower()
	for i, a in ipairs(ctx.regions) do
		for j, b in ipairs(ctx.regions) do
			if i ~= j and a.vertices and b.vertices and RegionsApi.Overlaps(a.vertices, b.vertices) then
				RegionsApi.ProblemWith(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
			end
		end
	end
end)

---@class StartDescription: RegionDescription what start says of one of its regions
---@field team integer the start ordinal
---@field positions { x: number, z: number }[] the team's start positions; none when the start is drawn as an area alone

---@class StartRegionsDescribeStages start's answer on the regions module's description, for its own type
---@field Start string the start's ordinal and its positions, with the shape

---@type StartRegionsDescribeStages
local RegionsDescribe = PolicyBuilder.Contributes(Regions.Describe, {
	Start = "Start",
})

Policies.On(Regions.Describe)
	.Answer(RegionsDescribe.Start, function(ctx)
		if ctx.type.key ~= RegionsApi.Enums.Types.Start then
			return nil
		end
		local region = ctx.region --[[@as StartRegion]]
		---@type StartDescription
		return {
			area = ctx.shape.area,
			centre = ctx.shape.centre,
			team = region.team,
			positions = region.positions or {},
		}
	end)
	.Before(Regions.Describe.Shape)

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
