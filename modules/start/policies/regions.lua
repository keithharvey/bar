local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")

local isStart = RegionsApi.OfType(RegionsApi.Enums.Types.Start)

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

-- Start regions describe what makes them special at run-time
--
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

Policies.On(RegionsDescribe).Step(RegionsDescribe.Start, function(ctx)
	if not isStart(ctx) then
		return
	end
	return { team = ctx.region.team, positions = ctx.region.positions or {} }
end)

-- Start regions are named by team, if present
--   (if a map maker hasn't defined the start region.name via terraformer e.g. "canyon", "carry", etc.)
--
---@class StartRegionsNamesSteps: PolicySteps<RegionNamesContext<StartRegion>, RegionNamesContext<StartRegion>>
---@field FromTeam "FromTeam"

---@type StartRegionsNamesSteps
local RegionsNames = {
	FromTeam = "FromTeam",
}
Policy.Contributes(Regions.Names, RegionsNames)

Policies.On(RegionsNames).Step(RegionsNames.FromTeam, function(ctx)
	if not isStart(ctx) then
		return
	end
	for i, region in ipairs(ctx.regions) do
		if region.team ~= nil then
			ctx.proposed[i] = tostring(region.team)
		end
	end
end)

-- Start regions do not overlap (validation enforced by the map editor)
--
---@class StartRegionsSetSteps: PolicySteps<RegionSetContext<StartRegion>, RegionSetContext<StartRegion>>
---@field AreasDisjoint "AreasDisjoint"

---@type StartRegionsSetSteps
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}
Policy.Contributes(Regions.CheckSet, RegionsSet)

Policies.On(RegionsSet).Step(RegionsSet.AreasDisjoint, function(ctx)
	if not isStart(ctx) then
		return
	end
	local label = ctx.type.label:lower()
	for i, a in ipairs(ctx.regions) do
		for j, b in ipairs(ctx.regions) do
			if i ~= j and #a.vertices >= 3 and #b.vertices >= 3 and RegionsApi.Overlaps(a.vertices, b.vertices) then
				RegionsApi.ProblemWith(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
			end
		end
	end
end)

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
