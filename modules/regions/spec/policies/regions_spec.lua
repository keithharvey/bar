local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Enums = VFS.Include("modules/regions/enums.lua")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param fields table
---@return Region
local function mex(fields)
	fields.type = Enums.Types.MexRegion
	return fields
end

---@param fields table
---@return Region
local function start(fields)
	fields.type = Enums.Types.Start
	return fields
end

describe("the region types", function()
	it("come in dropdown order, each saying what it may be drawn as", function()
		local order, byKey = Regions.Types()
		assert.are.same({ "start", "mex_region" }, order)
		assert.are.same({ "point", "polygon" }, byKey.start.geometries)
		assert.are.same({ "polygon" }, byKey.mex_region.geometries)
		assert.are.equal("start", byKey.start.module)
		assert.are.equal("economy", byKey.mex_region.module)
		assert.are.equal("group", byKey.mex_region.nameFrom)
	end)
end)

describe("a region's name", function()
	it("is what the map gave it, or its type's nameFrom field, numbered once siblings share it", function()
		local names = Regions.Names(Enums.Types.MexRegion, {
			mex({ team = 1, group = "anti" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 2, group = "tech" }),
			mex({ team = 1, group = "tech", name = "given" }),
		})
		assert.are.same({ name = "anti", derived = true }, names[1])
		assert.are.same({ name = "tech_1", derived = true }, names[2])
		assert.are.same({ name = "tech_2", derived = true }, names[3])
		assert.are.same({ name = "tech", derived = true }, names[4], "another team's tech is the only one there")
		assert.are.same({ name = "given", derived = false }, names[5])
	end)

	it("falls back to the type's label when the field is empty, and to numbering for a type without one", function()
		local names = Regions.Names(Enums.Types.MexRegion, { mex({ team = 1 }), mex({ team = 1 }) })
		assert.are.same({ "mex_region_1", "mex_region_2" }, { names[1].name, names[2].name })
		local starts = Regions.Names(Enums.Types.Start, { start({ team = 1 }), start({ team = 2, name = "N" }) })
		assert.are.same({ "start", "N" }, { starts[1].name, starts[2].name })
	end)
end)

describe("checking a region", function()
	it("passes a whole polygon with its required fields", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = square }), {}))
	end)

	it("collects every problem rather than stopping at the first", function()
		local problems = Regions.Check(Enums.Types.MexRegion, mex({ vertices = { { x = 0, z = 0 } } }), {})
		assert.are.same(
			{ "a mex region cannot be a point", "a mex region needs a team", "a mex region needs a group" },
			problems
		)
	end)

	it("refuses a shape the type cannot take, and a name a sibling already has", function()
		assert.are.same(
			{ "a mex region cannot be a point" },
			Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = { { x = 1, z = 1 } } }), {})
		)
		assert.are.same(
			{ "a mex region with name west already exists" },
			Regions.Check(
				Enums.Types.MexRegion,
				mex({ name = "west", team = 1, group = "g", vertices = square }),
				{ mex({ name = "west", team = 1, group = "g", vertices = { { x = 0, z = 0 } } }) }
			)
		)
	end)

	it(
		"checks only the fields when the region has no shape yet; a mex region needs its team and group first",
		function()
			assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g" }), {}, true))
			assert.are.same(
				{ "a mex region needs a team", "a mex region needs a group" },
				Regions.Check(Enums.Types.MexRegion, mex({}), {}, true)
			)
		end
	)

	it("judges a derived name like a given one: unique within its team", function()
		local souths = { mex({ name = "anti", team = 2, group = "x" }) }
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "anti" }), souths, true))
		assert.are.same(
			{ "a mex region with name anti already exists" },
			Regions.Check(Enums.Types.MexRegion, mex({ team = 2, group = "anti" }), souths, true)
		)
		assert.are.same(
			{ "Team must be a number" },
			Regions.Check(Enums.Types.MexRegion, mex({ team = "south", group = "g" }), {}, true)
		)
	end)

	it("two vertices are neither a point nor a polygon", function()
		assert.are.same(
			{ "two vertices make neither a point nor a polygon" },
			Regions.Check(Enums.Types.Start, start({ team = 1, vertices = { { x = 0, z = 0 }, { x = 5, z = 5 } } }), {})
		)
		assert.are.same(
			{ "a region is a point or a polygon" },
			Regions.Check(Enums.Types.Start, start({ team = 1 }), {})
		)
	end)

	it("a start may be a point or a polygon, and names its team", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1, vertices = { { x = 5, z = 5 } } }), {}))
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 2, vertices = square }), {}))
		assert.are.same(
			{ "a start needs a team" },
			Regions.Check(Enums.Types.Start, start({ vertices = { { x = 5, z = 5 } } }), {})
		)
	end)
end)

describe("a set of regions", function()
	local a = mex({ name = "a", team = 1, group = "g", vertices = square })
	local b = mex({
		name = "a",
		team = 1,
		group = "h",
		vertices = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } },
	})
	local c = mex({ team = 2, group = "g", vertices = square })

	it("is checked region by region, every problem naming its region", function()
		assert.are.same(
			{ "a: a mex region with name a already exists", "a: a mex region with name a already exists" },
			Regions.CheckSet(Enums.Types.MexRegion, { a, b, c })
		)
		assert.are.same({}, Regions.CheckSet(Enums.Types.MexRegion, { a, c }))
	end)
end)

describe("a region's facts", function()
	it("come from the geometry alone when the asker knows nothing else", function()
		local facts = Regions.Facts(mex({ team = 1, group = "a", vertices = square }), {})
		assert.are.equal(10000, facts[Contract.Facts.Area])
		assert.are.same({ x = 50, z = 50 }, facts[Contract.Facts.Centre])
		assert.is_nil(facts[Contract.Facts.MetalSpots])
		assert.is_nil(facts[Contract.Facts.NearestStart])
	end)

	it("count the metal under the region and find the nearest start", function()
		local facts = Regions.Facts(mex({ team = 1, group = "a", vertices = square }), {
			spots = { { x = 10, z = 10, worth = 2 }, { x = 20, z = 20, worth = 1.5 }, { x = 500, z = 500, worth = 9 } },
			starts = { { allyTeam = 1, x = 1000, z = 1000 }, { allyTeam = 2, x = 60, z = 60 } },
		})
		assert.are.same({ count = 2, worth = 3.5 }, facts[Contract.Facts.MetalSpots])
		assert.are.equal(2, facts[Contract.Facts.NearestStart].allyTeam)
		local lines = Regions.FactLines(facts)
		assert.are.equal("Metal spots", lines[3][1])
	end)

	it("a point has no area and is its own centre", function()
		local facts = Regions.Facts(start({ team = 1, vertices = { { x = 7, z = 9 } } }), {})
		assert.are.equal(0, facts[Contract.Facts.Area])
		assert.are.same({ x = 7, z = 9 }, facts[Contract.Facts.Centre])
	end)
end)
