local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local Problems = require("modules/regions/lib/problems")

---@class RegionProblem
---@field message string
---@field region Region|nil
---@field name string|nil
---@field at { x: number, z: number }|nil

---@class RegionSetContext
---@field type RegionType
---@field regions Region[]
---@field names string[]
---@field map RegionMap
---@field problems RegionProblem[]

---@class (partial) RegionMap

---@class RegionSetStages: PolicyStages<RegionSetContext, RegionSetContext>
---@field Each string

---@class (partial) RegionsContract
---@field CheckSet RegionSetStages

---@type RegionSetStages
local CheckSet = PolicyBuilder.Fold({
	Each = "Each",
})

Policies.On(CheckSet).Apply(CheckSet.Each, function(ctx)
	local names = {} ---@type table<Region, string>
	for i, region in ipairs(ctx.regions) do
		names[region] = ctx.names[i]
	end
	for i, region in ipairs(ctx.regions) do
		---@type RegionCheckContext
		local one = { type = ctx.type, region = region, siblings = ctx.regions, names = names, problems = {} }
		ModuleHandler.Evaluate(ModuleHandler.Contract(Modules.Regions).Check, one)
		for _, problem in ipairs(one.problems) do
			Problems.OfRegion(ctx, i, problem)
		end
	end
end)

return { CheckSet = CheckSet }
