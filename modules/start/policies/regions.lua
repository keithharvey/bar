local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class StartRegion: Region
---@field type "start"
---@field team integer
---@field name string|nil
---@field positions { x: number, z: number }[]|nil

---@class StartRegionsNamesStages
---@field FromTeam string

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

---@class StartRegionsSetStages
---@field AreasDisjoint string

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

---@class StartDescription: RegionDescription
---@field team integer
---@field positions { x: number, z: number }[]

---@class StartRegionsDescribeStages
---@field Start string

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
