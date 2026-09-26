local Policy = require("modules/policy")

---@class RegionDescription
---@field area number
---@field centre { x: number, z: number }

---@class RegionDescribeContext<R>
---@field type RegionType
---@field region R
---@field shape RegionDescription
---@field map RegionMap

---@class RegionDescribePolicy: PolicySteps<RegionDescribeContext<Region>, RegionDescription>
---@field Shape "Shape"

---@class (partial) RegionsContract
---@field Describe RegionDescribePolicy

---@type RegionDescribePolicy
local Describe = {
	Shape = "Shape",
}
Policy.Single(Describe)

Policies.On(Describe).Answer(Describe.Shape, function(ctx)
	return ctx.shape
end)

return { Describe = Describe }
