local PolicyBuilder = require("modules/policy_builder")

---@class RegionDescription
---@field area number
---@field centre { x: number, z: number }

---@class RegionDescribeContext
---@field type RegionType
---@field region Region
---@field shape RegionDescription
---@field map RegionMap

---@class RegionDescribeStages: PolicyStages<RegionDescribeContext, RegionDescription>
---@field Shape string

---@class (partial) RegionsContract
---@field Describe RegionDescribeStages

---@class (partial) RegionsPipelines
---@field describe AssembledPipeline<RegionDescribeContext, RegionDescription>

---@type RegionDescribeStages
local Describe = PolicyBuilder.Single({
	Shape = "Shape",
})

Policies.On(Describe).Answer(Describe.Shape, function(ctx)
	return ctx.shape
end)

return { Describe = Describe }
