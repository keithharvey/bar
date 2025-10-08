local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local BuildingCategoryDefinitions = require("luaui/Include/blueprint_substitution/definitions")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES

describe(SharedEnums.Policies.BuildingUnlocksSharing .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithAlliance(sender.id, receiver.id, true)

    describe("WHEN building unlocks sharing is enabled", function()
        spring:WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, SharedEnums.BuildingUnlocksSharingMode.Enabled)

        describe("WHEN no buildings exist", function()
            local result

            before_each(function()
                local service = Builders.TeamTransferService.new()
                    :WithSpringRepository(spring)
                    :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)
                    :Build()
                result = service:GetResult(sender.id, receiver.id)
            end)

            it("should DENY resource sharing", function()
                assert.is_false(result.metal_transfer.canShare)
                assert.is_false(result.energy_transfer.canShare)
            end)

            it("should DENY unit sharing", function()
                assert.is_false(result.unit_transfer.canShareUnits)
            end)
        end)

        describe("WHEN storage buildings exist", function()
            local result

            before_each(function()
                local senderWithStorage = Builders.Team:new():Human()
                    :WithUnitFromCategory(BuildingCategories.METAL_STORAGE)
                    :WithUnitFromCategory(BuildingCategories.ENERGY_STORAGE)

                local springWithStorage = Builders.SpringRepository.new()
                    :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, SharedEnums.BuildingUnlocksSharingMode.Enabled)
                    :WithTeam(senderWithStorage)
                    :WithTeam(receiver)
                    :WithAlliance(senderWithStorage.id, receiver.id, true)

                local service = Builders.TeamTransferService.new()
                    :WithSpringRepository(springWithStorage)
                    :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)
                    :Build()
                result = service:GetResult(senderWithStorage.id, receiver.id)
            end)

            it("should ALLOW resource sharing", function()
                assert.is_true(result.metal_transfer.canShare)
                assert.is_true(result.energy_transfer.canShare)
            end)
        end)

        describe("WHEN pinpointer exists", function()
            local result

            before_each(function()
                local senderWithPinpointer = Builders.Team:new():Human()
                    :WithUnitFromCategory(BuildingCategories.PINPOINTER)

                local springWithPinpointer = Builders.SpringRepository.new()
                    :WithModOption(SharedEnums.Policies.BuildingUnlocksSharing, SharedEnums.BuildingUnlocksSharingMode.Enabled)
                    :WithTeam(senderWithPinpointer)
                    :WithTeam(receiver)
                    :WithAlliance(senderWithPinpointer.id, receiver.id, true)

                local service = Builders.TeamTransferService.new()
                    :WithSpringRepository(springWithPinpointer)
                    :WithPolicy(SharedEnums.Policies.BuildingUnlocksSharing)
                    :Build()
                result = service:GetResult(senderWithPinpointer.id, receiver.id)
            end)

            it("should ALLOW unit sharing", function()
                assert.is_true(result.unit_transfer.canShareUnits)
            end)
        end)
    end)
end)
