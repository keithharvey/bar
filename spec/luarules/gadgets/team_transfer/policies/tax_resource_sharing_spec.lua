---@type Builders
local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()

local function expectTransfer(service, resource, amount, expectedSent, expectedReceived)
    local result = service:TransferResource(sender.id, receiver.id, resource, amount)
    assert.equal(true, result.success)
    assert.equal(expectedSent, result.sent)
    assert.equal(expectedReceived, result.received)
end

describe(SharedEnums.Policies.TaxResourceSharing .. " policy", function()
    local taxRate = 0.3

    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithAlliance(sender.id, receiver.id, true)
        :WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)

    ---@type TeamTransferServiceBuilder
    local serviceBuilder = Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithPolicy(SharedEnums.Policies.TaxResourceSharing)

    describe("simple taxation", function()
        ---@type CombinedPolicyResult
        local result

        before_each(function()
            sender:WithEnergy(1000):WithMetal(1000)
            receiver:WithEnergy(100):WithMetal(100)
            local service = serviceBuilder:Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should ALLOW sharing of both METAL and ENERGY", function()
            assert.equal(result.metal_transfer.canShare, true)
            assert.equal(result.energy_transfer.canShare, true)
        end)

        it("should cap ENERGY sendable by min(receiver capacity, sender budget + allowance)", function()
            local expectedResult = receiver.energy.storage - receiver.energy.current
            assert.equal(expectedResult, result.energy_transfer.amountSendable)
            assert.equal(expectedResult, result.energy_transfer.amountReceivable)
        end)

        it("should cap METAL sendable by min(receiver capacity, sender budget + allowance) #focus", function()
            local expectedResult = receiver.metal.storage - receiver.metal.current
            assert.equal(expectedResult, result.metal_transfer.amountReceivable)
        end)

        it("should also expose max amount sendable, allowing the metal send slider to have the correct max value #focus", function()
            local expectedResult = receiver.metal.storage - receiver.metal.current
            assert.equal(expectedResult, result.metal_transfer.amountSendable)
        end)

        it("should expose the tax rate", function()
            assert.equal(taxRate, result.metal_transfer.taxRate)
            assert.equal(taxRate, result.energy_transfer.taxRate)
        end)

        it("should not have a remaining tax free allowance", function()
            assert.equal(result.metal_transfer.remainingTaxFreeAllowance, 0)
        end)
    end)

    describe("when receiver is full", function()
        ---@type CombinedPolicyResult
        local result
        
        before_each(function()
            receiver:WithEnergy(1000):WithMetal(1000)
            local service = serviceBuilder:Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should NOT allow sharing when receiver is full", function()
            assert.equal(result.metal_transfer.canShare, false)
            assert.equal(result.energy_transfer.canShare, false)
        end)

        it("should set amount sendable to 0", function()
            assert.equal(0, result.metal_transfer.amountSendable)
            assert.equal(0, result.energy_transfer.amountSendable)
        end)
    end)

    
    describe("when a receiver has more metal capacity than the threshold", function()
        it("should have an untaxed portion that is the threshold", function()
            sender:WithMetal(1000)
            receiver:WithMetal(980)
            local result = serviceBuilder:Build():GetResult(sender.id, receiver.id)
            assert.equal(result.metal_transfer.amountSendable, 20)
        end)
    end)

    describe("when a sender has less metal than the receiver has capacity", function()
        ---@type CombinedPolicyResult
        local result
        local metalThreshold = 1000
        
        before_each(function()
            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
            spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, metalThreshold)

            sender:WithMetal(1000)
            receiver:WithMetalStorage(5000)

            result = serviceBuilder:Build():GetResult(sender.id, receiver.id)
        end)

        it("should be entirely tax free", function()
            assert.equal(1000, result.metal_transfer.untaxedPortion)
        end)
    end)

    describe("rate = 0.7, receiver capacity 300, sender 1000", function()
        ---@type CombinedPolicyResult
        local result
        local taxRate = 0.7

         before_each(function()
            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
            sender:WithEnergy(1000)
            receiver:WithEnergyStorage(1000):WithEnergy(700)

            result = serviceBuilder:Build():GetResult(sender.id, receiver.id)
        end)

        it("should have amountReceivable set to receiver capacity and amountSendable == 300", function()
            assert.equal(300, result.energy_transfer.amountReceivable)
            assert.equal(300, result.energy_transfer.amountSendable)
        end)
    end)

    describe("sender 1000, rate = 0.7, receiver capacity 300, threshold 0, cumulative sent 0", function()
        ---@type CombinedPolicyResult
        local result
        local taxRate = 0.7

         before_each(function()
            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
            sender:WithEnergy(1000)
            receiver:WithEnergyStorage(1000):WithEnergy(700)

            result = serviceBuilder:Build():GetResult(sender.id, receiver.id)
        end)

        it("should enable sharing", function()
            assert.is_true(result.energy_transfer.canShare)
            assert.is_true(result.energy_transfer.canShare)
        end)

        it("should have a receivable amount set to the receiver's capacity and amountSendable == 300", function()
            assert.equal(300, result.energy_transfer.amountReceivable)
            assert.equal(300, result.energy_transfer.amountSendable)
        end)
    end)
    
    describe("Taxation Behavior", function()
        describe("when taxation is enabled (30%)", function()
            ---@type TeamTransferService
            local service
            
            before_each(function()
                spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
                spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, 0)
                spring:WithModOption(ModOptions.Options.PlayerEnergySendThreshold, 0)

                -- Reset receiver resources to ensure test isolation
                receiver:WithEnergyStorage(1000):WithEnergy(100)
                receiver:WithMetalStorage(1000):WithMetal(100)

                service = Builders.TeamTransferService.new()
                    :WithSpringRepository(spring)
                    :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                    :Build()
            end)
    
            it("should tax metal transfers", function()
                expectTransfer(service, SharedEnums.ResourceType.METAL, 100, 100 / (1 - taxRate), 100)
                expectTransfer(service, SharedEnums.ResourceType.METAL, 500, 500 / (1 - taxRate), 500)
            end)
    
            it("should tax energy transfers", function()
                expectTransfer(service, SharedEnums.ResourceType.ENERGY, 100, 100 / (1 - taxRate), 100)
                expectTransfer(service, SharedEnums.ResourceType.ENERGY, 500, 500 / (1 - taxRate), 500)
            end)
        end)
    
        describe("when taxation is disabled", function()
            local service
            
            before_each(function()
                spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, 0)
                spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, 0)
                spring:WithModOption(ModOptions.Options.PlayerEnergySendThreshold, 0)
                
                service = Builders.TeamTransferService.new()
                    :WithSpringRepository(spring)
                    :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                    :Build()
            end)
    
            it("should not tax metal transfers", function()
                expectTransfer(service, SharedEnums.ResourceType.METAL, 100, 100, 100)
                expectTransfer(service, SharedEnums.ResourceType.METAL, 500, 500, 500)
            end)
    
            it("should not tax energy transfers", function()
                expectTransfer(service, SharedEnums.ResourceType.ENERGY, 100, 100, 100)
                expectTransfer(service, SharedEnums.ResourceType.ENERGY, 500, 500, 500)
            end)
        end)
    end)
    
    describe("Threshold Behavior", function()
        local resourceTypes = {
            { name = "METAL", type = SharedEnums.ResourceType.METAL, thresholdOption = ModOptions.Options.PlayerMetalSendThreshold },
            { name = "ENERGY", type = SharedEnums.ResourceType.ENERGY, thresholdOption = ModOptions.Options.PlayerEnergySendThreshold }
        }
        
        local thresholdScenarios = {
            { threshold = 0, name = "zero threshold" },
            { threshold = 200, name = "moderate threshold" },
            { threshold = 10000, name = "very high threshold" }
        }
        
        local transferAmounts = { 50, 150, 200, 250, 400 }
    
        for _, resourceInfo in ipairs(resourceTypes) do
            describe("for " .. resourceInfo.name, function()
                for _, scenario in ipairs(thresholdScenarios) do
                    describe("with " .. scenario.name .. " (" .. scenario.threshold .. ")", function()
                        local service
                        
                        before_each(function()
                            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
                            spring:WithModOption(resourceInfo.thresholdOption, scenario.threshold)
                            
                            service = Builders.TeamTransferService.new()
                                :WithSpringRepository(spring)
                                :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                                :Build()
                        end)
    
                        for _, amount in ipairs(transferAmounts) do
                            it("should handle " .. amount .. " " .. resourceInfo.name .. " transfer correctly", function()
                                local expectedSent, expectedReceived
                                
                                if amount <= scenario.threshold then
                                    -- Under threshold: no tax
                                    expectedSent = amount
                                    expectedReceived = amount
                                else
                                    -- Over threshold: tax only the excess
                                    local excessAmount = amount - scenario.threshold
                                    expectedSent = scenario.threshold + (excessAmount / (1 - taxRate))
                                    expectedReceived = amount
                                end
                                
                                expectTransfer(service, resourceInfo.type, amount, expectedSent, expectedReceived)
                            end)
                        end
                    end)
                end
            end)
        end
    end)
    
    describe("Edge Cases and Boundary Conditions", function()
        local service
        
        before_each(function()
            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
            spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, 200)
            spring:WithModOption(ModOptions.Options.PlayerEnergySendThreshold, 300)
            
            service = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                :Build()
        end)
    
        it("should handle exact threshold amounts", function()
            expectTransfer(service, SharedEnums.ResourceType.METAL, 200, 200, 200)
            expectTransfer(service, SharedEnums.ResourceType.ENERGY, 300, 300, 300)
        end)
    
        it("should handle minimal amounts", function()
            expectTransfer(service, SharedEnums.ResourceType.METAL, 1, 1, 1)
            expectTransfer(service, SharedEnums.ResourceType.ENERGY, 1, 1, 1)
        end)
    
        it("should handle threshold + 1 scenarios", function()
            expectTransfer(service, SharedEnums.ResourceType.METAL, 201, 200 + (1 / (1 - taxRate)), 201)
            expectTransfer(service, SharedEnums.ResourceType.ENERGY, 301, 300 + (1 / (1 - taxRate)), 301)
        end)
    end)
end)


