local Builders = require("spec/builders/index")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")

describe(SharedEnums.Policies.AssistAlly .. " policy", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()

    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithAlliance(sender.id, receiver.id, true) -- Allied teams

    describe("WHEN assist ally is disabled", function()
        spring:WithModOption(SharedEnums.Policies.AssistAlly, "disabled")

        ---@type CombinedPolicyResult
        local result

        before_each(function()
            -- Explicitly enable the policy for testing
            local serviceBuilder = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AssistAlly)
            local service = serviceBuilder:Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should DENY guard commands", function()
            assert.is_false(result.guard_transfer.allowGuardCommands)
        end)

        it("should DENY repair commands", function()
            assert.is_false(result.repair_transfer.allowRepairCommands)
        end)

        it("should provide default block reason", function()
            assert.equal("no_policy", result.guard_transfer.blockReason)
        end)
    end)

    describe("WHEN assist ally is enabled", function()
        spring:WithModOption(SharedEnums.Policies.AssistAlly, "enabled")

        ---@type CombinedPolicyResult
        local result

        before_each(function()
            -- Explicitly enable the policy for testing
            local serviceBuilder = Builders.TeamTransferService.new()
                :WithSpringRepository(spring)
                :WithPolicy(SharedEnums.Policies.AssistAlly)
            local service = serviceBuilder:Build()
            result = service:GetResult(sender.id, receiver.id)
        end)

        it("should ALLOW guard commands", function()
            assert.is_true(result.guard_transfer.allowGuardCommands)
        end)

        it("should ALLOW repair commands", function()
            assert.is_true(result.repair_transfer.allowRepairCommands)
        end)
    end)
end)
