local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local Problems = require("modules/regions/lib/problems")

---@class RegionProblem one problem found in a set of regions
---@field message string
---@field region Region|nil the region the problem is about; nil when it concerns the set as a whole
---@field name string|nil display name of that region
---@field at { x: number, z: number }|nil map position of the problem, when the rule that found it has one

---@class RegionSetContext the context for checking every region of one type as a set. Problems accumulate (see RegionProblems)
---@field type RegionType
---@field regions Region[]
---@field names string[] display name per region, by index, derived where none is set
---@field env table caller-supplied map data, passed through untouched. The regions module does not read it; each type's owner documents the keys its stages expect (StartRegionEnv, MexRegionEnv)
---@field problems RegionProblem[]

---@class RegionSetStages: PolicyStages<RegionSetContext, RegionSetContext> rules over the whole set. The module that owns a type contributes its own stages, such as coverage
---@field Each string runs the type's Check on every region against its siblings; each problem is attributed to its region

---@class (partial) RegionsContract
---@field CheckSet RegionSetStages

---@class (partial) RegionsPipelines
---@field check_set AssembledPipeline<RegionSetContext, RegionSetContext>

---@type RegionSetStages
local CheckSet = PolicyBuilder.Fold({
	Each = "Each",
})

Policies.On(CheckSet).Apply(CheckSet.Each, function(ctx)
	---@type RegionsPipelines
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions)
	local names = {} ---@type table<Region, string>
	for i, region in ipairs(ctx.regions) do
		names[region] = ctx.names[i]
	end
	for i, region in ipairs(ctx.regions) do
		---@type RegionCheckContext
		local one = { type = ctx.type, region = region, siblings = ctx.regions, names = names, problems = {} }
		ModuleHandler.Evaluate(pipelines.check, one)
		for _, problem in ipairs(one.problems) do
			Problems.OfRegion(ctx, i, problem)
		end
	end
end)

return { CheckSet = CheckSet }
