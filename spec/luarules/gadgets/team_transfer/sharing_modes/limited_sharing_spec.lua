local Builders = require("spec/builders/index")
local SharedEnums = require("luarules.gadgets.team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")
local PolicyLogger = require("modules/policy_engine_logger")

local sender = Builders.Team:new():Human()
    :WithMetal(1000)
    :WithEnergy(1000)
local receiver = Builders.Team:new():Human()
    :WithMetal(100)
    :WithEnergy(100)
local enemy = Builders.Team:new():AI()
    :WithMetal(100)
    :WithEnergy(100)
local spring = Builders.SpringRepository.new()
    :WithTeam(sender)
    :WithTeam(receiver)
    :WithTeam(enemy)
    :WithAlliance(sender.id, receiver.id, true)
    :WithRealUnitDefs()

local function createLimitedSharingService()
    -- policies enabled based on mod options set by WithSharingMode
    return Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithSharingMode(SharedEnums.SharingModes.LimitedSharing)
        :Build()
end

describe("Limited Sharing Configuration", function()
    ---@type TeamTransferService
    local service
    ---@type PolicyEngineLogger
    local logger

    before_each(function()
        service = createLimitedSharingService()

        local result, realPlan = service:GetResult(sender.id, receiver.id)
        
        -- logger = PolicyLogger.new()
        -- logger:LogPlan(result, realPlan)
    end)

    describe("Resource Sharing", function()
        it("should apply tax-free threshold and tax excess for metal", function()
            local modOptions = service.springRepo:GetModOptions()
            local thresholdAmount = modOptions[ModOptions.Options.PlayerMetalSendThreshold]
            local taxRate = modOptions[ModOptions.Options.TaxResourceSharingAmount]

            -- Transfer at threshold should be tax-free
            local thresholdResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, thresholdAmount)
            assert.equal(thresholdAmount, thresholdResult.sent)
            assert.equal(thresholdAmount, thresholdResult.received)

            -- Transfer over threshold should be taxed
            local excessAmount = 100
            local transferAmount = thresholdAmount + excessAmount
            local expectedSent = thresholdAmount + (excessAmount / (1 - taxRate))
            local taxedResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, transferAmount)
            assert.equal(expectedSent, taxedResult.sent)
            assert.equal(transferAmount, taxedResult.received)
        end)

        it("should tax all energy transfers (no threshold)", function()
            local modOptions = service.springRepo:GetModOptions()
            local transferAmount = 200
            local taxRate = modOptions[ModOptions.Options.TaxResourceSharingAmount]
            local expectedSent = transferAmount / (1 - taxRate)

            local result = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.ENERGY, transferAmount)
            assert.equal(expectedSent, result.sent)
            assert.equal(transferAmount, result.received)
        end)

        it("should provide tax-free allowance up to threshold", function()
            -- Transfer exactly at threshold should be tax-free
            local thresholdResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, 440)
            assert.equal(440, thresholdResult.sent)
            assert.equal(440, thresholdResult.received)

            -- Any amount over threshold should incur tax
            local overThresholdResult = service:TransferResource(sender.id, receiver.id, SharedEnums.ResourceType.METAL, 441)
            assert.is_true(overThresholdResult.sent > 441)
            assert.equal(441, overThresholdResult.received)
        end)

        it("should prevent sending to enemies", function()
            local result = service:TransferResource(sender.id, enemy.id, SharedEnums.ResourceType.METAL, 1000)
            assert.is_false(result.success)
        end)
    end)

    describe("Unit Sharing", function()
        it("should restrict unit sharing to T2 constructors only", function()
            local result = service:GetResult(sender.id, receiver.id)
            assert.is_not_nil(result.unit_transfer)
            assert.equal("t2cons", result.unit_transfer.sharingMode)
        end)
    end)

    describe("Command Validation", function()
        it("should allow allied assist commands", function()
            local result = service:GetResult(sender.id, receiver.id)
            -- LimitedSharing should allow allied assist
            assert.is_not_nil(result.guard_transfer)
            assert.is_true(result.guard_transfer.allowGuardCommands)
            assert.is_not_nil(result.repair_transfer)
            assert.is_true(result.repair_transfer.allowRepairCommands)
        end)

        it("should allow allied reclaim commands", function()
            local result = service:GetResult(sender.id, receiver.id)
            -- LimitedSharing should allow allied reclaim
            assert.is_not_nil(result.reclaim_transfer)
            assert.is_true(result.reclaim_transfer.allowReclaimCommands)
        end)

        it("should allow enemy reclaim commands", function()
            local result = service:GetResult(sender.id, enemy.id)
            assert.is_true(result.reclaim_transfer.allowReclaimCommands)
        end)

        it("should deny enemy guard commands", function()
            local result = service:GetResult(sender.id, enemy.id)
            assert.is_false(result.guard_transfer.allowGuardCommands)
        end)

        it("should deny enemy repair commands", function()
            local result = service:GetResult(sender.id, enemy.id)
            assert.is_false(result.repair_transfer.allowRepairCommands)
        end)
    end)

    describe("Policy Configuration", function()
        it("should have all required policies enabled", function()
            local result = service:GetResult(sender.id, receiver.id)

            -- Verify the service was created successfully with all policies
            assert.is_not_nil(result)
            assert.is_not_nil(result.metal_transfer)
            assert.is_not_nil(result.energy_transfer)
            assert.is_not_nil(result.unit_transfer)
        end)
    end)

    describe("when receiver is full", function()
        local fullReceiverService, fullSender, fullReceiver

        before_each(function()
            -- Create teams with receiver having more resources than sender
            fullSender = Builders.Team:new():Human()
                :WithMetal(500)
                :WithEnergy(500)
            fullReceiver = Builders.Team:new():Human()
                :WithMetal(1000)
                :WithEnergy(1000)

            local fullSpring = Builders.SpringRepository.new()
                :WithTeam(fullSender)
                :WithTeam(fullReceiver)
                :WithAlliance(fullSender.id, fullReceiver.id, true)
                :WithRealUnitDefs()

            fullReceiverService = Builders.TeamTransferService.new()
                :WithSpringRepository(fullSpring)
                :WithSharingMode(SharedEnums.SharingModes.LimitedSharing)
                :Build()
        end)

        it("should deny sharing when receiver has no storage capacity", function()
            local result = fullReceiverService:GetResult(fullSender.id, fullReceiver.id)

            assert.equal(false, result.metal_transfer.canShare)
            assert.equal(false, result.energy_transfer.canShare)
        end)

        it("should set sendable amounts to 0 when receiver has no capacity", function()
            local result = fullReceiverService:GetResult(fullSender.id, fullReceiver.id)

            assert.equal(0, result.metal_transfer.amountSendable)
            assert.equal(0, result.energy_transfer.amountSendable)
        end)
    end)
end)
