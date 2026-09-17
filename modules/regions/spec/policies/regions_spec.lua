local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Enums = VFS.Include("modules/regions/enums.lua")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

describe("the region types", function()
	it("come in dropdown order, each saying what it may be drawn as", function()
		local order, byKey = Regions.Types()
		assert.are.same({ "start", "mex_region" }, order)
		assert.are.same({ "point", "polygon" }, byKey.start.geometries)
		assert.are.same({ "polygon" }, byKey.mex_region.geometries)
		assert.are.equal("start", byKey.start.module)
		assert.are.equal("economy", byKey.mex_region.module)
	end)
end)

describe("checking a region", function()
	it("passes a whole polygon with its required fields", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, { name = "west", team = 1, vertices = square }, {}))
	end)

	it("collects every problem rather than stopping at the first", function()
		local problems = Regions.Check(Enums.Types.Start, { vertices = { { x = 0, z = 0 } } }, {})
		assert.are.same({ "a polygon needs at least three vertices", "a start needs a team" }, problems)
	end)

	it("refuses a shape the type cannot take, and a name a sibling already has", function()
		assert.are.same(
			{ "a mex region cannot be a point" },
			Regions.Check(Enums.Types.MexRegion, { name = "a", team = 1, x = 1, z = 1 }, {})
		)
		assert.are.same(
			{ "a mex region with name west already exists" },
			Regions.Check(
				Enums.Types.MexRegion,
				{ name = "west", team = 1, vertices = square },
				{ { name = "west", team = 1, x = 0, z = 0 } }
			)
		)
	end)

	it("checks only the fields when the region has no shape yet; a mex region needs its name and team first", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, { name = "soon", team = 1 }, {}, true))
		assert.are.same(
			{ "a mex region needs a name", "a mex region needs a team" },
			Regions.Check(Enums.Types.MexRegion, {}, {}, true)
		)
		assert.are.same(
			{ "a mex region with name soon already exists" },
			Regions.Check(Enums.Types.MexRegion, { name = "soon", team = 1 }, { { name = "soon", team = 1 } }, true)
		)
	end)

	it("a start may be a point or a polygon, and names its team", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, { team = 1, x = 5, z = 5 }, {}))
		assert.are.same({}, Regions.Check(Enums.Types.Start, { team = 2, vertices = square }, {}))
		assert.are.same({ "a start needs a team" }, Regions.Check(Enums.Types.Start, { x = 5, z = 5 }, {}))
	end)

	it("a mex region's name is unique within its team, so two teams may each have an anti1", function()
		local souths = { { name = "anti1", team = 2 } }
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, { name = "anti1", team = 1 }, souths, true))
		assert.are.same(
			{ "a mex region with name anti1 already exists" },
			Regions.Check(Enums.Types.MexRegion, { name = "anti1", team = 2 }, souths, true)
		)
		assert.are.same(
			{ "Team must be a number" },
			Regions.Check(Enums.Types.MexRegion, { name = "x", team = "south" }, {}, true)
		)
	end)
end)

describe("a disjoint type", function()
	local a = {
		name = "a",
		team = 1,
		vertices = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } },
	}
	local b = {
		name = "b",
		team = 1,
		vertices = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 }, { x = 50, z = 150 } },
	}
	local c = {
		name = "c",
		team = 2,
		vertices = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 }, { x = 500, z = 600 } },
	}

	it("never has two regions sharing ground", function()
		local _, byKey = Regions.Types()
		assert.is_true(byKey.mex_region.disjoint)
		assert.are.same({ "overlaps mex region a" }, Regions.Check(Enums.Types.MexRegion, b, { a, c }))
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, c, { a, b }))
	end)

	it("is a rule only for types that declare it, and only once there is a shape", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, { name = "b", team = 1 }, { a }, true))
		assert.are.same(
			{},
			Regions.Check(
				Enums.Types.Start,
				{ team = 2, vertices = b.vertices },
				{ { team = 1, vertices = a.vertices } }
			)
		)
	end)
end)

describe("a region's facts", function()
	it("come from the geometry alone when the asker knows nothing else", function()
		local facts = Regions.Facts({ type = "mex_region", name = "a", vertices = square }, {})
		assert.are.equal(10000, facts[Contract.Facts.Area])
		assert.are.same({ x = 50, z = 50 }, facts[Contract.Facts.Centre])
		assert.is_nil(facts[Contract.Facts.MetalSpots])
		assert.is_nil(facts[Contract.Facts.NearestStart])
	end)

	it("count the metal under the region and find the nearest start", function()
		local facts = Regions.Facts({ type = "mex_region", name = "a", vertices = square }, {
			spots = { { x = 10, z = 10, worth = 2 }, { x = 20, z = 20, worth = 1.5 }, { x = 500, z = 500, worth = 9 } },
			starts = { { allyTeam = 1, x = 1000, z = 1000 }, { allyTeam = 2, x = 60, z = 60 } },
		})
		assert.are.same({ count = 2, worth = 3.5 }, facts[Contract.Facts.MetalSpots])
		assert.are.equal(2, facts[Contract.Facts.NearestStart].allyTeam)
		local lines = Regions.FactLines(facts)
		assert.are.equal("Metal spots", lines[3][1])
	end)

	it("a point has no area and is its own centre", function()
		local facts = Regions.Facts({ type = "start", team = 1, x = 7, z = 9 }, {})
		assert.are.equal(0, facts[Contract.Facts.Area])
		assert.are.same({ x = 7, z = 9 }, facts[Contract.Facts.Centre])
	end)
end)
