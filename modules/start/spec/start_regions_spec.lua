local Enums = require("modules/regions/enums")
local Regions = require("modules/regions/api")

---@param team integer
---@param x number
---@param z number
---@param size number
---@return Region
local function area(team, x, z, size)
	return {
		type = Enums.Types.Start,
		team = team,
		vertices = {
			{ x = x, z = z },
			{ x = x + size, z = z },
			{ x = x + size, z = z + size },
			{ x = x, z = z + size },
		},
	}
end

describe("a map's starts, as a set", function()
	it("never have two areas sharing ground, and each problem is the region's own", function()
		local regions = { area(1, 0, 0, 100), area(2, 50, 50, 100), area(3, 500, 500, 100) }
		local problems = Regions.CheckSet(Enums.Types.Start, regions)
		assert.are.same({
			{ region = regions[1], name = "1", message = "overlaps start 2" },
			{ region = regions[2], name = "2", message = "overlaps start 1" },
		}, problems)
		assert.are.equal("1: overlaps start 2", Regions.ProblemLine(assert(problems[1])))
	end)

	it("may touch along an edge, and a start that is a point overlaps nothing", function()
		local point = { type = Enums.Types.Start, team = 3, vertices = { { x = 50, z = 50 } } }
		assert.are.same({}, Regions.CheckSet(Enums.Types.Start, { area(1, 0, 0, 100), area(2, 100, 0, 100), point }))
	end)
end)

describe("what start says about a region", function()
	before_each(function()
		Regions.Clear()
	end)

	it("is the start's ordinal and the positions drawn for it, with the shape", function()
		local one = area(1, 0, 0, 100)
		Regions.Put(one)
		Regions.Put({ type = Enums.Types.Start, team = 1, vertices = { { x = 10, z = 10 } } })
		Regions.Put({ type = Enums.Types.Start, team = 2, vertices = { { x = 500, z = 500 } } })
		Regions.Put({ type = Enums.Types.Start, team = 1, vertices = { { x = 90, z = 90 } } })
		local d = Regions.Describe(one)
		assert.are.equal(1, d.team)
		assert.are.equal(2, #d.positions, "the point regions carrying the same team")
		assert.are.same({ x = 90, z = 90 }, assert(d.positions[2]).vertices[1])
		assert.are.equal(10000, d.area)
	end)

	it("says nothing about a region of another type", function()
		Regions.Put(area(1, 0, 0, 100))
		local d = Regions.Describe({ type = "mex_region", vertices = area(0, 0, 0, 100).vertices })
		assert.is_nil(d.team)
	end)
end)
