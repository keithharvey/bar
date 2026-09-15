local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

local pipelines = ModuleHandler.LoadPolicies(Modules.Economy) ---@type EconomyPipelines

local function rect(name, x1, y1, x2, y2)
	return { name = name, poly = { { x = x1, y = y1 }, { x = x2, y = y2 } } }
end

-- Seven regions on a 200x200 map: a corner for each of four teams, then three in between.
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
	{ teamID = 0, x = 10, z = 10 },
	{ teamID = 1, x = 190, z = 10 },
	{ teamID = 2, x = 190, z = 190 },
	{ teamID = 3, x = 10, z = 190 },
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
		-- second round: team 0 is nearest n (and c is equidistant to all, so name order breaks the tie)
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
end)

describe("the spot holder fact", function()
	local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
	local EconomyEnums = VFS.Include("modules/economy/enums.lua")
	local resolved = ModuleHandler.LoadEnrichers(ConstructionContract.PlacementFacts)
	local published ---@type string|nil
	local mexIncome ---@type string
	local springRepo = {
		GetGameRulesParam = function()
			return published
		end,
		GetModOptions = function()
			return { [EconomyEnums.ModOptions.MexSplitting] = mexIncome }
		end,
	}
	local function holderAt(x, z, builderTeam)
		local facts = ModuleHandler.EnrichWith(
			resolved,
			nil,
			{ x = x, z = z, unitDefID = 7, builderTeam = builderTeam or 0 },
			springRepo
		)
		return facts[ConstructionContract.PlacementFacts.SpotHolder]
	end

	before_each(function()
		mexIncome = EconomyEnums.MexSplitting.MapAssigned
		published = Deal.Encode(sevenRegions, deal(fourTeams, sevenRegions))
	end)

	it("is the holding team inside a dealt region, read back from the published deal", function()
		assert.are.equal(0, holderAt(5, 5, 3))
		assert.are.equal(2, holderAt(195, 195, 3))
	end)

	it("judges a mex by the spot it targets, not by where its footprint centre lands", function()
		local facts = ModuleHandler.EnrichWith(
			resolved,
			nil,
			{ x = 60, z = 60, spotX = 5, spotZ = 5, unitDefID = 7, builderTeam = 3 },
			springRepo
		)
		assert.are.equal(
			0,
			facts[ConstructionContract.PlacementFacts.SpotHolder],
			"the build lands outside, the spot is inside"
		)
	end)

	it("falls back to the builder before the deal and outside every region", function()
		published = nil
		assert.are.equal(3, holderAt(5, 5, 3))
		published = Deal.Encode(sevenRegions, deal(fourTeams, sevenRegions))
		assert.are.equal(3, holderAt(60, 60, 3))
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
