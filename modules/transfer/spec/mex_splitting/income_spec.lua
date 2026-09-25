local Income = require("modules/transfer/mex_splitting/income")

describe("an even split of what an ally team's extractors made", function()
	it("hands what is above the share to who is below it, nearest deficit first, and nothing at the share", function()
		local transfers = Income.Even({
			{ teamID = 0, made = 90 },
			{ teamID = 1, made = 30 },
			{ teamID = 2, made = 0 },
		})
		assert.are.same({
			{ from = 0, to = 1, resourceType = "metal", amount = 10 },
			{ from = 0, to = 2, resourceType = "metal", amount = 40 },
		}, transfers)
	end)

	it("moves nothing for one team, for no income, or when everyone made the share", function()
		assert.are.same({}, Income.Even({ { teamID = 0, made = 50 } }))
		assert.are.same({}, Income.Even({ { teamID = 0, made = 0 }, { teamID = 1, made = 0 } }))
		assert.are.same({}, Income.Even({ { teamID = 0, made = 20 }, { teamID = 1, made = 20 } }))
	end)

	it("sums a team's extractors' metal rate, and only theirs", function()
		local spring = {
			GetTeamUnitsByDefs = function(teamID)
				return teamID == 1 and { 10, 11 } or {}
			end,
			GetUnitResources = function(unitID)
				return unitID == 10 and 2.5 or 1.5, 0, 0, 0
			end,
		}
		assert.are.equal(4, Income.Extraction(spring, 1, { 7 }))
		assert.are.equal(0, Income.Extraction(spring, 2, { 7 }))
	end)
end)
