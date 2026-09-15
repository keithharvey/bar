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
		_, reason = Layout.Parse("nonsense", 200, 200)
		assert.matches("a layout is", reason)
	end)
end)
