local policy = require("luarules/gadgets/team_transfer/policies/building_unlocks_sharing")

local Builders = require("common/unitTesting/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local Sides = require("gamedata/sides_enum")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES

describe(SharedEnums.Policies.BuildingUnlocksSharing .. " policy #bu", function()
    local me = Builders.Team.Human().PoorButNotBroke()
    local ally = Builders.Team.Human().Rich()

    local meData = me.Build()
    local allyData = ally.Build()

	local spring = Builders.SpringRepository.new()
        :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, true)
        :WithAlliance(meData.id, allyData.id)

    local teamRepository = Builders.TeamRepository.new()
        :WithAlliedPlayers(meData, allyData)

    local pipelineBuilder = Builders.Pipeline.new()
        :WithSpringRepository(spring)
        :WithTeamRepository(teamRepository)
        :WithPolicy(policy)
    

	describe("WHEN no buildings exist", function()
        local pipeline = pipelineBuilder:Build()
        ---@type CombinedExposeOutput
        local result = pipeline.QueryExpose(
            meData.id,
            allyData.id
        )

		it("should DENY commands", function()
            assert.is_false(result.CommandValidation.allowGuardCommands)
            assert.is_false(result.CommandValidation.allowRepairCommands)
            assert.is_false(result.CommandValidation.allowReclaimCommands)
		end)
        it("should DENY resource sharing #focus", function()
            assert.is_false(result.MetalTransfer.canShare)
            assert.is_false(result.EnergyTransfer.canShare)
        end)
        it("should DENY unit sharing", function()
            assert.is_false(result.UnitTransfer.canShareUnits)
        end)
	end)
    
    describe("WHEN a " .. BuildingCategories.METAL_STORAGE .. " and " .. BuildingCategories.ENERGY_STORAGE .. " exist", function()
        ---@type UnitRepositoryBuilder
        local unitRepository = Builders.UnitRepository.new()
        unitRepository:WithUnitFromCategory(
            BuildingCategories.METAL_STORAGE,
            Sides.ARM
        )
        unitRepository:WithUnitFromCategory(
            BuildingCategories.ENERGY_STORAGE,
            Sides.ARM
        )
        local pipeline = pipelineBuilder:WithUnitRepository(unitRepository):Build()
        ---@type CombinedExposeOutput
        local result = pipeline.QueryExpose(
            meData.id,
            allyData.id
        )

		it("should ALLOW commands", function()
            assert.is_true(result.CommandValidation.allowGuardCommands)
            assert.is_true(result.CommandValidation.allowRepairCommands)
            assert.is_true(result.CommandValidation.allowReclaimCommands)
		end)
        it("should ALLOW resource sharing", function()
            assert.is_true(result.MetalTransfer.canShare)
            assert.is_true(result.EnergyTransfer.canShare)
        end)
        it("should DENY unit sharing", function()
            assert.is_false(result.UnitTransfer.canShareUnits)
        end)
    end)


    describe("WHEN a " .. BuildingCategories.PINPOINTER .. " exists", function()
        ---@type UnitRepositoryBuilder
        local unitRepository = Builders.UnitRepository.new()
        unitRepository:WithUnitFromCategory(
            BuildingCategories.PINPOINTER,
            Sides.ARM
        )
        local pipeline = pipelineBuilder:WithUnitRepository(unitRepository):Build()
        ---@type CombinedExposeOutput
        local result = pipeline.QueryExpose(
            meData.id,
            allyData.id
        )

		it("should DENY commands", function()
            assert.is_false(result.CommandValidation.allowGuardCommands)
            assert.is_false(result.CommandValidation.allowRepairCommands)
            assert.is_false(result.CommandValidation.allowReclaimCommands)
		end)
        it("should DENY resource sharing", function()
            assert.is_false(result.MetalTransfer.canShare)
            assert.is_false(result.EnergyTransfer.canShare)
        end)
        it("should ALLOW unit sharing", function()
            assert.is_true(result.UnitTransfer.canShareUnits)
        end)
    end)
end)
