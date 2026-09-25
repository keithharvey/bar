local Contract = require("modules/economy/contract")
local ModuleHandler = require("modules/module_handler")

describe("economy's own answers, when no module provides", function()
	it("taxes nothing", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Distribution)
		local facts = ModuleHandler.EnrichWith(resolved, {}, { teamId = 1 })
		assert.are.equal(0, facts[Contract.Distribution.TaxRate])
	end)

	it("pays extraction as the engine did", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Extraction)
		local made = { [1] = { metal = 3, energy = 0 } }
		local ctx = { teams = {}, seconds = 1, made = made }
		assert.is_true(rawequal(made, ModuleHandler.EnrichWith(resolved, {}, ctx)[Contract.Extraction.Income]))
	end)

	it("redistributes the results as they are", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.Redistribution)
		local results = { { teamId = 1, resourceType = "metal", sent = 3, received = 0 } }
		local facts = ModuleHandler.EnrichWith(resolved, {}, { results = results })
		assert.is_true(rawequal(results, facts[Contract.Redistribution.Results]))
	end)
end)
