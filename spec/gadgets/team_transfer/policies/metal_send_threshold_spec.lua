local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

local PipelineLogger = require("luarules/gadgets/team_transfer/pipeline_logger")

describe(SharedEnums.Policies.MetalSendThreshold .. " policy #metal_threshold", function()
    local spring = Builders.SpringRepository.new()
    
    local taxRate = 0.3
    spring:WithModOption(SharedEnums.Policies.TaxResourceSharing, taxRate)
    
    local metalThreshold = 100
    spring:WithModOption(SharedEnums.Policies.MetalSendThreshold, metalThreshold)

    local sender = Builders.Team.Human()
    local receiver = Builders.Team.Human()

    local teamRepository = Builders.TeamRepository.new()
        :WithAlliedPlayers(sender, receiver)

    local pipelineBuilder = Builders.Pipeline.new()
        :WithSpringRepository(spring)
        :WithTeamRepository(teamRepository)
        :WithPolicy(SharedEnums.Policies.MetalSendThreshold)
        :WithPolicy(SharedEnums.Policies.TaxResourceSharing)

    describe("WITHOUT metal sent yet", function()
        local result, plan
        before_each(function()
            -- Set sender to have 1000 metal and receiver to have 500 capacity remaining
            sender:WithMetal(1000)
            receiver:WithMetal(500):WithMetalStorage(1000)  -- 500 capacity remaining

            pipeline = pipelineBuilder:Build()

            result = pipeline:QueryExpose(sender.id, receiver.id)
        end)
        
        it("should allow metal transfer", function()
            assert.equal(result.MetalTransfer.canShare, true)
        end)
        
        it("should limit to receiver capacity", function()
            local expectedResult = math.min(receiver.metalStorage - receiver.metalAmount, sender.metalAmount - metalThreshold)
            assert.equal(result.MetalTransfer.amountSendable, expectedResult)
        end)

        it("should expose the tax rate", function()
            assert.equal(result.MetalTransfer.taxRate, taxRate)
            assert.equal(result.EnergyTransfer.taxRate, taxRate)
        end)

        it("should expose the allowanceRemaining", function()
            assert.equal(result.MetalTransfer.remainingTaxFreeAllowance, 100)
        end)
    end)
end)
