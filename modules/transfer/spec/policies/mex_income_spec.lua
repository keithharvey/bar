local EconomyContract = require("modules/economy/contract")
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

---@param mode string
local function spring(mode)
	return {
		GetModOptions = function()
			return { [TransferEnums.ModOptions.MexSplitting] = mode }
		end,
	}
end

local teams = {
	[0] = { allyTeam = 0, isDead = false },
	[1] = { allyTeam = 0, isDead = false },
}
local made = { [0] = { metal = 6, energy = 0 }, [1] = { metal = 2, energy = 0 } }

describe("what extraction pays, under shared mex splitting", function()
	local resolved = ModuleHandler.LoadEnrichers(EconomyContract.Extraction)

	it("is the ally team's mex metal, split evenly", function()
		local ctx = { springRepo = spring(TransferEnums.MexSplitting.Shared), teams = teams, seconds = 2, made = made }
		local income = ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[EconomyContract.Extraction.Income]
		assert.are.same({ [0] = { metal = 4, energy = 0 }, [1] = { metal = 4, energy = 0 } }, income)
	end)

	it("is what the engine paid under any other mex splitting", function()
		local ctx =
			{ springRepo = spring(TransferEnums.MexSplitting.MapAssigned), teams = teams, seconds = 2, made = made }
		assert.is_true(
			rawequal(
				made,
				ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[EconomyContract.Extraction.Income]
			)
		)
	end)
end)
