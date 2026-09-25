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

---@class StartRegionsNamesSteps
---@field FromTeam "FromTeam"

---@type StartRegionsNamesSteps
local RegionsNames = {
	FromTeam = "FromTeam",
}
Policy.Contributes(Regions.Names, RegionsNames)

Policies.On(Regions.Names).Apply(RegionsNames.FromTeam, function(ctx)
	if ctx.type.key ~= RegionsApi.Enums.Types.Start then
		return
	end
	for i, region in ipairs(ctx.regions) do
		---@cast region StartRegion
		if region.team ~= nil then
			ctx.proposed[i] = tostring(region.team)
		end
	end
end)

---@class StartRegionsSetSteps
---@field AreasDisjoint "AreasDisjoint"

---@type StartRegionsSetSteps
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}
Policy.Contributes(Regions.CheckSet, RegionsSet)

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

---@class StartRegionsDescribeSteps
---@field Start "Start"

---@type StartRegionsDescribeSteps
local RegionsDescribe = {
	Start = "Start",
}
Policy.Contributes(Regions.Describe, RegionsDescribe)

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
