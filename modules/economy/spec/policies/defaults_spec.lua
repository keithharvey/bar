local Contract = require("modules/economy/contract")
local ModuleHandler = require("modules/module_handler")

describe("economy's own answers, when no module provides", function()
	it("taxes nothing", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Distribution)
		local facts = ModuleHandler.EnrichWith(resolved, {}, { teamId = 1 })
		assert.are.equal(0, facts[Contract.Distribution.TaxRate])
	end)

	it("pools nothing", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Pooling)
		assert.are.same(
			{},
			ModuleHandler.EnrichWith(resolved, {}, { teams = {}, seconds = 1 })[Contract.Pooling.Transfers]
		)
	end)

	it("redistributes the results as they are", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Redistribution)
		local results = { { teamId = 1, resourceType = "metal", sent = 3, received = 0 } }
		local facts = ModuleHandler.EnrichWith(resolved, {}, { results = results })
		assert.is_true(rawequal(results, facts[Contract.Redistribution.Results]))
	end)
end)
