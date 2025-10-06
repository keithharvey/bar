---@type Builders
local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

local taxRate = 0.3
local sender = Builders.Team:new():Human()
    :WithMetal(1000)
    :WithEnergy(1000)
local receiver = Builders.Team:new():Human()
    :WithMetal(100)
    :WithEnergy(100)
local spring = Builders.SpringRepository.new()
    :WithTeam(sender)
    :WithTeam(receiver)
    :WithAlliance(sender.id, receiver.id, true)

describe("Policy behavior", function()
    ---@type TeamTransferService
    local service
    local metalThreshold = 400
    
    before_each(function()
        spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
        spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, metalThreshold)
        spring:WithModOption(ModOptions.Options.PlayerEnergySendThreshold, 0)
        
        service = Builders.TeamTransferService.new()
            :WithSpringRepository(spring)
            :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
            :Build()
    end)

    it("should have an untaxed portion that is the threshold #focus", function()
        local result = service:GetResult(sender.id, receiver.id)

        assert.equal(result.metal_transfer.untaxedPortion, 400)
    end)
    
    it("should have an taxed portion that accounts for taxation overhead", function()
        local result = service:GetResult(sender.id, receiver.id)
        local receiverCapacity = receiver.metal.storage - receiver.metal.current
        local untaxedPortion = metalThreshold
        assert.equal(result.metal_transfer.amountSendable, (receiverCapacity - untaxedPortion) * (1 + taxRate))
    end)
end)

-- Helper function to test a resource transfer
local function expectTransfer(service, resource, amount, expectedSent, expectedReceived)
    local result = service:TransferResource(sender.id, receiver.id, resource, amount)
    assert.equal(true, result.success)
    assert.equal(expectedSent, result.sent)
    assert.equal(expectedReceived, result.received)
end

describe("Taxation Behavior", function()
    describe("when taxation is enabled (30%)", function()
        ---@type TeamTransferService
        local service
        
        before_each(function()
            spring:WithModOption(ModOptions.Options.TaxResourceSharingAmount, taxRate)
            spring:WithModOption(ModOptions.Options.PlayerMetalSendThreshold, 0)
            spring:WithModOption(ModOptions.Options.PlayerEnergySendThreshold, 0)
            
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


describe("when receiver is full", function()
    local result
    before_each(function()
        sender.metal.current = 1000
        sender.energy.current = 1000
        receiver.metal.current = 1000
        receiver.energy.current = 1000

        local service = Builders.TeamTransferService.new()
            :WithSpringRepository(spring)
            :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
            :Build()

        result = service:GetResult(sender.id, receiver.id)
    end)

    it("should NOT allow sharing when receiver is full", function()
        assert.equal(result.metal_transfer.canShare, false)
        assert.equal(result.energy_transfer.canShare, false)
    end)

    it("should set amount sendable to 0", function()
        assert.equal(0, result.energy_transfer.amountSendable)
        assert.equal(0, result.metal_transfer.amountSendable)
    end)
end)
