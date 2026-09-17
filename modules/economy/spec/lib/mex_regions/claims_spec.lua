local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Layout = VFS.Include("modules/economy/lib/mex_regions/layout.lua") ---@type MexRegionsLayout
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared

local function rect(name, team, x1, y1, x2, y2)
	return { name = name, team = team, poly = { { x = x1, y = y1 }, { x = x2, y = y2 } } }
end

describe("the deal's steps", function()
	local regions = assert(Layout.Parse({
		regions = {
			rect("near", 1, 0, 0, 20, 20),
			rect("far", 2, 180, 180, 200, 200),
			rect("mid", 1, 90, 90, 110, 110),
		},
	}, 200, 200))

	it("rank every region from where each team starts, nearest first", function()
		local views = Claims.Rank({
			{ teamID = 0, allyTeam = 1, x = 0, z = 0 },
			{ teamID = 1, allyTeam = 2, x = 200, z = 200 },
		}, regions)
		assert.are.equal(2, #views)
		local names = {}
		for i, ranked in ipairs(views[1].regions) do
			names[i] = ranked.region.name
		end
		assert.are.same({ "near", "mid", "far" }, names)
		assert.are.equal("far", views[2].regions[1].region.name)
		assert.are.equal(1, views[2].team.teamID)
		assert.is_true(views[1].regions[1].distance < views[1].regions[2].distance)
	end)

	it("place each spot in the region that covers it, and set aside the ones none does", function()
		local byRegion, open = Claims.SpotsIn(regions, { { x = 5, z = 5 }, { x = 100, z = 100 }, { x = 150, z = 150 } })
		assert.are.same({ [Shared.SpotKey(5, 5)] = true }, { [byRegion["near@1"][1]] = true })
		assert.are.same({ Shared.SpotKey(100, 100) }, byRegion["mid@1"])
		assert.is_nil(byRegion["far@2"])
		assert.are.same({ Shared.SpotKey(150, 150) }, open)
	end)

	it("list each team's holdings in layout order", function()
		assert.are.same(
			{ [0] = { "near@1", "mid@1" }, [1] = { "far@2" } },
			Claims.Holdings(regions, { ["near@1"] = 0, ["far@2"] = 1, ["mid@1"] = 0 })
		)
	end)

	it("find nothing wrong with a layout its type accepts, and name what the type refuses", function()
		assert.are.same({}, Claims.Problems(regions))
		local overlapping = assert(Layout.Parse({
			regions = { rect("a", 1, 0, 0, 40, 40), rect("b", 1, 20, 20, 60, 60) },
		}, 200, 200))
		assert.are.same({ "a@1: overlaps mex region b", "b@1: overlaps mex region a" }, Claims.Problems(overlapping))
	end)
end)
