local EconomyContract = require("modules/economy/contract")
local Income = require("modules/transfer/mex_splitting/income")
local TransferEnums = require("modules/transfer/enums")

-- Shared: what every team's mexes made this tick is the ally team's to split evenly.
Policies.On(EconomyContract.Extraction).Provide(EconomyContract.Extraction.Income, function(ctx)
	if ctx.springRepo.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.Shared then
		return nil
	end
	return Income.Shared(ctx.teams, ctx.income)
end)
