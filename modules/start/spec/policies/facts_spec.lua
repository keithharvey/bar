local Boxes = require("modules/start/lib/boxes")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

local Facts = ModuleHandler.Contract(Modules.Start).Facts ---@type StartFacts

---@param positions { teamID: integer, allyTeamID: integer, x: number, z: number }[]
local function stubSpring(positions)
	return {
		GetGaiaTeamID = function()
			return 99
		end,
		GetTeamList = function()
			local ids = { 99 }
			for _, p in ipairs(positions) do
				ids[#ids + 1] = p.teamID
			end
			return ids
		end,
		GetTeamStartPosition = function(teamID)
			for _, p in ipairs(positions) do
				if p.teamID == teamID then
					return p.x, 0, p.z
				end
			end
			return 0, 0, 0
		end,
		GetTeamAllyTeamID = function(teamID)
			for _, p in ipairs(positions) do
				if p.teamID == teamID then
					return p.allyTeamID
				end
			end
			return nil
		end,
		GetAllyTeamList = function()
			return {}
		end,
	}
end

describe("start's facts, when no module provides", function()
	it("the areas are the boxes, whole-map ones left out, in box order", function()
		local spring = stubSpring({})
		local boxes = Boxes.Resolve(spring, {
			byAllyTeam = {
				[0] = { boxes = { { { 0, 0 }, { 100, 0, 0.5 }, { 100, 100 } } }, nameShort = "N" },
				[1] = { boxes = { { { 0, 0 }, { 1, 1 }, { 2, 2 }, { 3, 3 } } }, wholeMap = true },
				[2] = { boxes = { { { 500, 500 }, { 600, 500 }, { 600, 600 }, { 500, 600 } } } },
			},
			source = "modoption_set",
			explicit = true,
		})
		local facts = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Facts),
			{},
			{ springRepo = spring, boxes = boxes }
		)
		local areas = facts[Facts.Areas]
		assert.are.equal(2, #areas)
		local first, second = assert(areas[1]), assert(areas[2])
		assert.are.equal(0, first.allyTeamID)
		assert.are.equal("N", first.name)
		assert.are.equal(0.5, assert(first.anchors[2]).strength)
		assert.are.equal("modoption_set", first.source)
		assert.are.equal(2, second.allyTeamID)
	end)

	it("the positions are the engine's, gaia left out, a team at the origin not yet placed", function()
		local spring = stubSpring({
			{ teamID = 0, allyTeamID = 0, x = 50, z = 50 },
			{ teamID = 1, allyTeamID = 2, x = 550, z = 550 },
			{ teamID = 2, allyTeamID = 1, x = 0, z = 0 },
		})
		local facts = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Facts),
			{},
			{ springRepo = spring, boxes = {} }
		)
		assert.are.same({
			{ allyTeamID = 0, teamID = 0, x = 50, z = 50 },
			{ allyTeamID = 2, teamID = 1, x = 550, z = 550 },
		}, facts[Facts.Positions])
	end)
end)
