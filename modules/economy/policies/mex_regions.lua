local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local RegionEnums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local EconomyEnums = VFS.Include("modules/economy/enums.lua")
local Claims = VFS.Include("modules/economy/lib/mex_regions/claims.lua") ---@type MexRegionsClaimsLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared

---@param problems string[]
---@return MexRegionsDeal
local function noDeal(problems)
	return { regions = {}, spots = {}, problems = problems }
end

Policies.On(RegionsContract.CheckSet).Apply(Contract.MexRegionsSet.MexesCovered, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.MexRegion or ctx.env.spots == nil then
		return
	end
	local uncovered = {} ---@type string[]
	for _, spot in ipairs(ctx.env.spots) do
		local covered = false
		for _, region in ipairs(ctx.regions) do
			covered = covered or (region.vertices ~= nil and Geometry.Contains(spot.x, spot.z, region.vertices))
		end
		if not covered then
			uncovered[#uncovered + 1] = string.format("%d, %d", spot.x, spot.z)
		end
	end
	if #uncovered > 0 then
		local shown = {}
		for i = 1, math.min(#uncovered, 4) do
			shown[i] = uncovered[i]
		end
		ctx.problems[#ctx.problems + 1] = #uncovered
			.. " metal spot"
			.. (#uncovered == 1 and "" or "s")
			.. " in no mex region: "
			.. table.concat(shown, "; ")
			.. (#uncovered > #shown and "; ..." or "")
	end
end)

Policies.On(Contract.MexRegions)
	.Refusal(function(ctx)
		local problems = Claims.Problems(ctx.regions, ctx.spots)
		if #problems == 0 and #ctx.spots == 0 then
			problems[1] = "the map has no metal spots to deal"
		end
		return noDeal(problems)
	end)
	.If(Contract.MexRegions.LayoutChecksOut, function(ctx)
		return #Claims.Problems(ctx.regions, ctx.spots) == 0
	end)
	.If(Contract.MexRegions.SpotsKnown, function(ctx)
		return #ctx.spots > 0
	end)
	.Answer(Contract.MexRegions.NearestRoundRobin, function(ctx)
		local views = Claims.Rank(ctx.teams, ctx.regions)
		local held = {} ---@type table<string, integer>

		---@param seated MexRegionsTeamView[] the teams taking turns
		---@param takes fun(region: MexRegion): boolean which regions are on the table
		local function goRound(seated, takes)
			---@param view MexRegionsTeamView
			---@return MexRegion|nil
			local function nearestFree(view)
				for _, ranked in ipairs(view.regions) do
					if held[ranked.region.id] == nil and takes(ranked.region) then
						return ranked.region
					end
				end
				return nil
			end

			---@return boolean
			local function round()
				local took = false
				for _, view in ipairs(seated) do
					local pick = nearestFree(view)
					if pick then
						held[pick.id] = view.team.teamID
						took = true
					end
				end
				return took
			end

			for _ = 1, #ctx.regions do
				if not round() then
					return
				end
			end
		end

		local seated = {} ---@type table<integer, MexRegionsTeamView[]>
		local ordinals = {} ---@type integer[]
		for _, view in ipairs(views) do
			local ordinal = view.team.allyTeam
			if seated[ordinal] == nil then
				seated[ordinal] = {}
				ordinals[#ordinals + 1] = ordinal
			end
			table.insert(seated[ordinal], view)
		end
		table.sort(ordinals)
		for _, ordinal in ipairs(ordinals) do
			goRound(seated[ordinal], function(region)
				return region.team == ordinal
			end)
		end
		goRound(views, function(region)
			return seated[region.team] == nil
		end)

		local byRegion = Claims.SpotsIn(ctx.regions, ctx.spots)
		local spots = {} ---@type table<string, integer>
		for id, teamID in pairs(held) do
			for _, key in ipairs(byRegion[id] or {}) do
				spots[key] = teamID
			end
		end
		return { regions = held, spots = spots, problems = {} }
	end)

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.SpotHolder, function(ctx, springRepo)
		if ctx.modOptions[EconomyEnums.ModOptions.MexSplitting] ~= EconomyEnums.MexSplitting.MapAssigned then
			return nil
		end
		if ctx.spotX == nil or ctx.spotZ == nil then
			return nil
		end
		local engine = springRepo or Spring
		local byKey = Shared.HolderBySpot(engine, engine.GetTeamList())
		return byKey[Shared.SpotKey(ctx.spotX, ctx.spotZ)]
	end)
