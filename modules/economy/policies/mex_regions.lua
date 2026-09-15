local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local EconomyEnums = VFS.Include("modules/economy/enums.lua")
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib

-- The deal. Each team in turn takes its nearest region nobody holds yet, round after round, until
-- every region is held. Seven regions and four teams: three teams hold two, one holds one, and
-- which one is whoever's turn came last in the second round.
Policies.On(Contract.MexRegions)
	.Refusal(function()
		return {}
	end)
	.Answer(Contract.MexRegions.NearestRoundRobin, function(ctx)
		---The team's nearest region nobody holds, or nil when every region it can see is held.
		---@param team MexRegionsTeamView
		---@param held MexRegionsClaims
		---@return MexRegionsRanked|nil
		local function nearestFree(team, held)
			for _, ranked in ipairs(team.regions) do
				if held[ranked.name] == nil then
					return ranked
				end
			end
			return nil
		end

		---One round: each team in turn takes its nearest free region. True when anyone took one.
		---@param held MexRegionsClaims
		---@return boolean
		local function round(held)
			local took = false
			for _, team in ipairs(ctx.teams) do
				local pick = nearestFree(team, held)
				if pick then
					held[pick.name] = team.teamID
					took = true
				end
			end
			return took
		end

		-- Every round deals at least one region or ends the deal, so there are at most as many
		-- rounds as regions. A region nobody takes is held by nobody: open to all.
		local held = {} ---@type MexRegionsClaims
		for _ = 1, #ctx.regions do
			if not round(held) then
				return held
			end
		end
		return held
	end)

local readDeal = Deal.Reader()

-- Construction's spot holder, under Map Assigned: the team holding the region under the spot, read
-- from the deal the synced side published. Declines otherwise, before the deal, outside every
-- region, and in a region nobody holds, so construction's default answers: the builder holds it.
-- A policy file runs in the plain global environment, not a gadget's, so it reads through the
-- engine rather than the module's state.
Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.SpotHolder, function(ctx, springRepo)
		local engine = springRepo or Spring
		if engine.GetModOptions()[EconomyEnums.ModOptions.MexSplitting] ~= EconomyEnums.MexSplitting.MapAssigned then
			return nil
		end
		local deal = readDeal(engine)
		if deal == nil then
			return nil
		end
		return Claims.OwnerAt(deal.regions, deal.claims, ctx.x, ctx.z)
	end)
