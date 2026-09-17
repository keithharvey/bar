local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local RegionEnums = VFS.Include("modules/regions/enums.lua")
local Records = VFS.Include("modules/economy/lib/mex_regions/records.lua") ---@type MexRegionsRecords
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines

local function rect(name, team, x1, y1, x2, y2)
	return { name = name, team = team, group = "g", poly = { { x = x1, y = y1 }, { x = x2, y = y2 } } }
end

---@return MexRegion[]
local function parse(entries)
	local regions, reason = Regions.ParseLayout(
		{ regions = { [RegionEnums.Types.MexRegion] = entries } },
		RegionEnums.Types.MexRegion,
		200,
		200
	)
	assert(regions, reason)
	return Records.From(regions)
end

-- four starts in the corners; n, s and c belong to a fifth start nobody sits at this match
local sevenRegions = parse({
	rect("nw", 1, 0, 0, 40, 40),
	rect("ne", 2, 160, 0, 200, 40),
	rect("se", 3, 160, 160, 200, 200),
	rect("sw", 4, 0, 160, 40, 200),
	rect("n", 9, 80, 0, 120, 40),
	rect("s", 9, 80, 160, 120, 200),
	rect("c", 9, 80, 80, 120, 120),
})

local fourTeams = {
	{ teamID = 0, allyTeam = 1, x = 10, z = 10 },
	{ teamID = 1, allyTeam = 2, x = 190, z = 10 },
	{ teamID = 2, allyTeam = 3, x = 190, z = 190 },
	{ teamID = 3, allyTeam = 4, x = 10, z = 190 },
}

-- one spot in each region
local spots = {
	{ x = 5, z = 5 },
	{ x = 195, z = 5 },
	{ x = 195, z = 195 },
	{ x = 5, z = 195 },
	{ x = 100, z = 20 },
	{ x = 100, z = 180 },
	{ x = 100, z = 100 },
}

---@return MexRegionsDeal
local function deal(teams, regions, metal)
	return ModuleHandler.Evaluate(pipelines.mex_regions, { regions = regions, spots = metal or spots, teams = teams })
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

describe("the deal", function()
	it("binds a region to the team seated at its start, and deals a start nobody sits at round everyone", function()
		local d = deal(fourTeams, sevenRegions)
		assert.are.same({}, d.problems)
		assert.are.equal(0, d.regions["nw@1"])
		assert.are.equal(1, d.regions["ne@2"])
		assert.are.equal(2, d.regions["se@3"])
		assert.are.equal(3, d.regions["sw@4"])
		assert.are.equal(0, d.regions["n@9"], "nearest free region for the first team round")
		assert.are.equal(1, d.regions["c@9"], "n was gone, so team 1 took the centre")
		assert.are.equal(2, d.regions["s@9"])
		assert.are.equal(7, count(d.regions))
	end)

	it("claims each spot for the team holding the region it lies in", function()
		local d = deal(fourTeams, sevenRegions)
		assert.are.equal(0, d.spots[Shared.SpotKey(5, 5)])
		assert.are.equal(0, d.spots[Shared.SpotKey(100, 20)])
		assert.are.equal(1, d.spots[Shared.SpotKey(100, 100)])
		assert.are.equal(2, d.spots[Shared.SpotKey(100, 180)])
		assert.are.equal(3, d.spots[Shared.SpotKey(5, 195)])
		assert.are.equal(7, count(d.spots))
	end)

	it("shares a start's regions between the teams seated there, nearest first, round by round", function()
		local regions = parse({ rect("a", 1, 0, 0, 40, 40), rect("b", 1, 40, 0, 80, 40), rect("c", 1, 80, 0, 120, 40) })
		local allies = {
			{ teamID = 0, allyTeam = 1, x = 10, z = 10 },
			{ teamID = 5, allyTeam = 1, x = 100, z = 10 },
			{ teamID = 1, allyTeam = 2, x = 190, z = 190 },
		}
		local d = deal(allies, regions, { { x = 20, z = 20 }, { x = 60, z = 20 }, { x = 100, z = 20 } })
		assert.are.same({}, d.problems, "neighbours may share an edge")
		assert.are.equal(0, d.regions["a@1"])
		assert.are.equal(5, d.regions["c@1"])
		assert.are.equal(0, d.regions["b@1"], "round two: team 0 is nearer b")
		for _, holder in pairs(d.regions) do
			assert.are_not.equal(1, holder, "team 1 sits at another start")
		end
	end)

	it("leaves teams beyond the regions holding nothing, and deals nothing to no teams", function()
		local two = parse({ rect("a", 1, 0, 0, 10, 10), rect("b", 2, 190, 190, 200, 200) })
		local metal = { { x = 5, z = 5 }, { x = 195, z = 195 } }
		local d = deal(fourTeams, two, metal)
		assert.are.equal(0, d.regions["a@1"])
		assert.are.equal(1, d.regions["b@2"])
		assert.are.equal(2, count(d.regions))
		local none = deal({}, two, metal)
		assert.are.same({}, none.regions)
		assert.are.same({}, none.spots)
		assert.are.same({}, none.problems)
	end)

	it("is refused when the layout fails its type, naming the region and the problem", function()
		local overlapping = parse({ rect("a", 1, 0, 0, 40, 40), rect("b", 2, 20, 20, 60, 60) })
		local d = deal(fourTeams, overlapping, { { x = 5, z = 5 } })
		assert.are.same({}, d.regions)
		assert.are.same({}, d.spots)
		assert.are.same({ "a: overlaps mex region b", "b: overlaps mex region a" }, d.problems)
	end)

	it("is refused when a metal spot lies in no region", function()
		local d = deal(fourTeams, sevenRegions, { { x = 5, z = 5 }, { x = 60, z = 60 }, { x = 61, z = 61 } })
		assert.are.same({}, d.regions)
		assert.are.same({ "2 metal spots in no mex region: 60, 60; 61, 61" }, d.problems)
	end)

	it("is refused on a map with no metal spots, since a mex is judged by the spot it mines", function()
		local d = deal(fourTeams, sevenRegions, {})
		assert.are.same({}, d.regions)
		assert.are.same({ "the map has no metal spots to deal" }, d.problems)
	end)
end)

