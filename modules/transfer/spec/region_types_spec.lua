local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param fields table
---@return Region
local function mex(fields)
	fields.type = Regions.Enums.Types.MexRegion
	return fields
end

describe("the mex region type", function()
	it("is transfer's, drawn as a polygon only", function()
		local order, byKey = Regions.Types()
		assert.are.same({ "start", "mex_region" }, order, "start first: transfer is built on start")
		assert.are.same({ "polygon" }, byKey.mex_region.geometries)
		assert.are.equal("transfer", byKey.mex_region.module)
		assert.are.same(
			{ "a mex region cannot be a point" },
			Regions.Check(
				Regions.Enums.Types.MexRegion,
				mex({ team = 1, group = "g", vertices = { { x = 1, z = 1 } } }),
				{}
			)
		)
	end)

	it("needs its team and group before its first vertex; a name is optional", function()
		assert.are.same({}, Regions.Check(Regions.Enums.Types.MexRegion, mex({ team = 1, group = "g" }), {}, true))
		assert.are.same(
			{ "a mex region needs a team", "a mex region needs a group" },
			Regions.Check(Regions.Enums.Types.MexRegion, mex({}), {}, true)
		)
		assert.are.same(
			{},
			Regions.Check(Regions.Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = square }), {})
		)
	end)

	it("may share a name with a sibling: the id is the identity, the name is a label", function()
		local souths = { mex({ name = "anti", team = 2, group = "x" }) }
		assert.are.same(
			{},
			Regions.Check(Regions.Enums.Types.MexRegion, mex({ team = 1, group = "anti" }), souths, true)
		)
		assert.are.same(
			{},
			Regions.Check(Regions.Enums.Types.MexRegion, mex({ team = 2, group = "anti" }), souths, true)
		)
	end)
end)

describe("a mex region in the store", function()
	it("offers the groups its siblings already carry", function()
		Regions.Clear()
		Regions.Put(mex({ team = 1, group = "anti", vertices = square }))
		Regions.Put(mex({ team = 2, group = "tech", vertices = square }))
		assert.are.same({ group = { "anti", "tech" } }, Regions.Suggestions(Regions.Enums.Types.MexRegion))
		Regions.Clear()
	end)
end)
