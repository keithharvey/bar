describe("Team Transfer Builder", function()
    local Builders = require("common/unitTesting/builders/index")
    local pipeline, api

    before_each(function()
        -- Create fresh pipeline for each test (stateless)
        local result = Builders.TeamTransfer.Build()
        pipeline = result.pipeline
        api = result.api
    end)

    describe("Basic functionality", function()
        it("should create a team transfer scenario", function()
            assert.is_not_nil(pipeline)
            assert.is_not_nil(api)
        end)

        it("should have real API available", function()
            assert.is_not_nil(api)
            assert.is_not_nil(api.RegisterPolicy)
            assert.is_not_nil(api.GetPolicies)
            assert.is_not_nil(api.GetPipeline)
        end)

        it("should support WithPolicy pattern", function()
            local result = Builders.TeamTransfer.WithPolicy("test_policy").Build()
            assert.is_not_nil(result.pipeline)
            assert.is_not_nil(result.api)
        end)
    end)

    describe("Real API integration", function()
        it("should support policy registration using real API", function()
            -- Test that the API method exists (actual functionality tested elsewhere)
            assert.is_function(api.RegisterPolicy)
        end)

        it("should support policy queries using real API", function()
            -- Test that the API method exists (actual functionality tested elsewhere)
            assert.is_function(api.GetPolicies)
        end)

        it("should support pipeline access using real API", function()
            -- Test that the API method exists (actual functionality tested elsewhere)
            assert.is_function(api.GetPipeline)
        end)
    end)
end)





