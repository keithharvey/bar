local Builders = require("common/unitTesting/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local BuildingCategoryDefinitions = require("luaui/Include/blueprint_substitution/definitions")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES

local PipelineLogger = require("luarules/gadgets/team_transfer/pipeline_logger")

describe(SharedEnums.Policies.BuildingUnlocksSharing .. " policy", function()
    local me = Builders.Team.Human():PoorButNotBroke():Build()
    local ally = Builders.Team.Rich():Build()

	local spring = Builders.SpringRepository.new()
        :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, true)

    local teamRepository = Builders.TeamRepository.new()
        :WithAlliedPlayers(me, ally)

    local pipelineBuilder = Builders.Pipeline.new()
        :WithSpringRepository(spring)
        :WithTeamRepository(teamRepository)
        :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)

	describe("WHEN no buildings exist", function()
        local result, plan
        before_each(function()
            local pipeline = pipelineBuilder:Build()
            ---@type CombinedExposeOutput
            result, plan = pipeline:QueryExpose(
                me.id,
                ally.id
            )
        end)

		it("should DENY commands", function()
            assert.is_false(result.CommandValidation.allowGuardCommands)
            assert.is_false(result.CommandValidation.allowRepairCommands)
            assert.is_false(result.CommandValidation.allowReclaimCommands)
		end)
        it("should DENY resource sharing", function()
            assert.is_false(result.MetalTransfer.canShare)
            assert.is_false(result.EnergyTransfer.canShare)
        end)
        it("should DENY unit sharing", function()
            assert.is_false(result.UnitTransfer.canShareUnits)
        end)
	end)
    
    describe("WHEN a " .. BuildingCategories.METAL_STORAGE .. " and " .. BuildingCategories.ENERGY_STORAGE .. " exist", function()
        local result, plan
        ---@type UnitRepositoryBuilder
        local unitRepository = Builders.UnitRepository.new()
        unitRepository:WithUnitFromCategory(BuildingCategories.METAL_STORAGE, me.id)
        unitRepository:WithUnitFromCategory(BuildingCategories.ENERGY_STORAGE, me.id)
        before_each(function()
            local pipeline = pipelineBuilder:WithUnitRepository(unitRepository):Build()
            ---@type CombinedExposeOutput
            result, plan = pipeline:QueryExpose(
                me.id,
                ally.id
            )
        end)

		it("should ALLOW comman", function()
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
            BuildingCategories.PINPOINTER
        )
        local pipeline = pipelineBuilder:WithUnitRepository(unitRepository):Build()
        ---@type CombinedExposeOutput
        local result, plan = pipeline:QueryExpose(
            me.id,
            ally.id
        )

		it("should DENY commands", function()
            -- PipelineLogger.LogPlan(plan, result)
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
