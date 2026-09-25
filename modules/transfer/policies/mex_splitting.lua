local Claims = require("modules/transfer/mex_splitting/claims")
local ConstructionContract = require("modules/construction/contract")
local Contract = require("modules/transfer/contract")
local Holders = require("modules/transfer/mex_splitting/holders")
local RegionsApi = require("modules/regions/api")
local TransferEnums = require("modules/transfer/enums")

---@param problems string[]
---@return MexRegionsDeal
local function noDeal(problems)
	return { regions = {}, spots = {}, problems = problems }
end

Policies.On(Contract.MexSplitting)
	.Refusal(function(ctx)
		local problems = RegionsApi.ProblemLines(RegionsApi.Enums.Types.MexRegion, ctx.regions, { spots = ctx.spots })
		if #problems == 0 and #ctx.spots == 0 then
			problems[1] = "the map has no metal spots to deal"
		end
		return noDeal(problems)
	end)
	.If(Contract.MexSplitting.LayoutChecksOut, function(ctx)
		return #RegionsApi.ProblemLines(RegionsApi.Enums.Types.MexRegion, ctx.regions, { spots = ctx.spots }) == 0
	end)
	.If(Contract.MexSplitting.SpotsKnown, function(ctx)
		return #ctx.spots > 0
	end)
	.Answer(Contract.MexSplitting.NearestRoundRobin, function(ctx)
		local teams = Claims.Rank(ctx.teams, ctx.regions)
		local starts = Claims.Seat(teams)
		local held = {} ---@type table<string, integer>
		for _, start in ipairs(starts) do
			Claims.Round(start.teams, held, Claims.OwnedBy(start.ordinal))
		end
		Claims.Round(teams, held, Claims.Not(Claims.OfStart(starts)))
		local emptyHanded = Claims.EmptyHanded(ctx.teams, held)
		if #emptyHanded > 0 then
			local n = #emptyHanded
			return noDeal({
				n .. " team" .. (n == 1 and "" or "s") .. " would hold no mex region: the layout has too few",
			})
		end
		return { regions = held, spots = Claims.SpotHolders(ctx.regions, ctx.spots, held), problems = {} }
	end)

Policies.On(Contract.MexSplittingHeir).Answer(Contract.MexSplittingHeir.FewestGiftedThenNearest, function(ctx)
	local from = ctx.departing
	local best, bestGifted, bestDistance = nil, math.huge, math.huge
	for _, heir in ipairs(ctx.heirs) do
		local distance = RegionsApi.Geometry.Distance(from.x, from.z, heir.x, heir.z)
		if heir.gifted < bestGifted or (heir.gifted == bestGifted and distance < bestDistance) then
			best, bestGifted, bestDistance = heir.teamID, heir.gifted, distance
		end
	end
	return best
end)

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.SpotHolder, function(ctx, springRepo)
		if ctx.modOptions[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
			return nil
		end
		if ctx.spotX == nil or ctx.spotZ == nil then
			return nil
		end
		local engine = springRepo or Spring
		local holders = Holders.At(engine, ctx.spotX, ctx.spotZ)
		if #holders == 0 or table.contains(holders, ctx.builderTeam) then
			return nil
		end
		for _, teamID in ipairs(holders) do
			if engine.AreTeamsAllied and engine.AreTeamsAllied(ctx.builderTeam, teamID) then
				return teamID
			end
		end
		return holders[1]
	end)
