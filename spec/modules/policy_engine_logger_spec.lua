local PolicyEngineLogger = require("modules/policy_engine_logger")

describe("PolicyEngineLogger #clear", function()
    local logger
    local originalSpringLog

    before_each(function()
        logger = PolicyEngineLogger.new()
        -- Mock Spring.Log to capture calls without printing
        originalSpringLog = _G.Spring.Log
        _G.Spring.Log = spy.new(function() end)
    end)

    after_each(function()
        -- Restore original Spring.Log
        _G.Spring.Log = originalSpringLog
    end)

    describe("GetOutcomeSummary", function()
        it("should summarize unit transfer outcomes", function()
            local result = {
                expose = {
                    canShareUnits = true,
                    sharingMode = "all"
                }
            }
            local summary = PolicyEngineLogger.GetOutcomeSummary("unit_transfer", result)
            assert.is_not_nil(summary:find("Allowed"))
            assert.is_not_nil(summary:find("mode: all"))
        end)

        it("should summarize metal transfer outcomes with tax info", function()
            local result = {
                expose = {
                    canShare = true,
                    amountSendable = 1000,
                    taxRate = 0.2,
                    remainingTaxFreeAllowance = 100
                }
            }
            local summary = PolicyEngineLogger.GetOutcomeSummary("metal_transfer", result)
            assert.is_not_nil(summary:find("Allowed", 1, true))
            assert.is_not_nil(summary:find("max sendable: 1000", 1, true))
            assert.is_not_nil(summary:find("tax: 20.0%", 1, true))
            assert.is_not_nil(summary:find("tax-free allowance: 100", 1, true))
        end)

        it("should summarize energy transfer outcomes", function()
            local result = {
                expose = {
                    canShare = true,
                    maxEnergyShareAmount = 500,
                    taxRate = 0.1
                }
            }
            local summary = PolicyEngineLogger.GetOutcomeSummary("energy_transfer", result)
            assert.is_not_nil(summary:find("Allowed", 1, true))
            assert.is_not_nil(summary:find("max share: 500", 1, true))
            assert.is_not_nil(summary:find("tax: 10.0%", 1, true))
        end)

        it("should summarize command validation outcomes", function()
            local result = {
                expose = {
                    allowGuardCommands = true,
                    allowRepairCommands = false,
                    allowReclaimCommands = true
                }
            }
            local summary = PolicyEngineLogger.GetOutcomeSummary("command_validation", result)
            assert.is_not_nil(summary:find("Guard", 1, true))
            assert.is_not_nil(summary:find("Reclaim", 1, true))
            assert.is_nil(summary:find("Repair", 1, true))
        end)

        it("should handle deny outcomes", function()
            local result = {
                deny = true,
                reason = "Policy denied"
            }
            local summary = PolicyEngineLogger.GetOutcomeSummary("unit_transfer", result)
            assert.is_not_nil(summary:find("Denied", 1, true))
            assert.is_not_nil(summary:find("Policy denied", 1, true))
        end)
    end)

    describe("FormatExposeResult", function()
        it("should format unit transfer expose data", function()
            local expose = {
                canShareUnits = true,
                blockReason = "test reason"
            }
            local formatted = PolicyEngineLogger.FormatExposeResult("unit_transfer", expose)
            assert.is_not_nil(formatted:find("canShareUnits: true", 1, true))
            assert.is_not_nil(formatted:find('blockReason: "test reason"', 1, true))
        end)

        it("should format metal transfer expose data", function()
            local expose = {
                canShare = true,
                amountSendable = 1000,
                taxRate = 0.15,
                blockReason = "insufficient funds"
            }
            local formatted = PolicyEngineLogger.FormatExposeResult("metal_transfer", expose)
            assert.is_not_nil(formatted:find("canShare: true", 1, true))
            assert.is_not_nil(formatted:find("maxAmount: 1000", 1, true))
            assert.is_not_nil(formatted:find("taxRate: 0.15", 1, true))
            assert.is_not_nil(formatted:find('blockReason: "insufficient funds"', 1, true))
        end)

        it("should format command validation expose data", function()
            local expose = {
                allowGuardCommands = true,
                allowRepairCommands = true,
                allowReclaimCommands = false,
                blockReason = "commands disabled"
            }
            local formatted = PolicyEngineLogger.FormatExposeResult("command_validation", expose)
            assert.is_not_nil(formatted:find("allowed: [guard, repair", 1, true))
            assert.is_not_nil(formatted:find('blockReason: "commands disabled"', 1, true))
        end)
    end)

    describe("GetCategoryDisplayName", function()
        it("should return proper display names for categories", function()
            assert.equal("Unit Transfer", PolicyEngineLogger.GetCategoryDisplayName("unit_transfer"))
            assert.equal("Metal Transfer", PolicyEngineLogger.GetCategoryDisplayName("metal_transfer"))
            assert.equal("Energy Transfer", PolicyEngineLogger.GetCategoryDisplayName("energy_transfer"))
            assert.equal("Command Validation", PolicyEngineLogger.GetCategoryDisplayName("command_validation"))
            assert.equal("unknown_category", PolicyEngineLogger.GetCategoryDisplayName("unknown_category"))
        end)
    end)

    describe("IsImplicitDeny", function()
        it("should detect implicit denies for unit transfers", function()
            assert.is_true(PolicyEngineLogger.IsImplicitDeny("unit_transfer", { canShareUnits = false }))
            assert.is_false(PolicyEngineLogger.IsImplicitDeny("unit_transfer", { canShareUnits = true }))
        end)

        it("should detect implicit denies for resource transfers", function()
            assert.is_true(PolicyEngineLogger.IsImplicitDeny("metal_transfer", { canShare = false }))
            assert.is_false(PolicyEngineLogger.IsImplicitDeny("metal_transfer", { canShare = true }))
            assert.is_true(PolicyEngineLogger.IsImplicitDeny("energy_transfer", { canShare = false }))
            assert.is_false(PolicyEngineLogger.IsImplicitDeny("energy_transfer", { canShare = true }))
        end)

        it("should detect implicit denies for command validation", function()
            local noCommands = {}
            local hasCommands = { allowGuardCommands = true }
            assert.is_true(PolicyEngineLogger.IsImplicitDeny("command_validation", noCommands))
            assert.is_false(PolicyEngineLogger.IsImplicitDeny("command_validation", hasCommands))
        end)
    end)

    describe("LogPlan", function()
        it("should handle nil results gracefully", function()
            -- This should not crash
            logger:LogPlan(nil, nil)

            -- Should call Spring.Log with the no result message
            assert.spy(_G.Spring.Log).was_called_with("PIPELINE PLAN", LOG.INFO, "No result to log.")
        end)

        it("should log basic plan structure", function()
            local result = { expose = { test = true } }
            local plan = {
                context = {
                    senderTeamId = 1,
                    receiverTeamId = 2,
                    senderName = "Team Alpha",
                    receiverName = "Team Beta",
                    areAlliedTeams = true,
                    isCheatingEnabled = false
                }
            }

            -- This should not crash and should log appropriate information
            logger:LogPlan(result, plan)

            -- Should call Spring.Log multiple times for the plan structure
            assert.spy(_G.Spring.Log).was_called_with("PIPELINE PLAN", LOG.INFO, "=== PIPELINE PLAN ===")
            assert.spy(_G.Spring.Log).was_called_with("PIPELINE PLAN", LOG.INFO, "[CONTEXT]")
            assert.spy(_G.Spring.Log).was_called_with("PIPELINE PLAN", LOG.INFO, "=== END PLAN ===")
        end)
    end)
end)
