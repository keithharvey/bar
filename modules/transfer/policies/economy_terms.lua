local EconomyContract = require("modules/economy/contract")
local distribution = EconomyContract.Distribution
local redistribution = EconomyContract.Redistribution
local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local SharedConfig = require("modules/transfer/economy/shared_config")

Policies.On(distribution).Provide(distribution.TaxRate, function(ctx)
	return SharedConfig.getTeamTaxRate(ctx.springRepo, ctx.teamId)
end)

Policies.On(redistribution).Provide(redistribution.Results, function(ctx)
	return ManualShareLedger.FoldInto(ctx.results)
end)
