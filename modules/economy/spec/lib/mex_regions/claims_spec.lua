local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout

local function rect(name, x1, y1, x2, y2, group)
	return { name = name, group = group, poly = { { x = x1, y = y1 }, { x = x2, y = y2 } } }
end

describe("the deal's context", function()
	local regions = assert(Layout.Parse({
		regions = { rect("near", 0, 0, 20, 20), rect("far", 180, 180, 200, 200), rect("mid", 90, 90, 110, 110) },
	}, 200, 200))

	it("ranks every region from each team's start, nearest first, with its ordinal", function()
		local ctx = Claims.Context({ { teamID = 0, x = 0, z = 0 }, { teamID = 1, x = 200, z = 200 } }, regions)
		assert.are.equal(2, #ctx.teams)
		local names = {}
		for i, ranked in ipairs(ctx.teams[1].regions) do
			names[i] = ranked.name .. ranked.ordinal
		end
		assert.are.same({ "near1", "mid2", "far3" }, names)
		assert.are.equal("far", ctx.teams[2].regions[1].name)
		assert.are.equal(1, ctx.teams[2].regions[1].ordinal)
		assert.are.equal(1, ctx.teams[2].teamID)
		assert.is_true(ctx.teams[1].regions[1].distance < ctx.teams[1].regions[2].distance)
	end)

	it("finds the region under a point and who holds it", function()
		local claims = { near = 0, far = 1 }
		assert.are.equal("mid", Claims.RegionAt(regions, 100, 100).name)
		assert.is_nil(Claims.RegionAt(regions, 50, 50))
		assert.are.equal(0, Claims.OwnerAt(regions, claims, 5, 5))
		assert.are.equal(1, Claims.OwnerAt(regions, claims, 190, 190))
		assert.is_nil(Claims.OwnerAt(regions, claims, 100, 100), "held by nobody")
		assert.is_nil(Claims.OwnerAt(regions, claims, 50, 50), "outside every region")
	end)

	it("lists each team's holdings in layout order", function()
		assert.are.same(
			{ [0] = { "near", "mid" }, [1] = { "far" } },
			Claims.Holdings(regions, { near = 0, far = 1, mid = 0 })
		)
	end)
end)
