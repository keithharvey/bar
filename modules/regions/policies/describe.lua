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
---@field Shape string

---@class (partial) RegionsContract
---@field Describe RegionDescribeSteps

---@type RegionDescribeSteps
local Describe = Policy.Single({
	Shape = "Shape",
})

Policies.On(Describe).Answer(Describe.Shape, function(ctx)
	return ctx.shape
end)

return { Describe = Describe }
