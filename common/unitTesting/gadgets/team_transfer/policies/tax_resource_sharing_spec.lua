local Builders = require("common/unitTesting/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

local PipelineLogger = require("luarules/gadgets/team_transfer/pipeline_logger")

describe(SharedEnums.Policies.TaxResourceSharing .. " policy #clear", function()
    local taxRate = 0.3
    local spring = Builders.SpringRepository.new()
    spring:WithModOption(SharedEnums.Policies.TaxResourceSharing, taxRate)

    local me = Builders.Team.Human()
    local ally = Builders.Team.Human()

    local teamRepository = Builders.TeamRepository.new()
        :WithAlliedPlayers(me, ally)

    local pipelineBuilder = Builders.Pipeline.new()
        :WithSpringRepository(spring)
        :WithTeamRepository(teamRepository)
        :WithPolicy(SharedEnums.Policies.TaxResourceSharing)

    describe("simple taxation", function()
        local pipeline, result

        before_each(function()
            -- Reset ally builder to original state for this test
            ally:WithEnergy(500):WithMetal(500)

            pipeline = pipelineBuilder:Build()

            result = pipeline:QueryExpose(me.id, ally.id)
        end)

        it("should ALLOW sharing of both METAL and ENERGY", function()
            assert.equal(result.MetalTransfer.canShare, true)
            assert.equal(result.EnergyTransfer.canShare, true)
        end)

        it("should limit the amount of ENERGY sendable by the tax rate", function()
            local expectedResult = (me.energyAmount - ally.energyAmount) * (1 + taxRate)
            assert.equal(result.EnergyTransfer.amountSendable, expectedResult)
        end)

        it("should limit the amount of METAL sendable by the tax rate", function()
            local maxSendable = (me.metalAmount - ally.metalAmount)
            local expectedResult = maxSendable * (1 + taxRate)
            assert.equal(result.MetalTransfer.amountSendable, expectedResult)
        end)

        it("should expose the tax rate", function()
            -- Strongly-typed usage with EmmyLua type assertions
            local et = pipeline:GetExpose(me.id, ally.id, SharedEnums.TransferCategory.EnergyTransfer)
            ---@cast et TaxResourceSharingEnergyResult
            local mt = pipeline:GetExpose(me.id, ally.id, SharedEnums.TransferCategory.MetalTransfer)
            ---@cast mt TaxResourceSharingMetalResult

            assert.equal(et.taxRate, taxRate)
            assert.equal(mt.taxRate, taxRate)
        end)
    end)

    describe("when receiver is full", function()
        local pipeline, result
        before_each(function()
            -- Use late binding: modify the reusable builder
            ally:WithEnergy(1000):WithMetal(1000)

            pipeline = pipelineBuilder:Build()

            result = pipeline:QueryExpose(me.id, ally.id)
        end)

        it("should NOT allow sharing when receiver is full", function()
            assert.equal(result.MetalTransfer.canShare, false)
            assert.equal(result.EnergyTransfer.canShare, false)
        end)

        it("should set amount sendable to 0", function()
            assert.equal(result.EnergyTransfer.amountSendable, 0)
            assert.equal(result.MetalTransfer.amountSendable, 0)
        end)
    end)
end)