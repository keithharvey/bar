local Builders = require("spec/builders/index")
local SharedEnums = require("luarules.gadgets.team_transfer.shared_enums")

describe(SharedEnums.Policies.SystemCleanup .. " policy", function()
    local spring, sender, receiver, service

    before_each(function()
        -- Set up teams (IDs are auto-assigned starting from 0)
        sender = Builders.Team:new():Human()
        receiver = Builders.Team:new():Human()

        -- Mock the Spring repository with spy
        spring = Builders.SpringRepository.new()
            :WithTeam(sender)
            :WithTeam(receiver)
            :WithAlliance(sender.id, receiver.id)
            :Build()
        spring.GiveOrderToUnit = spy.new(function() end)
        spring.TransferUnit = spy.new(function() return true end)
        spring.GetUnitTeam = spy.new(function(self, unitId) return sender.id end)
        spring.GetUnitDefs = spy.new(function() return { [1] = { name = "testunit" } } end)
        spring.GetUnitDefID = spy.new(function(self, unitId) return 1 end)

        -- Create service with the policy
        service = Builders.TeamTransferService.new()
            :WithSpringRepository(spring)
            :WithPolicy(SharedEnums.Policies.SystemCleanup)
            :WithPolicy(SharedEnums.Policies.UnitSharingMode)
            :Build()
    end)

    describe("post-unit-transfer cleanup", function()
        it("should issue LOAD_ONTO and SELFD commands for each transferred unit", function()
            -- Call the service's TransferUnits method which should trigger post-transfer cleanup
            local result = service:TransferUnits(sender.id, receiver.id, {123, 456, 789}, false)

            -- Verify the transfer was successful
            assert.equal("success", result.outcome)
            assert.equal(3, #result.successfulUnitIds)

            -- Verify the correct cleanup commands were issued
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 123, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 123, 2, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 456, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 456, 2, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 789, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 789, 2, {}, {})
        end)

        it("should handle empty unit lists gracefully", function()
            -- Call TransferUnits with empty list
            local result = service:TransferUnits(sender.id, receiver.id, {}, false)

            -- Verify the transfer failed (no units to transfer)
            assert.equal("failed", result.outcome)
            assert.equal(0, #result.successfulUnitIds)

            -- Verify no cleanup commands were issued
            assert.spy(spring.GiveOrderToUnit).was_not_called()
        end)

        it("should only issue cleanup commands for successful transfers", function()
            -- Mock TransferUnit to fail for unit 456
            spring.TransferUnit = spy.new(function(self, unitId, teamId, given)
                return unitId ~= 456  -- Fail for unit 456
            end)

            -- Call TransferUnits
            local result = service:TransferUnits(sender.id, receiver.id, {123, 456, 789}, false)

            -- Should have partial success
            assert.equal("success", result.outcome)
            assert.equal(2, #result.successfulUnitIds)  -- 123 and 789 succeeded
            assert.equal(1, #result.failedUnitIds)      -- 456 failed

            -- Verify cleanup commands were only issued for successful units
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 123, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 123, 2, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 789, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was.called_with(spring, 789, 2, {}, {})

            -- Verify no cleanup for failed unit
            assert.spy(spring.GiveOrderToUnit).was_not_called_with(spring, 456, 1, {}, {})
            assert.spy(spring.GiveOrderToUnit).was_not_called_with(spring, 456, 2, {}, {})
        end)
    end)
end)
