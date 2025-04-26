local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")

local PolicyLogger = require("modules/policy_engine_logger")

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

-- Helper function to create service with Building Unlocks configuration
local function createBuildingUnlocksService()
    return Builders.TeamTransferService.new()
        :WithSpringRepository(spring)
        :WithSharingMode(SharedEnums.SharingModes.BuildingUnlocks)
        :Build()
end

describe("Building Unlocks Configuration", function()
    ---@type TeamTransferService
    local service

    before_each(function()
        -- Reset teams to normal state
        sender.metal.current = 1000
        sender.energy.current = 1000
        receiver.metal.current = 100
        receiver.energy.current = 100

        service = createBuildingUnlocksService()
    end)

    describe("Configuration Setup", function()
        it("should enable building unlocks sharing policy", function()
            -- The sharing mode should set the mod option that enables the building unlocks policy
            local modOptions = service.springRepo:GetModOptions()
            local buildingUnlocksMode = modOptions[ModOptions.Options.BuildingUnlocksSharing]
            assert.equal(SharedEnums.BuildingUnlocksSharingMode.Enabled, buildingUnlocksMode,
                "Building unlocks sharing should be enabled in mod options")
        end)

        it("should set building unlocks mode to enabled", function()
            -- Check that the mod option is set correctly
            local modOptions = service.springRepo:GetModOptions()
            assert.equal(SharedEnums.BuildingUnlocksSharingMode.Enabled, modOptions[SharedEnums.Policies.BuildingUnlocksSharing])
        end)
    end)

    it("should disable unit sharing with no buildings", function()
        local result, realPlan = service:GetResult(sender.id, receiver.id)

        assert.is_not_nil(result.unit_transfer)
        assert.is_false(result.unit_transfer.canShareUnits)
    end)

    describe("Building Requirements", function()
        it("should enable resource sharing when storage buildings are present", function()
            -- Create service with teams that have storage buildings
            local senderTeam = Builders.Team:new():Human():WithUnit("armmstor"):WithUnit("armestor")
            local receiverTeam = Builders.Team:new():Human():WithUnit("armtarg")

            local serviceWithBuildings = Builders.TeamTransferService.new()
                :WithSpringRepository(Builders.SpringRepository.new()
                    :WithTeam(senderTeam)
                    :WithTeam(receiverTeam)
                    :WithAlliance(senderTeam.id, receiverTeam.id, true)
                    :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, SharedEnums.BuildingUnlocksSharingMode.Enabled)
                    :WithRealUnitDefs()
                )
                :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)
                :Build()

            local result = serviceWithBuildings:GetResult(senderTeam.id, receiverTeam.id)

            -- Should allow resource sharing when both storage buildings are present
            assert.equal(true, result.metal_transfer.canShare)
            assert.equal(true, result.energy_transfer.canShare)
            assert.equal(false, result.unit_transfer.canShareUnits)
        end)

        it("should deny resource sharing when storage buildings are missing", function()
            -- Create service with teams that lack storage buildings
            local senderTeam = Builders.Team:new():Human()
            local receiverTeam = Builders.Team:new():Human()

            local serviceWithoutBuildings = Builders.TeamTransferService.new()
                :WithSpringRepository(Builders.SpringRepository.new()
                    :WithTeam(senderTeam) -- No buildings
                    :WithTeam(receiverTeam) -- No buildings
                    :WithAlliance(senderTeam.id, receiverTeam.id, true)
                    :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, SharedEnums.BuildingUnlocksSharingMode.Enabled)
                    :WithRealUnitDefs()
                )
                :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)
                :Build()

            local result = serviceWithoutBuildings:GetResult(senderTeam.id, receiverTeam.id)

            -- Should deny resource sharing when storage buildings are missing
            assert.equal(false, result.metal_transfer.canShare)
            assert.equal(false, result.energy_transfer.canShare)
            assert.equal(false, result.unit_transfer.canShareUnits) -- Unit sharing is always enabled in building unlocks
        end)
    end)
end)
