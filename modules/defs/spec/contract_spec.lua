local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Contract = require("modules/defs/contract")
local PolicyBuilder = require("modules/policy_builder")

describe("defs pipelines", function()
	local pipelines = ModuleHandler.LoadPolicies(Modules.Defs) ---@type DefsPipelines

	it("are folds over one def, with the base game's post as a named stage", function()
		for _, category in ipairs({ "unit_def", "weapon_def" }) do
			local pipeline = pipelines[category]
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
