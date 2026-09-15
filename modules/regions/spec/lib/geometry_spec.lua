local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

describe("region geometry", function()
	local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

	it("measures a polygon and finds its middle", function()
		assert.are.equal(10000, Geometry.Area(square))
		local x, z = Geometry.Centroid(square)
		assert.are.equal(50, x)
		assert.are.equal(50, z)
		assert.are.equal(0, Geometry.Area({ { x = 0, z = 0 }, { x = 1, z = 1 } }))
	end)

	it("knows when two polygons share ground", function()
		local shifted = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 }, { x = 50, z = 150 } }
		local apart = { { x = 200, z = 200 }, { x = 300, z = 200 }, { x = 300, z = 300 }, { x = 200, z = 300 } }
		local crossing = { { x = 40, z = -20 }, { x = 60, z = -20 }, { x = 60, z = 120 }, { x = 40, z = 120 } }
		assert.is_true(Geometry.Overlaps(square, shifted))
		assert.is_false(Geometry.Overlaps(square, apart))
		assert.is_true(Geometry.Overlaps(square, crossing), "no vertex inside, but the edges cross")
	end)

	it("knows what is inside, concave corners included", function()
		assert.is_true(Geometry.Contains(50, 50, square))
		assert.is_false(Geometry.Contains(150, 50, square))
		local ell = {
			{ x = 0, z = 0 },
			{ x = 100, z = 0 },
			{ x = 100, z = 50 },
			{ x = 50, z = 50 },
			{ x = 50, z = 100 },
			{ x = 0, z = 100 },
		}
		assert.is_true(Geometry.Contains(25, 75, ell))
		assert.is_false(Geometry.Contains(75, 75, ell))
	end)
end)
