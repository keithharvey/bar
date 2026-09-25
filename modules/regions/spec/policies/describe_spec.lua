local Enums = require("modules/regions/enums")
local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }
local far = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } }

---@param fields table
---@return Region
local function start(fields)
	fields.type = Enums.Types.Start
	return fields
end

describe("what is said about a region", function()
	it("is the shape's facts for a type nobody describes, and the type owner's record for one somebody does", function()
		local d = Regions.Describe({ type = "nobody_knows", vertices = square })
		assert.are.same({ area = 10000, centre = { x = 50, z = 50 } }, d)
		local s = Regions.Describe(start({ team = 1, vertices = square }), {})
		assert.are.equal(10000, s.area)
		assert.are.equal(1, s.team, "start answers for its own type, on top of the shape")
	end)

	it("a point has no area and is its own centre", function()
		local d = Regions.Describe({ type = "nobody_knows", vertices = { { x = 7, z = 9 } } })
		assert.are.same({ area = 0, centre = { x = 7, z = 9 } }, d)
	end)
end)
