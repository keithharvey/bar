local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local EconomyEnums = VFS.Include("modules/economy/enums.lua")
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared

Policies.On(Contract.MexRegions)
	.Refusal(function()
		return {}
	end)
	.Answer(Contract.MexRegions.NearestRoundRobin, function(ctx)
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

		local held = {} ---@type MexRegionsClaims
		for _ = 1, #ctx.regions do
			if not round(held) then
				return held
			end
		end
		return held
	end)

local readDeal = Deal.Reader()

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.SpotHolder, function(ctx, springRepo)
		local engine = springRepo or Spring
		if engine.GetModOptions()[EconomyEnums.ModOptions.MexSplitting] ~= EconomyEnums.MexSplitting.MapAssigned then
			return nil
		end
		if ctx.spotX and ctx.spotZ then
			local byKey = Shared.HolderBySpot(engine, engine.GetTeamList())
			return byKey[Shared.SpotKey(ctx.spotX, ctx.spotZ)]
		end
		local deal = readDeal(engine)
		if deal == nil then
			return nil
		end
		return Claims.OwnerAt(deal.regions, deal.claims, ctx.x, ctx.z)
	end)
