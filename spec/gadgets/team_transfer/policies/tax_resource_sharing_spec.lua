local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

local PipelineLogger = require("luarules/gadgets/team_transfer/pipeline_logger")

describe(SharedEnums.Policies.TaxResourceSharing .. " policy #tax", function()
    local taxRate = 0.3
    local spring = Builders.SpringRepository.new()
    spring:WithModOption(SharedEnums.Policies.TaxResourceSharing, taxRate)

    local sender = Builders.Team.Human()
    local receiver = Builders.Team.Human()

    local teamRepository = Builders.TeamRepository.new()
        :WithAlliedPlayers(sender, receiver)

    local pipelineBuilder = Builders.Pipeline.new()
        :WithSpringRepository(spring)
        :WithTeamRepository(teamRepository)
        :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
    describe("simple taxation", function()
        local pipeline, result

        before_each(function()
            receiver:WithEnergy(500):WithMetal(500)

            pipeline = pipelineBuilder:Build()

            result = pipeline:QueryExpose(sender.id, receiver.id)
        end)

        it("should ALLOW sharing of both METAL and ENERGY", function()
            assert.equal(result.MetalTransfer.canShare, true)
            assert.equal(result.EnergyTransfer.canShare, true)
        end)

        it("should limit the amount of ENERGY sendable by the tax rate", function()
            local expectedResult = (sender.energyAmount - receiver.energyAmount) * (1 + taxRate)
            assert.equal(result.EnergyTransfer.amountSendable, expectedResult)
        end)

        it("should limit the amount of METAL sendable by the tax rate", function()
            local maxSendable = (sender.metalAmount - receiver.metalAmount)
            local expectedResult = maxSendable * (1 + taxRate)
            assert.equal(result.MetalTransfer.amountSendable, expectedResult)
        end)

        it("should expose the tax rate", function()
            assert.equal(result.MetalTransfer.taxRate, taxRate)
            assert.equal(result.EnergyTransfer.taxRate, taxRate)
        end)

        it("should not have a remaining tax free allowance", function()
            assert.equal(result.MetalTransfer.remainingTaxFreeAllowance, 0)
        end)
    end)

    describe("when receiver is full", function()
        local pipeline, result
        before_each(function()
            -- Use late binding: modify the reusable builder
            receiver:WithEnergy(1000):WithMetal(1000)

            pipeline = pipelineBuilder:Build()

            result, plan = pipeline:QueryExpose(sender.id, receiver.id)
        end)

        it("should NOT allow sharing when receiver is full", function()
            assert.equal(result.MetalTransfer.canShare, false)
            assert.equal(result.EnergyTransfer.canShare, false)
        end)

        it("should set amount sendable to 0 #focus", function()
            assert.equal(0, result.EnergyTransfer.amountSendable)
            assert.equal(0, result.MetalTransfer.amountSendable)
        end)
    end)
end)
