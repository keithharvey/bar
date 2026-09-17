local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout

describe("a mex regions layout", function()
	it("scales the startbox space onto the map and expands two corners into a rect", function()
		local regions = assert(Layout.Parse({
			regions = { { name = "west", group = "flank", poly = { { x = 0, y = 0 }, { x = 100, y = 200 } } } },
		}, 4000, 2000))
		assert.are.equal(1, #regions)
		assert.are.equal("west", regions[1].name)
		assert.are.equal("flank", regions[1].group)
		assert.are.same({ { 0, 0 }, { 2000, 0 }, { 2000, 2000 }, { 0, 2000 } }, regions[1].polygon)
		assert.are.equal(1000, regions[1].centerX)
		assert.are.equal(1000, regions[1].centerZ)
	end)

	it("keeps a polygon's vertices and centres it on them", function()
		local regions = assert(Layout.Parse({
			regions = { { name = "tri", poly = { { x = 0, y = 0 }, { x = 200, y = 0 }, { x = 100, y = 200 } } } },
		}, 200, 200))
		assert.are.same({ { 0, 0 }, { 200, 0 }, { 100, 200 } }, regions[1].polygon)
		assert.are.equal(100, regions[1].centerX)
		assert.is_nil(regions[1].group)
	end)

	it("refuses what it cannot read, naming the region", function()
		local _, reason = Layout.Parse({ regions = { { name = "a", poly = { { x = 1, y = 1 } } } } }, 200, 200)
		assert.matches("region a needs a poly", reason)
		_, reason = Layout.Parse({ regions = { { poly = {} } } }, 200, 200)
		assert.matches("region 1 has no name", reason)
		_, reason = Layout.Parse({
			regions = {
				{ name = "a", poly = { { x = 0, y = 0 }, { x = 1, y = 1 } } },
				{ name = "a", poly = { { x = 0, y = 0 }, { x = 1, y = 1 } } },
			},
		}, 200, 200)
		assert.matches("two regions are named a", reason)
		_, reason = Layout.Parse({ regions = {} }, 200, 200)
		assert.matches("no regions", reason)
		_, reason = Layout.Parse(
			{ regions = { { name = "a", team = 0, poly = { { x = 0, y = 0 }, { x = 1, y = 1 } } } } },
			200,
			200
		)
		assert.matches("not a start ordinal", reason)
	end)

	it("keeps a region's team, and lets two teams each have a region of the same name", function()
		local regions = assert(Layout.Parse({
			regions = {
				{ name = "anti1", team = 1, poly = { { x = 0, y = 0 }, { x = 10, y = 10 } } },
				{ name = "anti1", team = 2, poly = { { x = 190, y = 190 }, { x = 200, y = 200 } } },
				{ name = "mid", poly = { { x = 90, y = 90 }, { x = 110, y = 110 } } },
			},
		}, 200, 200))
		assert.are.same({ "anti1@1", "anti1@2", "mid" }, { regions[1].id, regions[2].id, regions[3].id })
		assert.are.equal(2, regions[2].team)
		assert.is_nil(regions[3].team)
		local _, reason = Layout.Parse({
			regions = {
				{ name = "anti1", team = 1, poly = { { x = 0, y = 0 }, { x = 10, y = 10 } } },
				{ name = "anti1", team = 1, poly = { { x = 190, y = 190 }, { x = 200, y = 200 } } },
			},
		}, 200, 200)
		assert.matches("two regions are named anti1 for team 1", reason)
		local back = Layout.Export(
			{ { name = "anti1", team = 2, vertices = { { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 0, z = 200 } } } },
			200,
			200
		)
		assert.are.equal(2, back.regions[1].team)
		_, reason = Layout.Parse("nonsense", 200, 200)
		assert.matches("a layout is", reason)
	end)
end)
