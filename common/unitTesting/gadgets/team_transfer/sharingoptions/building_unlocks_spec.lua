local Builders = require("common/unitTesting/builders/index")
local Sides = require("gamedata/sides_enum")
local Units = require("gamedata/unit_names")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")
local BUILDING_CATEGORIES = BuildingCategoryDefinitions.BUILDING_CATEGORIES
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")


describe("sharingoptions: building_unlocks preset", function()
	--@type PipelineBuilder
	local pipelineBuilder

	before_each(function()
		local me = Builders.Team.Human().PoorButNotBroke().Build()
		local ally = Builders.Team.Human().Rich().Build()
		
		-- Set up Spring environment
		local spring = Builders.Spring
			.WithPlayer(me)
			.WithPlayer(ally)
			.WithAlliance(me, ally)

			pipelineBuilder = Builders.Pipeline
			.WithSpringBuilder(spring)
			.WithSharingMode(SharedEnums.SharingOptions.BuildingUnlocks)
	end)

	describe("when no storage buildings exist", function() 
		local pipeline
		before_each(function()
			pipeline = pipelineBuilder.Build()
		end)
		it("should restrict commands", function()
		end)
	end)

	-- it("starts with restricted command sharing when no storage buildings exist", function()
	-- 	-- No storage buildings - should restrict commands
	-- 	_G.Spring.GetTeamUnits = function(teamID) return {} end

	-- 	local result = pipeline.QueryExposeByPredicates("allied", "command_validation", 0, 1)
	-- 	assert.is_not_nil(result)
	-- 	-- In building_unlocks mode without storage, commands should be restricted
	-- end)

	-- it("enables command sharing when storage buildings are present", function()
	-- 	-- Build individual storage buildings using enums directly
	-- 	local metalStorage = Builders.Unit.From(Units.ARM_METAL_STORAGE)
	-- 	local energyStorage = Builders.Unit.From(Units.ARM_ENERGY_STORAGE)
		
	-- 	-- Add to UnitDefs for the test
	-- 	_G.UnitDefs[1001] = metalStorage
	-- 	_G.UnitDefs[1002] = energyStorage

	-- 	-- Combine all unit definitions
	-- 	local allUnits = {}
	-- 	for id, unit in pairs(metalStorage) do allUnits[id] = unit end
	-- 	for id, unit in pairs(energyStorage) do allUnits[id + 1000] = unit end
	-- 	for id, unit in pairs(pinpointer) do allUnits[id + 2000] = unit end

	-- 	_G.UnitDefs = allUnits

	-- 	-- Mock Spring to return these units for team
	-- 	_G.Spring.GetTeamUnits = function(teamID)
	-- 		if teamID == 0 then
	-- 			local unitIDs = {}
	-- 			for unitID, _ in pairs(units) do
	-- 				table.insert(unitIDs, unitID)
	-- 			end
	-- 			return unitIDs
	-- 		end
	-- 		return {}
	-- 	end

	-- 	_G.Spring.GetUnitDefID = function(unitID) return unitID end

	-- 	local result = pipeline.QueryExposeByPredicates("allied", "command_validation", 0, 1)
	-- 	assert.is_not_nil(result)
	-- 	assert.is_true(result.allowGuardCommands)
	-- 	assert.is_true(result.allowRepairCommands)
	-- end)

	-- it("enables unit sharing by default in building_unlocks mode", function()
	-- 	local result = pipeline.QueryExposeByPredicates("allied", "unit_transfer", 0, 1)
	-- 	assert.is_not_nil(result)
	-- 	assert.is_true(result.canShareUnits, "Should allow unit sharing in building_unlocks mode")
	-- end)
end)


