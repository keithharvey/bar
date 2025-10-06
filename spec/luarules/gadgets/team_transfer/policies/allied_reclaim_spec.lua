local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

describe(SharedEnums.Policies.AlliedReclaim .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    describe("WHEN allied reclaim is disabled at policy level", function()
        local result

        before_each(function()
            local spring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AlliedReclaim, "disabled")

            -- Policy is always enabled, but command validation blocks allied reclaims
            local service = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AlliedReclaim)
                :Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should DENY reclaim commands at policy level", function()
            assert.is_false(result.reclaim_transfer.allowReclaimCommands)
        end)
    end)

    describe("WHEN allied reclaim is disabled", function()
        local service

        before_each(function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false }
            }

            local springWithRestrictions = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AlliedReclaim, "disabled")
                :Build()

            service = Builders.TeamTransferService.new()
                :WithSpringRepository(springWithRestrictions)
                :WithPolicy(SharedEnums.Policies.AlliedReclaim)
                :Build()
        end)

        it("should allow reclaiming own units", function()
            -- Mock UnitDefs first so WithUnit can copy properties
            _G.UnitDefs = {
                ["armpw"] = { buildOptions = {}, canAssist = false }
            }

            -- Create a unit that will do the reclaiming
            local reclaimerUnitId
            sender:WithUnit("armpw", function(unitId) reclaimerUnitId = unitId end)

            -- Create own unit to reclaim
            local ownUnitId
            sender:WithUnit("armpw", function(unitId) ownUnitId = unitId end)

            -- Update the service's spring repo with the units
            service.springRepo._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }

            local allowed = service:ValidateCommand(reclaimerUnitId, 1, sender.id, service.springRepo.CMD.RECLAIM, {ownUnitId}, {}, 0, sender.id)
            assert.is_true(allowed)
        end)
    end)

    describe("WHEN allied reclaim is enabled", function()
        local service

        before_each(function()
            local spring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AlliedReclaim, "enabled")

            -- Explicitly enable the policy for testing
            service = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AlliedReclaim)
                :Build()
        end)

        it("should ALLOW reclaim commands", function()
            local result = service:GetResult(sender.id, receiver.id)
            assert.is_true(result.reclaim_transfer.allowReclaimCommands)
        end)
    end)
end)
