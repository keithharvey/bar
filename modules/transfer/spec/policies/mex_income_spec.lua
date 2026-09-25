local EconomyContract = require("modules/economy/contract")
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

---@param mode string
---@param rates table<integer, number> metal per second by team
local function spring(mode, rates)
	return {
		GetModOptions = function()
			return { [TransferEnums.ModOptions.MexSplitting] = mode }
		end,
		GetTeamUnitsByDefs = function(teamID)
			return rates[teamID] and { teamID } or {}
		end,
		GetUnitResources = function(unitID)
			return rates[unitID], 0, 0, 0
		end,
	}
end

local teams = {
	[0] = { allyTeam = 0, isDead = false },
	[1] = { allyTeam = 0, isDead = false },
	[2] = { allyTeam = 1, isDead = false },
	[3] = { allyTeam = 0, isDead = true },
}

describe("shared mex income, on economy's tick", function()
	local resolved = ModuleHandler.LoadEnrichers(EconomyContract.Pooling)
	setup(function()
		_G.UnitDefs = _G.UnitDefs or { [7] = { extractsMetal = 1, customParams = {} } }
	end)

	it(
		"pools each ally team's extraction over the tick and hands it round evenly; the dead and other ally teams apart",
		function()
			local ctx = {
				springRepo = spring(TransferEnums.MexSplitting.Shared, { [0] = 3, [1] = 1, [2] = 9, [3] = 5 }),
				teams = teams,
				seconds = 2,
			}
			local transfers =
				ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[EconomyContract.Pooling.Transfers]
			assert.are.same({ { from = 0, to = 1, resourceType = "metal", amount = 2 } }, transfers)
		end
	)

	it("is not transfer's to say under any other mex splitting", function()
		local ctx = {
			springRepo = spring(TransferEnums.MexSplitting.MapAssigned, { [0] = 3, [1] = 1 }),
			teams = teams,
			seconds = 2,
		}
		assert.are.same(
			{},
			ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[EconomyContract.Pooling.Transfers]
		)
	end)
end)
