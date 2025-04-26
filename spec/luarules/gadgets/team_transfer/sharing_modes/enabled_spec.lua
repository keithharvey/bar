local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

-- Test the "Enabled" preset configuration from sharing_modes
-- Configuration: All sharing enabled with no restrictions, no tax, all allied actions enabled

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
    :WithRealUnitDefs()

-- Helper function to create service with Enabled configuration
local function createEnabledService()
    return Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithSharingMode(SharedEnums.SharingModes.Enabled)
        :Build()
end

describe("Enabled Sharing Configuration", function()
    ---@type TeamTransferService
    local service

    before_each(function()
        -- Reset teams to normal state
        sender.metal.current = 1000
        sender.energy.current = 1000
        receiver.metal.current = 100
        receiver.energy.current = 100

        service = createEnabledService()
    end)

    describe("Resource Sharing", function()
        it("should allow unrestricted resource transfers with no tax", function()
            local transferAmount = 500
            
            local metalResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, transferAmount)
            local energyResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.ENERGY, transferAmount)

            -- No tax should be applied
            assert.equal(transferAmount, metalResult.sent)
            assert.equal(transferAmount, metalResult.received)
            assert.equal(transferAmount, energyResult.sent)
            assert.equal(transferAmount, energyResult.received)
        end)

        it("should maximize sendable amounts", function()
            local result = service:GetResult(sender.id, receiver.id)

            assert.equal(true, result.metal_transfer.canShare)
            assert.equal(true, result.energy_transfer.canShare)
            assert.is_true(result.metal_transfer.amountSendable > 0)
            assert.is_true(result.energy_transfer.amountSendable > 0)
        end)
    end)

    describe("Unit Sharing", function()
        it("should enable full unrestricted unit sharing", function()
            local result = service:GetResult(sender.id, receiver.id)
            
            assert.is_not_nil(result.unit_transfer)
            assert.equal(true, result.unit_transfer.canShareUnits)
        end)
    end)

    describe("Allied Actions", function()
        it("should provide allied action results", function()
            local result = service:GetResult(sender.id, receiver.id)
            
            -- Check that the enabled configuration provides results
            -- The exact behavior depends on which policies are active
            assert.is_not_nil(result)
        end)
    end)

    describe("compared to other sharing modes", function()
        it("should provide comprehensive sharing results", function()
            -- Create restrictive service for comparison
            local restrictiveService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.NoSharing)
                :Build()

            local enabledResult = service:GetResult(sender.id, receiver.id)
            local restrictiveResult = restrictiveService:GetResult(sender.id, receiver.id)

            -- Both should provide valid results
            assert.is_not_nil(enabledResult)
            assert.is_not_nil(restrictiveResult)
            assert.is_not_nil(enabledResult.metal_transfer)
            assert.is_not_nil(restrictiveResult.metal_transfer)
        end)

        it("should be more permissive than limited sharing", function()
            -- Create limited sharing service for comparison
            local limitedService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.LimitedSharing)
                :Build()

            local transferAmount = 600
            local enabledResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, transferAmount)
            local limitedResult = limitedService:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, transferAmount)

            -- Enabled should cost less to send the same amount
            assert.is_true(enabledResult.sent <= limitedResult.sent)
            assert.equal(transferAmount, enabledResult.received)
            assert.equal(transferAmount, limitedResult.received)
        end)
    end)
end)
