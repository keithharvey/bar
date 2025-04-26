local Builders = require("spec/builders/index")
local SharedEnums = require("luarules.gadgets.team_transfer.shared_enums")
local UnitTransfer = require("luarules.gadgets.team_transfer.actions.unit_transfer")

describe("UnitTransfer action #clear #actions", function()
    local sender = Builders.Team:new():Human()
    local receiver = Builders.Team:new():Human()
    local spring = Builders.SpringRepository.new()
        :WithTeam(sender)
        :WithTeam(receiver)
        :WithRealUnitDefs()
        :Build()


    describe("when unit sharing is allowed", function()
        local unitIds
        local result
        local spring

        before_each(function()
            unitIds = {}
            sender:WithUnit("armpw", function(unitId) table.insert(unitIds, unitId) end)
            sender:WithUnit("armck", function(unitId) table.insert(unitIds, unitId) end)

            -- Rebuild spring repo after adding units
            spring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :Build()

            -- Manually set _builtTeams since the builder is broken
            spring._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }
        end)

        it("should successfully transfer all units when sharing is allowed", function()
            local validationResults = {}
            for _, unitId in ipairs(unitIds) do
                table.insert(validationResults, { unitId = unitId, ok = true })
            end

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = unitIds,
                given = false,
                validationResults = validationResults,
                policyResult = {
                    canShareUnits = true
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_true(result.success)
            assert.equal(#unitIds, #result.successfulUnitIds)
            assert.equal(0, #result.failedUnitIds)
            assert.is_nil(result.reason)
        end)

        it("should handle mixed success/failure scenarios", function()
            -- Add an invalid unit ID to test partial failure
            local mixedUnitIds = {unitIds[1], 9999, unitIds[2]}  -- 9999 is invalid

            local validationResults = {
                { unitId = unitIds[1], ok = true },
                { unitId = 9999, ok = false, reason = "invalid_unit" },
                { unitId = unitIds[2], ok = true }
            }

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = mixedUnitIds,
                given = false,
                validationResults = validationResults,
                policyResult = {
                    canShareUnits = true
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_true(result.success)  -- Should be true if any units transferred
            assert.equal(2, #result.successfulUnitIds)  -- Valid units transferred
            assert.equal(1, #result.failedUnitIds)  -- Invalid unit failed
            assert.equal(9999, result.failedUnitIds[1])
        end)

        it("should set given parameter correctly", function()
            local validationResults = {
                { unitId = unitIds[1], ok = true }
            }

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = {unitIds[1]},
                given = true,  -- Test given parameter
                validationResults = validationResults,
                policyResult = {
                    canShareUnits = true
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_true(result.success)
            assert.equal(1, #result.successfulUnitIds)
            assert.equal(0, #result.failedUnitIds)
        end)
    end)

    describe("when unit sharing is not allowed", function()
        local unitIds
        local result
        local spring

        before_each(function()
            unitIds = {}
            sender:WithUnit("armpw", function(unitId) table.insert(unitIds, unitId) end)
            sender:WithUnit("armck", function(unitId) table.insert(unitIds, unitId) end)

            -- Rebuild spring repo after adding units
            spring = Builders.SpringRepository.new()
                :WithTeam(sender)
                :WithTeam(receiver)
                :Build()

            -- Manually set _builtTeams since the builder is broken
            spring._builtTeams = {
                [sender.id] = sender:Build(),
                [receiver.id] = receiver:Build()
            }
        end)

        it("should fail to transfer any units when sharing is disabled", function()
            local validationResults = {}
            for _, unitId in ipairs(unitIds) do
                table.insert(validationResults, { unitId = unitId, ok = true })
            end

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = unitIds,
                given = false,
                validationResults = validationResults,
                policyResult = {
                    canShareUnits = false,
                    blockReason = SharedEnums.BlockReason.Disabled
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_false(result.success)
            assert.equal(0, #result.successfulUnitIds)
            assert.equal(#unitIds, #result.failedUnitIds)
            assert.is_not_nil(result.reason)
            assert.is_string(result.reason)
        end)

        it("should include policy result in response", function()
            local validationResults = {}
            for _, unitId in ipairs(unitIds) do
                table.insert(validationResults, { unitId = unitId, ok = true })
            end

            local policyResult = {
                canShareUnits = false,
                blockReason = "Test block reason"
            }

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = unitIds,
                given = false,
                validationResults = validationResults,
                policyResult = policyResult,
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.equal(policyResult, result.policyResult)
        end)
    end)

    describe("edge cases", function()
        it("should handle empty unit list", function()
            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = {},
                validationResults = {},
                given = false,
                policyResult = {
                    canShareUnits = true
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_false(result.success)  -- No units to transfer
            assert.equal(0, #result.successfulUnitIds)
            assert.equal(0, #result.failedUnitIds)
            assert.is_not_nil(result.reason)
        end)

        it("should handle invalid unit IDs gracefully", function()
            local validationResults = {
                { unitId = -1, ok = false, reason = "invalid_unit" },
                { unitId = 0, ok = false, reason = "invalid_unit" },
                { unitId = 9999, ok = false, reason = "invalid_unit" }
            }

            local ctx = {
                senderTeamId = sender.id,
                receiverTeamId = receiver.id,
                unitIds = {-1, 0, 9999},  -- All invalid
                validationResults = validationResults,
                given = false,
                policyResult = {
                    canShareUnits = true
                },
                repositories = {
                    springRepo = spring
                }
            }

            result = UnitTransfer(ctx)

            assert.is_false(result.success)
            assert.equal(0, #result.successfulUnitIds)
            assert.equal(3, #result.failedUnitIds)
            assert.is_not_nil(result.reason)
        end)
    end)
end)
