local PolicyBuilder = require("modules/policy_builder")

---@class RegionDescription what is known of any region: its shape. The module that owns a type answers with its own record extending this
---@field area number elmos squared; 0 for a point
---@field centre { x: number, z: number } the vertex centroid, or the point itself

---@class RegionDescribeContext the context for describing one region
---@field type RegionType
---@field region Region
---@field shape RegionDescription the shape's facts, computed by the api before the ask
---@field map RegionMap what the caller knows of the map, passed through untouched

---@class RegionDescribeStages: PolicyStages<RegionDescribeContext, RegionDescription> one answer per region: the module that owns the type answers for its own type, placed before Shape; the shape alone answers for a type nobody describes
---@field Shape string the shape's facts alone

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
