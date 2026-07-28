local Contract = require("modules/economy/contract")

Policies.On(Contract.Distribution).Default(Contract.Distribution.TaxRate, function()
	return 0
end)

Policies.On(Contract.Redistribution).Default(Contract.Redistribution.Results, function(ctx)
	return ctx.results
end)
