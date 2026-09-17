local Layout = VFS.Include("modules/economy/lib/mex_regions/layout.lua") ---@type MexRegionsLayout

describe("a mex regions layout", function()
	it("scales the startbox space onto the map and expands two corners into a rect", function()
		local regions = assert(Layout.Parse({
			regions = {
				{ name = "west", team = 1, group = "flank", poly = { { x = 0, y = 0 }, { x = 100, y = 200 } } },
			},
		}, 4000, 2000))
		assert.are.equal(1, #regions)
		assert.are.equal("mex_region", regions[1].type)
		assert.are.equal("west@1", regions[1].id)
		assert.are.equal("west", regions[1].name)
		assert.are.equal(1, regions[1].team)
		assert.are.equal("flank", regions[1].group)
		assert.are.same(
			{ { x = 0, z = 0 }, { x = 2000, z = 0 }, { x = 2000, z = 2000 }, { x = 0, z = 2000 } },
			regions[1].vertices
		)
	end)

	it("keeps a polygon's vertices", function()
		local regions = assert(Layout.Parse({
			regions = {
				{ name = "tri", team = 2, poly = { { x = 0, y = 0 }, { x = 200, y = 0 }, { x = 100, y = 200 } } },
			},
		}, 200, 200))
		assert.are.same({ { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 100, z = 200 } }, regions[1].vertices)
		assert.is_nil(regions[1].group)
	end)

	it("refuses what it cannot read, naming the region", function()
		local corners = { { x = 0, y = 0 }, { x = 1, y = 1 } }
		local _, reason =
			Layout.Parse({ regions = { { name = "a", team = 1, poly = { { x = 1, y = 1 } } } } }, 200, 200)
		assert.matches("region a needs a poly", reason)
		_, reason = Layout.Parse({ regions = { { poly = {} } } }, 200, 200)
		assert.matches("region 1 has no name", reason)
		_, reason = Layout.Parse({ regions = { { name = "a", poly = corners } } }, 200, 200)
		assert.matches("region a has no team", reason)
		_, reason = Layout.Parse({ regions = { { name = "a", team = 0, poly = corners } } }, 200, 200)
		assert.matches("not a start ordinal", reason)
		_, reason = Layout.Parse({
			regions = { { name = "a", team = 1, poly = corners }, { name = "a", team = 1, poly = corners } },
		}, 200, 200)
		assert.matches("two regions are named a for team 1", reason)
		_, reason = Layout.Parse({ regions = {} }, 200, 200)
		assert.matches("no regions", reason)
		_, reason = Layout.Parse("nonsense", 200, 200)
		assert.matches("a layout is", reason)
	end)

	it("lets two teams each have a region of the same name, and keeps the team through an export", function()
		local regions = assert(Layout.Parse({
			regions = {
				{ name = "anti1", team = 1, poly = { { x = 0, y = 0 }, { x = 10, y = 10 } } },
				{ name = "anti1", team = 2, poly = { { x = 190, y = 190 }, { x = 200, y = 200 } } },
			},
		}, 200, 200))
		assert.are.same({ "anti1@1", "anti1@2" }, { regions[1].id, regions[2].id })
		local back = Layout.Export(
			{ { name = "anti1", team = 2, vertices = { { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 0, z = 200 } } } },
			200,
			200
		)
		assert.are.equal(2, back.regions[1].team)
		assert.are.same({ x = 200, y = 0 }, back.regions[1].poly[2])
	end)
end)
