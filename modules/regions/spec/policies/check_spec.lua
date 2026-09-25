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

describe("checking a region", function()
	it("passes a whole polygon or a point with its required fields", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1, vertices = square }), {}))
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1, vertices = { { x = 5, z = 5 } } }), {}))
	end)

	it("collects every problem rather than stopping at the first", function()
		local problems =
			Regions.Check(Enums.Types.Start, start({ vertices = { { x = 0, z = 0 }, { x = 1, z = 1 } } }), {})
		assert.are.same({ "two vertices make neither a point nor a polygon", "a start needs a team" }, problems)
		assert.are.same(
			{ "a region is a point or a polygon" },
			Regions.Check(Enums.Types.Start, start({ team = 1 }), {})
		)
	end)

	it("refuses a value a sibling already has where the type says it is unique", function()
		assert.are.same(
			{ "a start with team 1 already exists" },
			Regions.Check(
				Enums.Types.Start,
				start({ team = 1, vertices = square }),
				{ start({ team = 1, vertices = far }) }
			)
		)
		assert.are.same(
			{ "Team must be a number" },
			Regions.Check(Enums.Types.Start, start({ team = "north", vertices = square }), {})
		)
	end)

	it("checks only the fields when the region has no shape yet", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1 }), {}, true))
		assert.are.same({ "a start needs a team" }, Regions.Check(Enums.Types.Start, start({}), {}, true))
	end)
end)
