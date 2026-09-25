local Geometry = require("modules/regions/lib/geometry")
local PolicyBuilder = require("modules/policy_builder")

---@class RegionDescribeContext the context for building the label/value lines shown for one region
---@field type RegionType
---@field region Region
---@field map RegionMap what the caller knows of the map, passed through untouched
---@field lines { [1]: string, [2]: string }[] { label, value } pairs, in the order the stages add them

---@class RegionDescribeStages: PolicyStages<RegionDescribeContext, RegionDescribeContext> the lines shown for a region. The module that owns a type adds the lines only it can compute
---@field Shape string the area (elmos squared, 0 for a point) and the centre (vertex centroid, or the point itself)

---@class (partial) RegionsContract
---@field Describe RegionDescribeStages

---@class (partial) RegionsPipelines
---@field describe AssembledPipeline<RegionDescribeContext, RegionDescribeContext>

---@type RegionDescribeStages
local Describe = PolicyBuilder.Fold({
	Shape = "Shape",
})

Policies.On(Describe).Apply(Describe.Shape, function(ctx)
	local vertices = ctx.region.vertices or {}
	local area = Geometry.Area(vertices)
	if area > 0 then
		ctx.lines[#ctx.lines + 1] =
			{ "Area", string.format("%.0f x %.0f elmos equivalent", math.sqrt(area), math.sqrt(area)) }
	end
	local x, z = Geometry.Centroid(vertices)
	ctx.lines[#ctx.lines + 1] = { "Centre", string.format("%d, %d", x, z) }
end)

return { Describe = Describe }
