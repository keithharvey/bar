local Geometry = require("modules/regions/lib/geometry")
local Policy = require("modules/policy")

---@class RegionCheckContext
---@field type RegionType
---@field region Region
---@field siblings Region[]
---@field names table<Region, string>
---@field fieldsOnly boolean|nil
---@field problems string[]

---@class RegionCheckSteps: PolicySteps<RegionCheckContext, RegionCheckContext>
---@field Shape string
---@field Fields string

---@class (partial) RegionsContract
---@field Check RegionCheckSteps

---@type RegionCheckSteps
local Check = Policy.Fold({
	Shape = "Shape",
	Fields = "Fields",
})

---@param ctx RegionCheckContext
---@param region Region
---@param field RegionField
---@return any
local function valueOf(ctx, region, field)
	if field.key == "name" then
		return ctx.names[region]
	end
	return region[field.key]
end

Policies.On(Check)
	.Apply(Check.Shape, function(ctx)
		if ctx.fieldsOnly then
			return
		end
		local vertices = ctx.region.vertices or {}
		local shape = Geometry.Of(vertices)
		if shape == nil then
			ctx.problems[#ctx.problems + 1] = #vertices == 2 and "two vertices make neither a point nor a polygon"
				or "a region is a point or a polygon"
			return
		end
		local allowed = false
		for _, g in ipairs(ctx.type.geometries) do
			allowed = allowed or g == shape
		end
		if not allowed then
			ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " cannot be a " .. shape
		end
	end)
	.Apply(Check.Fields, function(ctx)
		for _, field in ipairs(ctx.type.fields) do
			local value = valueOf(ctx, ctx.region, field)
			local missing = value == nil or value == ""
			if field.required and missing then
				ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " needs a " .. field.label:lower()
			elseif not missing and field.kind == "integer" and type(value) ~= "number" then
				ctx.problems[#ctx.problems + 1] = field.label .. " must be a number"
			end
			if field.unique and not missing then
				for _, other in ipairs(ctx.siblings) do
					if other ~= ctx.region and valueOf(ctx, other, field) == value then
						ctx.problems[#ctx.problems + 1] = "a "
							.. ctx.type.label:lower()
							.. " with "
							.. field.label:lower()
							.. " "
							.. tostring(value)
							.. " already exists"
						break
					end
				end
			end
		end
	end)

return { Check = Check }
