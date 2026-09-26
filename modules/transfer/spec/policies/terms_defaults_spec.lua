local Contract = require("modules/transfer/contract")
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

---@param opts table
local function repo(opts)
	return {
		GetModOptions = function()
			return opts
		end,
	}
end

describe("transfer's own terms, when no module provides", function()
	it("the team's tax is the modoption, clamped to 0..1", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamTerms)
		local function tax(raw)
			return ModuleHandler.EnrichWith(
				resolved,
				{},
				{ opts = { [TransferEnums.ModOptions.TaxResourceSharingAmount] = raw } }
			)[Contract.TeamTerms.TaxRate]
		end
		assert.are.equal(0.3, tax("0.3"))
		assert.are.equal(0, tax(-1))
		assert.are.equal(1, tax(7))
		assert.are.equal(0, tax(nil))
	end)

	it("a pairing blocks nothing, shares by the modoption's mode and taxes by its rate", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamPairing)
		local spring = repo({
			[TransferEnums.ModOptions.UnitSharingMode] = "resource",
			[TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.2,
		})
		local facts = ModuleHandler.EnrichWith(resolved, {}, {}, spring, 1)
		assert.is_nil(facts[Contract.TeamPairing.TechBlocking])
		assert.are.same({ "resource" }, facts[Contract.TeamPairing.UnitSharingModes])
		assert.are.equal(0.2, facts[Contract.TeamPairing.TaxRate])
		assert.are.same(
			{ "none" },
			ModuleHandler.EnrichWith(resolved, {}, {}, repo({}), 1)[Contract.TeamPairing.UnitSharingModes]
		)
	end)

	it("the notes promise no unlock and know no tech", function()
		local unit = ModuleHandler.EnrichWith(ModuleHandler.LoadEnrichers(Contract.UnitTermsNotes), {}, {})
		assert.is_false(unit[Contract.UnitTermsNotes.FutureUnlock])
		assert.is_nil(unit[Contract.UnitTermsNotes.TechData])
		local resource = ModuleHandler.EnrichWith(ModuleHandler.LoadEnrichers(Contract.ResourceTermsNotes), {}, {})
		assert.is_nil(resource[Contract.ResourceTermsNotes.TaxUnlock])
	end)
end)
