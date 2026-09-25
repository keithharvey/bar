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

	it(
		"names the start whose region holds the centre, else the nearest start to it, from the starts on the map",
		function()
			local region = { type = "mex_region", vertices = area(0, 0, 0, 100).vertices }
			Regions.Put(area(1, 1000, 1000, 100))
			Regions.Put(area(2, 0, 0, 100))
			assert.are.same({ "Nearest start", "start 2 holds the centre" }, Regions.Describe(region)[3])
			Regions.Clear()
			Regions.Put(area(1, 1000, 1000, 100))
			Regions.Put(area(2, 0, 200, 100))
			assert.are.same({ "Nearest start", "start 2, 200 elmos from the centre" }, Regions.Describe(region)[3])
		end
	)

	it("adds nothing when the map has no starts, and nothing about a start itself", function()
		assert.are.equal(2, #Regions.Describe({ type = "mex_region", vertices = area(0, 0, 0, 100).vertices }))
		Regions.Put(area(1, 0, 0, 100))
		assert.are.equal(2, #Regions.Describe(area(2, 0, 0, 100)))
	end)
end)
