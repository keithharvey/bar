local Contract = require("modules/defs/contract")
local ModuleHandler = require("modules/module_handler")
local PolicyBuilder = require("modules/policy_builder")

describe("defs pipelines", function()
	it("are folds over one def, with the base game's post as a named stage", function()
		for category, stages in pairs({ unit_def = Contract.UnitDef, weapon_def = Contract.WeaponDef }) do
			local pipeline = ModuleHandler.Pipeline(stages)
			assert.are.equal("fold", pipeline.result, category)
			local named = {}
			for _, stage in ipairs(pipeline) do
				named[stage.name] = true
			end
			assert.is_true(named.Base, category)
		end
		assert.are.same(
			{ owner = "defs", category = "unit_def", result = "fold" },
			PolicyBuilder.IdentityOf(Contract.UnitDef)
		)
	end)

end)
