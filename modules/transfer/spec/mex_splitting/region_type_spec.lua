local Enums = require("modules/regions/enums")
local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param fields table
---@return Region
local function mex(fields)
	fields.type = Enums.Types.MexRegion
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
			Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = { { x = 1, z = 1 } } }), {})
		)
	end)

	it("needs its team and group before its first vertex; a name is optional", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g" }), {}, true))
		assert.are.same(
			{ "a mex region needs a team", "a mex region needs a group" },
			Regions.Check(Enums.Types.MexRegion, mex({}), {}, true)
		)
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = square }), {}))
	end)

	it("is called after its group when it carries no name, numbered once siblings share the group", function()
		local names = Regions.Names(Enums.Types.MexRegion, {
			mex({ team = 1, group = "anti" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 2, group = "tech" }),
			mex({ team = 1, group = "tech", name = "given" }),
			mex({ team = 1 }),
		})
		local given = {}
		for i, named in ipairs(names) do
			given[i] = named.name
		end
		assert.are.same({ "anti", "tech_1", "tech_2", "tech_3", "given", "mex_region" }, given)
		assert.is_false(names[5].derived)
	end)

	it("may share a name with a sibling: the id is the identity, the name is a label", function()
		local souths = { mex({ name = "anti", team = 2, group = "x" }) }
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "anti" }), souths, true))
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 2, group = "anti" }), souths, true))
	end)

	it("says where the first uncovered metal spot is, so an editor can take the map maker there", function()
		local a = mex({ name = "a", team = 1, group = "g", vertices = square })
		local problems = Regions.CheckSet(Enums.Types.MexRegion, { a }, {
			spots = { { x = 50, z = 50 }, { x = 700, z = 300 }, { x = 900, z = 900 } },
		})
		assert.are.same({ { message = "2 metal spots in no mex region", at = { x = 700, z = 300 } } }, problems)
	end)

	it("may share ground with a sibling: coverage is its rule, not disjointness", function()
		local a = mex({ name = "a", team = 1, group = "g", vertices = square })
		local b = mex({
			name = "b",
			team = 1,
			group = "g",
			vertices = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 } },
		})
		assert.are.same({}, Regions.CheckSet(Enums.Types.MexRegion, { a, b }))
	end)
end)

describe("a mex region in the store", function()
	it("offers the groups its siblings already carry", function()
		Regions.Clear()
		Regions.Put(mex({ team = 1, group = "anti", vertices = square }))
		Regions.Put(mex({ team = 2, group = "tech", vertices = square }))
		assert.are.same({ group = { "anti", "tech" } }, Regions.Suggestions(Enums.Types.MexRegion))
		Regions.Clear()
	end)
end)

describe("what mex splitting says about a region", function()
	it(
		"is the region's team and group, the metal spots inside and their worth when the map's spots are given",
		function()
			local d = Regions.Describe(mex({ name = "a", team = 1, group = "g", vertices = square }), {
				spots = {
					{ x = 10, z = 10, worth = 2000 },
					{ x = 20, z = 20, worth = 1500 },
					{ x = 500, z = 500, worth = 9 },
				},
			})
			assert.are.equal(1, d.team)
			assert.are.equal("g", d.group)
			assert.are.equal(2, d.spots)
			assert.are.equal(3.5, d.worth)
			assert.are.equal(10000, d.area)
		end
	)

	it("knows no spots when the map's are not given", function()
		local d = Regions.Describe(mex({ name = "a", team = 1, group = "g", vertices = square }), {})
		assert.is_nil(d.spots)
		assert.are.equal("g", d.group)
	end)
end)
