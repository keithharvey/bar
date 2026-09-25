local Construction = require("modules/construction/api")
local EconomyContract = require("modules/economy/contract")
local Income = require("modules/transfer/mex_splitting/income")
local TransferEnums = require("modules/transfer/enums")

-- Shared: what every team's extractors made this tick pools by ally team and splits back evenly.
Policies.On(EconomyContract.Pooling).Provide(EconomyContract.Pooling.Transfers, function(ctx)
	local spring = ctx.springRepo
	if spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.Shared then
		return nil
	end
	local mexes = Construction.Mexes()
	local byAlly = {} ---@type table<integer, MexIncomeSeat[]>
	for teamID, team in pairs(ctx.teams) do
		if not team.isDead then
			local seats = byAlly[team.allyTeam] or {}
			byAlly[team.allyTeam] = seats
			seats[#seats + 1] = { teamID = teamID, made = Income.Extraction(spring, teamID, mexes) * ctx.seconds }
		end
	end
	local transfers = {} ---@type EconomyTransfer[]
	for _, seats in pairs(byAlly) do
		table.sort(seats, function(a, b)
			return a.teamID < b.teamID
		end)
		for _, transfer in ipairs(Income.Even(seats)) do
			transfers[#transfers + 1] = transfer
		end
	end
	return transfers
end)
