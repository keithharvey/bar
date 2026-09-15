local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Enums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

---@param region Region
---@return RegionGeometryKey|nil
local function shapeOf(region)
	if region.geometry then
		return region.geometry
	end
	if type(region.vertices) == "table" then
		return Enums.Geometry.Polygon
	end
	if type(region.x) == "number" and type(region.z) == "number" then
		return Enums.Geometry.Point
	end
	return nil
end

-- The rules every region passes, from its type's descriptor. Problems collect rather than
-- refuse, so an editor can show a map maker everything at once.
Policies.On(Contract.Check)
	.Apply(Contract.Check.Shape, function(ctx)
		if ctx.fieldsOnly then
			return
		end
		local shape = shapeOf(ctx.region)
		if shape == nil then
			ctx.problems[#ctx.problems + 1] = "a region is a point or a polygon"
			return
		end
		local allowed = false
		for _, g in ipairs(ctx.type.geometries) do
			allowed = allowed or g == shape
		end
		if not allowed then
			ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " cannot be a " .. shape
		elseif shape == Enums.Geometry.Polygon and #ctx.region.vertices < 3 then
			ctx.problems[#ctx.problems + 1] = "a polygon needs at least three vertices"
		end
	end)
	.Apply(Contract.Check.Fields, function(ctx)
		for _, field in ipairs(ctx.type.fields) do
			local value = ctx.region[field.key]
			local missing = value == nil or value == ""
			if field.required and missing then
				ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " needs a " .. field.label:lower()
			elseif not missing and field.kind == "integer" and type(value) ~= "number" then
				ctx.problems[#ctx.problems + 1] = field.label .. " must be a number"
			end
			if field.unique and not missing then
				for _, other in ipairs(ctx.siblings) do
					if other ~= ctx.region and other[field.key] == value then
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
	.Apply(Contract.Check.Disjoint, function(ctx)
		if not ctx.type.disjoint or ctx.fieldsOnly or not ctx.region.vertices then
			return
		end
		for _, other in ipairs(ctx.siblings) do
			if other ~= ctx.region and other.vertices and Geometry.Overlaps(ctx.region.vertices, other.vertices) then
				ctx.problems[#ctx.problems + 1] = "overlaps "
					.. ctx.type.label:lower()
					.. " "
					.. tostring(other.name or other.allyTeam or "?")
				return
			end
		end
	end)

-- What a region is once measured. Defaults are the geometry's own answers; a module that knows
-- more about a kind of region provides over them.
Policies.On(Contract.Facts)
	.Default(Contract.Facts.Area, function(ctx)
		return ctx.region.vertices and Geometry.Area(ctx.region.vertices) or 0
	end)
	.Default(Contract.Facts.Centre, function(ctx)
		if ctx.region.vertices then
			local x, z = Geometry.Centroid(ctx.region.vertices)
			return { x = x, z = z }
		end
		return { x = ctx.region.x or 0, z = ctx.region.z or 0 }
	end)
	.Default(Contract.Facts.MetalSpots, function(ctx)
		if not ctx.spots or not ctx.region.vertices then
			return nil
		end
		local count, worth = 0, 0.0
		for _, spot in ipairs(ctx.spots) do
			if Geometry.Contains(spot.x, spot.z, ctx.region.vertices) then
				count = count + 1
				worth = worth + (spot.worth or 0)
			end
		end
		return { count = count, worth = worth }
	end)
	.Default(Contract.Facts.NearestStart, function(ctx)
		if not ctx.starts or #ctx.starts == 0 then
			return nil
		end
		local cx, cz
		if ctx.region.vertices then
			cx, cz = Geometry.Centroid(ctx.region.vertices)
		else
			cx, cz = ctx.region.x or 0, ctx.region.z or 0
		end
		local best, bestD = ctx.starts[1], math.huge
		for _, start in ipairs(ctx.starts) do
			local d = Geometry.Distance(cx, cz, start.x, start.z)
			if d < bestD then
				best, bestD = start, d
			end
		end
		if not best then
			return nil
		end
		return { allyTeam = best.allyTeam, distance = bestD }
	end)
