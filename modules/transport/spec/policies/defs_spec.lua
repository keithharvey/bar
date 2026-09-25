local Contract = require("modules/transport/contract")
local DefsContract = require("modules/defs/contract")
local ModuleHandler = require("modules/module_handler")
local TransportEnums = require("modules/transport/enums")

describe("transport's stage on the unit def fold", function()
	local pipeline = ModuleHandler.Pipeline(DefsContract.UnitDef)

	local function enemyTransport(which, def)
		for _, stage in ipairs(pipeline) do
			if stage.name == Contract.UnitDef.EnemyTransport then
				stage.evaluate({
					name = "spec",
					def = def,
					modOptions = { [TransportEnums.ModOptions.TransportEnemy] = which },
				})
				return def
			end
		end
		error("no EnemyTransport stage")
	end

	it("follows the base game's post", function()
		local order = {}
		for i, stage in ipairs(pipeline) do
			order[stage.name] = i
		end
		assert.is_true(order.Base < order[Contract.UnitDef.EnemyTransport])
	end)

	it("makes commanders immune under All But Commanders, and everyone under Disallow All", function()
		local commander = { customparams = { iscommander = "1" } }
		local tank = { customparams = {} }
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, commander).transportbyenemy)
		assert.is_nil(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, tank).transportbyenemy)
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.None, tank).transportbyenemy)
	end)
end)
