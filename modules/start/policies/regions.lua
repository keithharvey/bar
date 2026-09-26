local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class StartRegion: Region
---@field type "start"
---@field team integer
---@field name string|nil
---@field positions { x: number, z: number }[]|nil

---@class StartRegionsNamesSteps: PolicySteps<RegionNamesContext<StartRegion>, RegionNamesContext<StartRegion>>
---@field FromTeam "FromTeam"

---@type StartRegionsNamesSteps
local RegionsNames = {
	FromTeam = "FromTeam",
}
Policy.Contributes(Regions.Names, RegionsNames)

Policies.On(RegionsNames)
	.Apply(RegionsNames.FromTeam, function(ctx)
		for i, region in ipairs(ctx.regions) do
			if region.team ~= nil then
				ctx.proposed[i] = tostring(region.team)
			end
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))

---@class StartRegionsSetSteps: PolicySteps<RegionSetContext<StartRegion>, RegionSetContext<StartRegion>>
---@field AreasDisjoint "AreasDisjoint"

---@type StartRegionsSetSteps
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}
Policy.Contributes(Regions.CheckSet, RegionsSet)

Policies.On(RegionsSet)
	.Apply(RegionsSet.AreasDisjoint, function(ctx)
		local label = ctx.type.label:lower()
		for i, a in ipairs(ctx.regions) do
			for j, b in ipairs(ctx.regions) do
				if i ~= j and #a.vertices >= 3 and #b.vertices >= 3 and RegionsApi.Overlaps(a.vertices, b.vertices) then
					RegionsApi.ProblemWith(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
				end
			end
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))

---@class StartDescription: RegionDescription
---@field team integer
---@field positions { x: number, z: number }[]

---@class StartRegionsDescribeSteps: PolicySteps<RegionDescribeContext<StartRegion>, StartDescription>
---@field Start "Start"

---@type StartRegionsDescribeSteps
local RegionsDescribe = {
	Start = "Start",
}
Policy.Contributes(Regions.Describe, RegionsDescribe)

Policies.On(RegionsDescribe)
	.Answer(RegionsDescribe.Start, function(ctx)
		---@type StartDescription
		return {
			area = ctx.shape.area,
			centre = ctx.shape.centre,
			team = ctx.region.team,
			positions = ctx.region.positions or {},
		}
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))
	.Before(Regions.Describe.Shape)

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
