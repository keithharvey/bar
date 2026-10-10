local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

-- Four characters. transfer owns UnitTransfer and shapes its refusal once. tech contributes one guard and never sees
-- that shape. The loader places the guard before transfer's answer. Eval hands back transfer's refusal when it trips.
describe("a unit given to a team still at tier one, under tech blocking", function()
	local function terms(receiverLevel, techBlocking)
		local levels = { [1] = 2, [2] = receiverLevel }
		return ModuleHandler.Evaluate(ModuleHandler.Contract(Modules.Transfer).UnitTransfer, {
			senderTeamId = 1,
			receiverTeamId = 2,
			areAlliedTeams = true,
			isCheatingEnabled = false,
			modOptions = { unit_sharing_mode = "all", unit_share_stun_seconds = 7, tech_blocking = techBlocking },
			springRepo = {
				GetTeamRulesParam = function(teamId, key)
					if key == "tech_level" then
						return levels[teamId]
					end
					return nil
				end,
			},
		})
	end

	it("is refused on transfer's terms, which tech never wrote: the stun the tooltip shows is still there", function()
		local refused = terms(1, true)
		assert.is_false(refused.canShare)
		assert.are.equal(7, refused.stunSeconds)
		assert.are.same({ "all" }, refused.sharingModes)
		assert.are.equal(2, refused.receiverTeamId)
	end)

	it("goes through at tier two, and whenever tech blocking is off", function()
		assert.is_true(terms(2, true).canShare)
		assert.is_true(terms(1, false).canShare)
	end)

	it("sits among transfer's guards, before its answer, where the loader put it", function()
		local names = {}
		for i, step in ipairs(ModuleHandler.Steps(ModuleHandler.Contract(Modules.Transfer).UnitTransfer)) do
			names[i] = step.name
		end
		assert.are.same(
			{ "SharingDisabled", "Allied", "ReceiverHasNoPlayers", "ReceiverAtTierOne", "TransferTerms" },
			names
		)
	end)
end)
