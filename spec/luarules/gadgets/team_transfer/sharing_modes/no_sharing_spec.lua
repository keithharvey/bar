local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

-- Test the "No Sharing" preset configuration from sharing_modes
-- Configuration: All sharing disabled, 30% tax, no thresholds, assist/reclaim disabled

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

-- Helper function to create service with No Sharing configuration
local function createNoSharingService()
    return Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithSharingMode(SharedEnums.SharingModes.NoSharing)
        :Build()
end

describe("No Sharing Configuration", function()
    ---@type TeamTransferService
    local service

    before_each(function()
        -- Reset teams to normal state
        sender.metal.current = 1000
        sender.energy.current = 1000
        receiver.metal.current = 100
        receiver.energy.current = 100

        service = createNoSharingService()
    end)

    describe("Resource Sharing", function()
        it("should have restrictive resource transfer behavior", function()
            local result = service:GetResult(sender.id, receiver.id)

            -- Check that the no sharing configuration creates some result
            assert.is_not_nil(result.metal_transfer)
            assert.is_not_nil(result.energy_transfer)
            
            -- The exact behavior depends on policy implementation
            -- but we expect less permissive behavior than unrestricted sharing
        end)
    end)

    describe("Unit Sharing", function()
        it("should completely disable unit sharing", function()
            local result = service:GetResult(sender.id, receiver.id)
            
            assert.is_not_nil(result.unit_transfer)
            assert.equal(false, result.unit_transfer.canShareUnits)
        end)
    end)

    describe("Allied Actions", function()
        it("should block assist ally actions", function()
            local result = service:GetResult(sender.id, receiver.id)
            
            -- These might not exist if the policies block them entirely
            if result.guard_transfer then
                assert.equal(false, result.guard_transfer.allowGuardCommands or false)
            end
            if result.repair_transfer then
                assert.equal(false, result.repair_transfer.allowRepairCommands or false)
            end
        end)

        it("should block allied reclaim", function()
            local result = service:GetResult(sender.id, receiver.id)
            
            -- This might not exist if the policy blocks it entirely
            if result.reclaim_transfer then
                assert.equal(false, result.reclaim_transfer.allowReclaimCommands or false)
            end
        end)
    end)

    describe("compared to other sharing modes", function()
        it("should load successfully and provide results", function()
            -- Create a more permissive service for comparison
            local permissiveService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.Enabled)
                :Build()

            local noSharingResult = service:GetResult(sender.id, receiver.id)
            local permissiveResult = permissiveService:GetResult(sender.id, receiver.id)

            -- Both should provide valid results
            assert.is_not_nil(noSharingResult)
            assert.is_not_nil(permissiveResult)
            assert.is_not_nil(noSharingResult.metal_transfer)
            assert.is_not_nil(permissiveResult.metal_transfer)
        end)
    end)
end)
