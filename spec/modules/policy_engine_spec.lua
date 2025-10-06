local PolicyEngine = require("modules/policy_engine")

describe("PolicyEngine #clear", function()
    local engine

    before_each(function()
        engine = PolicyEngine.new()
    end)

    describe("WHEN no rules are registered", function()
        it("should return empty result", function()
            local result = engine:evaluate("test_category", {})
            assert.is_nil(result.allow)
            assert.is_nil(result.expose)
        end)

        it("should apply default handler when available", function()
            engine:registerDefault("test_category", function() return { default = true } end)
            local result = engine:evaluate("test_category", {})
            assert.is_true(result.expose.default)
        end)
    end)

    describe("WHEN rules are registered", function()
        it("should execute rule with passing predicates", function()
            engine:addRule("test_category", {
                name = "test_rule",
                predicates = { function() return true end },
                handler = function() return { expose = { result = "success" } } end
            })

            local result = engine:evaluate("test_category", {})
            assert.equal("success", result.expose.result)
        end)

        it("should skip rule with failing predicates", function()
            engine:addRule("test_category", {
                name = "test_rule",
                predicates = { function() return false end },
                handler = function() return { expose = { result = "should_not_see" } } end
            })
            engine:registerDefault("test_category", function() return { default = true } end)

            local result = engine:evaluate("test_category", {})
            assert.is_true(result.expose.default)
        end)

        it("should merge expose data from multiple rules", function()
            engine:addRule("test_category", {
                name = "rule1",
                predicates = {},
                handler = function() return { expose = { field1 = "value1" } } end
            })
            engine:addRule("test_category", {
                name = "rule2",
                predicates = {},
                handler = function() return { expose = { field2 = "value2" } } end
            })

            local result = engine:evaluate("test_category", {})
            assert.equal("value1", result.expose.field1)
            assert.equal("value2", result.expose.field2)
        end)

        it("should short-circuit on deny", function()
            engine:addRule("test_category", {
                name = "deny_rule",
                predicates = {},
                handler = function() return { deny = true, reason = "denied" } end
            })
            engine:addRule("test_category", {
                name = "allow_rule",
                predicates = {},
                handler = function() return { expose = { should_not_see = true } } end
            })

            local result = engine:evaluate("test_category", {})
            assert.is_true(result.deny)
            assert.equal("denied", result.reason)
            assert.is_nil(result.expose)
        end)
    end)

    describe("initialization handlers", function()
        it("should register and track init handlers", function()
            local called = false
            engine:registerInitHandler(function() called = true end, "test_policy")

            -- Init handlers are not automatically called during evaluation
            -- They need to be triggered separately
            assert.is_true(#engine.initHandlers == 1)
        end)
    end)

    describe("validators", function()
        it("should register validators for categories", function()
            local validatorCalled = false
            engine:registerValidator("test_category",
                function() validatorCalled = true; return {} end,
                "test_policy")

            local results = engine:validateItem("test_category", {}, function() return {} end)
            assert.is_true(#results == 1)
        end)
    end)

    describe("post-action handlers", function()
        it("should register post-action handlers for categories", function()
            local handlerCalled = false
            engine:registerPostActionHandler("test_category",
                function() handlerCalled = true end,
                "test_policy")

            -- Post-action handlers are not automatically called during evaluation
            assert.is_true(#engine.postActionHandlers["test_category"] == 1)
        end)
    end)
end)
