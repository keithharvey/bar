local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

-- Test the "Customize" preset configuration from sharing_modes
-- Configuration: No preset options, everything customizable

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

-- Helper function to create service with Customize configuration
local function createCustomizeService()
    return Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithSharingMode(SharedEnums.SharingModes.Customize)
        :Build()
end

describe("Customize Sharing Configuration", function()
    ---@type TeamTransferService
    local service

    before_each(function()
        -- Reset teams to normal state
        sender.metal.current = 1000
        sender.energy.current = 1000
        receiver.metal.current = 100
        receiver.energy.current = 100

        service = createCustomizeService()
    end)

    describe("Default Behavior", function()
        it("should use system defaults when no customizations are set", function()
            local result = service:GetResult(sender.id, receiver.id)

            -- Customize mode should rely on default mod options and policies
            assert.is_not_nil(result)
            assert.is_not_nil(result.metal_transfer)
            assert.is_not_nil(result.energy_transfer)
        end)

        it("should allow configuration flexibility", function()
            -- Create a custom service with specific mod options
            local customSpring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(ModOptions.Options.UnitSharingMode, "t2cons")
                :WithModOption(ModOptions.Options.TaxResourceSharingAmount, 0.15)
                :WithRealUnitDefs()

            local customService = Builders.TeamTransferService.new()
                :WithSpringRepository(customSpring)
                :WithSharingMode(SharedEnums.SharingModes.Customize)
                :WithPolicy(SharedEnums.Policies.UnitSharingMode)
                :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                :Build()

            local result = customService:GetResult(sender.id, receiver.id)

            assert.is_not_nil(result.unit_transfer)
            assert.is_not_nil(result.metal_transfer)
        end)
    end)

    describe("compared to preset modes", function()
        it("should be neutral compared to preset sharing modes", function()
            -- Create preset services for comparison
            local noSharingService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.NoSharing)
                :Build()

            local enabledService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.Enabled)
                :Build()

            local customizeResult = service:GetResult(sender.id, receiver.id)
            local noSharingResult = noSharingService:GetResult(sender.id, receiver.id)
            local enabledResult = enabledService:GetResult(sender.id, receiver.id)

            -- Customize should fall somewhere between these extremes or have its own behavior
            assert.is_not_nil(customizeResult)
            assert.is_not_nil(noSharingResult)
            assert.is_not_nil(enabledResult)
        end)
    end)

    describe("Policy Configuration", function()
        it("should work with minimal policies by default", function()
            local result = service:GetResult(sender.id, receiver.id)

            -- Should work even with empty policy configuration
            assert.is_not_nil(result)
        end)

        it("should accept custom policy additions", function()
            -- Add specific policies to the customize service
            local enhancedService = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithSharingMode(SharedEnums.SharingModes.Customize)
                :WithPolicy(SharedEnums.Policies.UnitSharingMode)
                :WithPolicy(SharedEnums.Policies.TaxResourceSharing)
                :Build()

            local result = enhancedService:GetResult(sender.id, receiver.id)

            assert.is_not_nil(result)
            assert.is_not_nil(result.unit_transfer)
            assert.is_not_nil(result.metal_transfer)
        end)
    end)
end)
