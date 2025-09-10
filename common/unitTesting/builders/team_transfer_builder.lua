-- Team Transfer Builder
-- Main builder for complete team transfer system including pipeline and API

local PipelineBuilder = require("common/unitTesting/builders/pipeline_builder")
local SpringBuilder = require("common/unitTesting/builders/spring_builder")
local TeamBuilder = require("common/unitTesting/builders/team_builder")

---@class TeamTransferBuilder
---@field WithPolicy fun(policyName: string): TeamTransferBuilder
---@field WithSharingMode fun(mode: string): TeamTransferBuilder
---@field WithModOption fun(key: string, value: any): TeamTransferBuilder
---@field WithSpringBuilder fun(springBuilder: SpringBuilder): TeamTransferBuilder
---@field From fun(pipeline: TeamTransferPipeline): TeamTransferBuilder
---@field Build fun(): TeamTransferAPI
local TeamTransferBuilder = {}

-- Default data for TeamTransferBuilder instances
local defaultData = {
    policies = {},
    modOptions = {},
    springBuilder = nil,
    customPipeline = nil
}

-- Fluent methods that mutate the instance
local methods = {
    ---WithPolicy adds a policy to the team transfer configuration
    ---@param policyName string Name of the policy to add
    ---@return TeamTransferBuilder
    WithPolicy = function(instance, policyName)
        table.insert(instance.policies, policyName)
        return instance
    end,

    ---WithSharingMode configures the unit sharing mode
    ---@param mode string The sharing mode
    ---@return TeamTransferBuilder
    WithSharingMode = function(instance, mode)
        instance.modOptions.unit_sharing_mode = mode
        return instance
    end,

    ---WithModOption sets a mod option
    ---@param key string The mod option key
    ---@param value any The mod option value
    ---@return TeamTransferBuilder
    WithModOption = function(instance, key, value)
        instance.modOptions[key] = value
        return instance
    end,

    ---WithPipeline uses a custom pipeline instead of creating one
    ---@param pipeline TeamTransferPipeline The pipeline to use
    ---@return TeamTransferBuilder
    WithPipeline = function(instance, pipeline)
        instance.customPipeline = pipeline
        return instance
    end
}

-- Build function for the TeamTransferBuilder
local buildFunction = function(instance)
    ---Build creates the final team transfer system
    ---@return table{ pipeline: TeamTransferPipeline, api: TeamTransferAPI }

    -- Set up Spring environment using repository pattern
    local Builders = require("common/unitTesting/builders/index")
    local springRepo = Builders.SpringRepository.new()
    -- Set up alliances between all teams for testing
    for i = 0, 10 do
        for j = 0, 10 do
            if i ~= j then
                springRepo = springRepo:WithAlliance(i, j)
            end
        end
    end
    local springMock = springRepo:Build()
    _G.Spring = springMock

    -- Auto-load unit definitions
    local UnitBuilder = require("common/unitTesting/builders/unit_builder")
    _G.UnitDefs = UnitBuilder.GetAllRealUnitDefs()

    -- Set up service registry and inject repositories
    local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")
    ServiceRegistry.clear()
    
    -- Register repository mocks with alliance setup
    ServiceRegistry.register("SpringRepository", springMock)
    
    -- Set up team repository with alliances between all teams (for testing)
    local teamRepo = Builders.TeamRepository.new():Build()
    for i = 0, 10 do
        for j = 0, 10 do
            if i ~= j then
                teamRepo.SetAlliance(i, j)
            end
        end
    end
    ServiceRegistry.register("TeamRepository", teamRepo)
    ServiceRegistry.register("UnitRepository", Builders.UnitRepository.new():Build())
    
    -- Load only specific policies for testing (avoid loading all policies)
    for _, policyName in ipairs(instance.policies) do
        ServiceRegistry.PolicyRepository().LoadPolicy(policyName)
    end

    -- Set up the pipeline (custom or default)
    local pipeline = instance.customPipeline
    if not pipeline then
        pipeline = require("luarules/gadgets/team_transfer/pipeline")
    end
    _G.TeamTransferPipeline = pipeline

    -- Create a simple API mock for testing (api_gadgets loads later)
    local api = {
        CanShareUnits = function(senderTeamID, receiverTeamID)
            -- Simple mock: allow sharing between allied teams
            if _G.Spring and _G.Spring.AreTeamsAllied then
                return _G.Spring.AreTeamsAllied(senderTeamID, receiverTeamID)
            end
            return true -- Default to allowing for tests
        end
    }
    _G.GG = _G.GG or {}
    _G.GG.TeamTransfer = api

    return {
        pipeline = pipeline,
        api = api
    }
end

-- Create the builder using traditional metatable approach like other builders
local TeamTransferBuilder = {}
TeamTransferBuilder.__index = TeamTransferBuilder

-- Copy methods to TeamTransferBuilder table
for methodName, methodFn in pairs(methods) do
    TeamTransferBuilder[methodName] = methodFn
end

-- Add Build method
TeamTransferBuilder.Build = function(instance)
    return buildFunction(instance)
end

-- Static factory methods
function TeamTransferBuilder.new()
    local instance = {}

    -- Copy default data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end

    return setmetatable(instance, TeamTransferBuilder)
end

function TeamTransferBuilder.From(pipeline)
    local instance = {}

    -- Copy default data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end

    instance.customPipeline = pipeline

    return setmetatable(instance, TeamTransferBuilder)
end

return TeamTransferBuilder