describe("the spot holder fact", function()
	local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
	local MexRegions = VFS.Include("modules/economy/api.lua").MexRegions ---@type EconomyMexRegionsApi
	local state = VFS.Include("modules/economy/state.lua") ---@type EconomyState
	local EconomyEnums = VFS.Include("modules/economy/enums.lua")
	local resolved = ModuleHandler.LoadEnrichers(ConstructionContract.PlacementFacts)
	local mexSplitting ---@type string
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

	local function holderAt(spotX, spotZ, builderTeam)
		local ctx = {
			modOptions = { [EconomyEnums.ModOptions.MexSplitting] = mexSplitting },
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
		mexSplitting = EconomyEnums.MexSplitting.MapAssigned
		rules, params = {}, {}
		state.mexRegions = sevenRegions
		MexRegions.Deal(fourTeams, repo, spots)
	end)

	it("is the team the deal handed the spot to, wherever the build lands", function()
		assert.are.equal(0, holderAt(5, 5, 3))
		assert.are.equal(2, holderAt(195, 195, 3))
		assert.are.equal(1, holderAt(100, 100, 3), "the centre went round to team 1")
	end)

	it("publishes each team's regions and the spots inside them", function()
		local record = Shared.Holdings.Read(repo, 0) ---@type MexHoldingsRecord
		assert.are.same({ "nw@1", "n@9" }, record.regions)
		assert.are.same({ Shared.SpotKey(100, 20), Shared.SpotKey(5, 5) }, record.spots)
		local byKey = Shared.HolderBySpot(repo, { 0, 1, 2, 3 })
		assert.are.equal(2, byKey[Shared.SpotKey(195.4, 194.6)], "keys round to whole elmos")
		assert.are.same(
			{ [0] = { "nw@1", "n@9" }, [1] = { "ne@2", "c@9" }, [2] = { "se@3", "s@9" }, [3] = { "sw@4" } },
			MexRegions.Holdings()
		)
	end)

	it("is the builder's own for a spot the deal never saw", function()
		assert.are.equal(3, holderAt(60, 60, 3))
	end)

	it("has no say without a spot, even on ground a region covers", function()
		local ctx = {
			modOptions = { [EconomyEnums.ModOptions.MexSplitting] = mexSplitting },
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

	it("has no say unless Mex Splitting is Map Assigned", function()
		mexSplitting = EconomyEnums.MexSplitting.None
		assert.are.equal(3, holderAt(5, 5, 3))
	end)

	it("survives the wire: the deal decodes to what was encoded", function()
		local d = deal(fourTeams, sevenRegions)
		local back = assert(Deal.Decode(Deal.Encode(sevenRegions, d.regions)))
		assert.are.same(d.regions, back.holders)
		assert.are.equal(#sevenRegions, #back.regions)
		assert.are.same(sevenRegions[1].vertices, back.regions[1].vertices)
		assert.is_nil(Deal.Decode(""))
		assert.is_nil(Deal.Decode("not json"))
	end)
end)
