local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local EconomyEnums = VFS.Include("modules/economy/enums.lua")
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared

Policies.On(Contract.MexRegions)
	.Refusal(function()
		return {}
	end)
	.Answer(Contract.MexRegions.NearestRoundRobin, function(ctx)
		local held = {} ---@type MexRegionsClaims

		---@param teams MexRegionsTeamView[]
		---@param takes fun(ranked: MexRegionsRanked): boolean
		local function goRound(teams, takes)
			---@param team MexRegionsTeamView
			---@return MexRegionsRanked|nil
			local function nearestFree(team)
				for _, ranked in ipairs(team.regions) do
					if held[ranked.id] == nil and takes(ranked) then
						return ranked
					end
				end
				return nil
			end

			---@return boolean
			local function round()
				local took = false
				for _, team in ipairs(teams) do
					local pick = nearestFree(team)
					if pick then
						held[pick.id] = team.teamID
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
		for _, team in ipairs(ctx.teams) do
			if seated[team.allyTeam] == nil then
				seated[team.allyTeam] = {}
				ordinals[#ordinals + 1] = team.allyTeam
			end
			table.insert(seated[team.allyTeam], team)
		end
		table.sort(ordinals)
		for _, ordinal in ipairs(ordinals) do
			goRound(seated[ordinal], function(ranked)
				return ranked.team == ordinal
			end)
		end
		goRound(ctx.teams, function(ranked)
			return ranked.team == nil or seated[ranked.team] == nil
		end)
		return held
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
