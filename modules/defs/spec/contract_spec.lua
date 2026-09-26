local Contract = require("modules/defs/contract")
local ModuleHandler = require("modules/module_handler")
local Policy = require("modules/policy")

describe("defs policies", function()
	it("are folds over one def, with the base game's post as a named step", function()
		for category, steps in pairs({ unit_def = Contract.UnitDef, weapon_def = Contract.WeaponDef }) do
			local policy = ModuleHandler.Steps(steps)
			assert.are.equal("fold", policy.result, category)
			local named = {}
			for _, step in ipairs(policy) do
				named[step.name] = true
			end
			assert.is_true(named.Base, category)
		end
		assert.are.same({ owner = "defs", category = "unit_def", result = "fold" }, Policy.IdentityOf(Contract.UnitDef))
	end)

end)
