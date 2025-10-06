local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

describe(SharedEnums.Policies.AlliedReclaim .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    describe("WHEN allied reclaim is disabled", function()
        local result

        before_each(function()
            local spring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :WithAlliance(sender.id, receiver.id, true)
                :WithModOption(SharedEnums.Policies.AlliedReclaim, "disabled")

            -- Explicitly enable the policy for testing
            local service = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AlliedReclaim)
                :Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should DENY allied reclaim commands", function()
            assert.is_false(result.reclaim_transfer.allowReclaimCommands)
        end)

        it("should provide default block reason", function()
            assert.equal("no_policy", result.reclaim_transfer.blockReason)
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
