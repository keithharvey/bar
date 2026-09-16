local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines

local function rect(name, x1, y1, x2, y2, team)
	return { name = name, team = team, poly = { { x = x1, y = y1 }, { x = x2, y = y2 } } }
end

local sevenRegions = assert(Layout.Parse({
	regions = {
		rect("nw", 0, 0, 40, 40),
		rect("ne", 160, 0, 200, 40),
		rect("se", 160, 160, 200, 200),
		rect("sw", 0, 160, 40, 200),
		rect("n", 80, 0, 120, 40),
		rect("s", 80, 160, 120, 200),
		rect("c", 80, 80, 120, 120),
	},
}, 200, 200))

local fourTeams = {
	{ teamID = 0, allyTeam = 1, x = 10, z = 10 },
	{ teamID = 1, allyTeam = 2, x = 190, z = 10 },
	{ teamID = 2, allyTeam = 3, x = 190, z = 190 },
	{ teamID = 3, allyTeam = 4, x = 10, z = 190 },
}

local function deal(teams, regions)
	return ModuleHandler.Evaluate(pipelines.mex_regions, Claims.Context(teams, regions))
end

describe("the deal", function()
	it("gives each team its nearest region first, then goes round again until none are left", function()
		local claims = deal(fourTeams, sevenRegions)
		assert.are.equal(0, claims.nw)
		assert.are.equal(1, claims.ne)
		assert.are.equal(2, claims.se)
		assert.are.equal(3, claims.sw)
		assert.are.equal(0, claims.n)
		assert.are.equal(2, claims.s)
		assert.are.equal(1, claims.c)
		local count = 0
		for _ in pairs(claims) do
			count = count + 1
		end
		assert.are.equal(7, count)
	end)

	it("with seven regions and four teams, one team holds one and the rest hold two", function()
		local holdings = Claims.Holdings(sevenRegions, deal(fourTeams, sevenRegions))
		local sizes = {}
		for teamID = 0, 3 do
			sizes[#sizes + 1] = #holdings[teamID]
		end
		table.sort(sizes)
		assert.are.same({ 1, 2, 2, 2 }, sizes)
	end)

	it("leaves teams beyond the regions holding nothing, and holds nothing with no teams", function()
		local two =
			assert(Layout.Parse({ regions = { rect("a", 0, 0, 10, 10), rect("b", 190, 190, 200, 200) } }, 200, 200))
		local claims = deal(fourTeams, two)
		assert.are.equal(0, claims.a)
		assert.are.equal(1, claims.b)
		assert.are.same({}, deal({}, two))
	end)

	it("binds a region with a team to that start, however far, and deals the rest by distance", function()
		local regions = assert(Layout.Parse({
			regions = {
				rect("far", 0, 0, 40, 40, 3),
				rect("mine", 160, 160, 200, 200, 3),
				rect("anyone", 80, 80, 120, 120),
				rect("nw", 0, 40, 40, 80),
			},
		}, 200, 200))
		local claims = deal(fourTeams, regions)
		assert.are.equal(2, claims["far@3"], "team 3 sits at the far corner, and the map says it is theirs")
		assert.are.equal(2, claims["mine@3"])
		assert.are.equal(0, claims.nw, "team 1 is nearest the free region beside far")
		assert.are.equal(1, claims.anyone, "the centre goes to whoever's turn is left")
	end)

	it("shares a team's regions between the teams that play from that start", function()
		local regions = assert(Layout.Parse({
			regions = { rect("a", 0, 0, 40, 40, 1), rect("b", 40, 0, 80, 40, 1), rect("c", 80, 0, 120, 40, 1) },
		}, 200, 200))
		local allies = {
			{ teamID = 0, allyTeam = 1, x = 10, z = 10 },
			{ teamID = 5, allyTeam = 1, x = 100, z = 10 },
			{ teamID = 1, allyTeam = 2, x = 190, z = 190 },
		}
		local claims = deal(allies, regions)
		assert.are.equal(0, claims["a@1"])
		assert.are.equal(5, claims["c@1"])
		assert.are.equal(0, claims["b@1"], "round two: team 0 is nearer b")
		local mine = 0
		for _, holder in pairs(claims) do
			assert.are_not.equal(1, holder)
			mine = mine + 1
		end
		assert.are.equal(3, mine)
	end)

	it("deals a region whose team has no start in this match as if it had none", function()
		local regions = assert(
			Layout.Parse({ regions = { rect("orphan", 0, 0, 40, 40, 9), rect("free", 160, 0, 200, 40) } }, 200, 200)
		)
		local claims = deal(fourTeams, regions)
		assert.are.equal(0, claims["orphan@9"])
		assert.are.equal(1, claims.free)
	end)
end)

describe("the spot holder fact", function()
	local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
	local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
	local MexRegions = VFS.Include("modules/economy/api.lua").MexRegions ---@type EconomyMexRegionsApi
	local state = VFS.Include("modules/economy/state.lua") ---@type EconomyState
	local EconomyEnums = VFS.Include("modules/economy/enums.lua")
	local resolved = ModuleHandler.LoadEnrichers(ConstructionContract.PlacementFacts)
	local mexIncome ---@type string
	local rules ---@type table<string, string>
	local params ---@type table<integer, string>
	local repo = {
		GetGameRulesParam = function(key)
			return rules[key]
		end,
		SetGameRulesParam = function(key, value)
			rules[key] = value
		end,
		GetTeamList = function()
			return { 0, 1, 2, 3 }
		end,
		GetTeamRulesParam = function(teamID)
			return params[teamID]
		end,
		SetTeamRulesParam = function(teamID, _, value)
			params[teamID] = value
		end,
	}
	local spots = { { x = 5, z = 5 }, { x = 195, z = 195 }, { x = 100, z = 100 }, { x = 60, z = 60 } }

	local function holderAt(spotX, spotZ, builderTeam)
		local ctx = {
			modOptions = { [EconomyEnums.ModOptions.MexSplitting] = mexIncome },
			x = spotX + 30,
			z = spotZ + 30,
			spotX = spotX,
			spotZ = spotZ,
			unitDefID = 7,
			builderTeam = builderTeam or 0,
		}
		return ModuleHandler.EnrichWith(resolved, nil, ctx, repo)[ConstructionContract.PlacementFacts.SpotHolder]
	end

	before_each(function()
		mexIncome = EconomyEnums.MexSplitting.MapAssigned
		rules, params = {}, {}
		state.mexRegions = sevenRegions
		MexRegions.Deal(fourTeams, repo, spots)
	end)

	it("is the team the deal handed the spot to, wherever the build lands", function()
		assert.are.equal(0, holderAt(5, 5, 3))
		assert.are.equal(2, holderAt(195, 195, 3))
		assert.are.equal(1, holderAt(100, 100, 3), "the centre went round to team 1")
	end)

	it("reduces each region to the spots inside it, published per team", function()
		local record = Shared.Holdings.Read(repo, 0) ---@type MexHoldingsRecord
		assert.are.same({ "nw", "n" }, record.regions)
		assert.are.same({ Shared.SpotKey(5, 5) }, record.spots)
		local byKey = Shared.HolderBySpot(repo, { 0, 1, 2, 3 })
		assert.are.equal(2, byKey[Shared.SpotKey(195.4, 194.6)], "keys round to whole elmos")
	end)

	it("is the builder's own for a spot no region reduced to", function()
		assert.are.equal(3, holderAt(60, 60, 3))
	end)

	it("has no say without a spot, even on ground a region covers", function()
		local ctx = {
			modOptions = { [EconomyEnums.ModOptions.MexSplitting] = mexIncome },
			x = 5,
			z = 5,
			unitDefID = 7,
			builderTeam = 3,
		}
		assert.are.equal(
			3,
			ModuleHandler.EnrichWith(resolved, nil, ctx, repo)[ConstructionContract.PlacementFacts.SpotHolder]
		)
	end)

	it("has no say unless mex income is Map Assigned", function()
		mexIncome = EconomyEnums.MexSplitting.None
		assert.are.equal(3, holderAt(5, 5, 3))
	end)

	it("survives the wire: the deal decodes to what was encoded", function()
		local claims = deal(fourTeams, sevenRegions)
		local back = assert(Deal.Decode(Deal.Encode(sevenRegions, claims)))
		assert.are.same(claims, back.claims)
		assert.are.equal(#sevenRegions, #back.regions)
		assert.are.same(sevenRegions[1].polygon, back.regions[1].polygon)
		assert.is_nil(Deal.Decode(""))
		assert.is_nil(Deal.Decode("not json"))
	end)
end)
