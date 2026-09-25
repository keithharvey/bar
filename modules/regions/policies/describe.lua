local Policy = require("modules/policy")

---@class RegionDescription
---@field area number
---@field centre { x: number, z: number }

---@class RegionDescribeContext
---@field type RegionType
---@field region Region
---@field shape RegionDescription
---@field map RegionMap

---@class RegionDescribeSteps: PolicySteps<RegionDescribeContext, RegionDescription>
---@field Shape "Shape"

---@class (partial) RegionsContract
---@field Describe RegionDescribeSteps

---@type RegionDescribeSteps
local Describe = {
	Shape = "Shape",
}
Policy.Single(Describe)

Policies.On(Describe).Answer(Describe.Shape, function(ctx)
	return ctx.shape
end)

return { Describe = Describe }
