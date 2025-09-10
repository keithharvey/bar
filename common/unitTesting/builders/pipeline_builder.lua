---@class PipelineBuilder
---@field springBuilder any
---@field springRepository any
---@field policies table
---@field unitRepository any
---@field teamRepository any
local PipelineBuilder = {}
PipelineBuilder.__index = PipelineBuilder

local Pipeline = require("luarules.gadgets.team_transfer.pipeline")

local ServiceRegistry = require("luarules.gadgets.team_transfer.service_registry")
local UnitRepositoryBuilder = require("common/unitTesting/builders/unit_repository_builder")
local SpringRepositoryBuilder = require("common/unitTesting/builders/spring_repository_builder")
local TeamRepositoryBuilder = require("common/unitTesting/builders/team_repository_builder")
local PolicyRepositoryBuilder = require("common/unitTesting/builders/policy_repository_builder")

-- Default data for PipelineBuilder instances
local defaultData = {
    springBuilder = nil,
    springRepository = nil,
    policies = {},
    unitRepository = nil,
    teamRepository = nil,
    policyRepository = nil,
}

---Create a new PipelineBuilder instance
---@see PipelineBuilder.new_static
---@return PipelineBuilder
function PipelineBuilder.new()
    local instance = setmetatable({}, PipelineBuilder)
    for k, v in pairs(defaultData) do
        instance[k] = v
    end
    -- Ensure repository builders exist by default so policies can rely on them
    instance.springRepository = SpringRepositoryBuilder.new()
    instance.teamRepository = TeamRepositoryBuilder.new()
    instance.unitRepository = UnitRepositoryBuilder.new()
    instance.policyRepository = PolicyRepositoryBuilder.new()
    return instance
end

---WithPolicyRepository manages policies
---@param self PolicyBuilder
---@param policyRepository table The Spring repository/builder to use
---@return PolicyBuilder
function PipelineBuilder:WithPolicyRepository(policyRepository)
    self.policyRepository = policyRepository
    return self
end

---WithSpringRepository applies a Spring repository (mod options, etc.)
---@param self PipelineBuilder
---@param springRepository table The Spring repository/builder to use
---@return PipelineBuilder
function PipelineBuilder:WithSpringRepository(springRepository)
    self.springRepository = springRepository
    return self
end

---WithPolicy adds a specific policy module for testing
---@param self PipelineBuilder
---@param policy string SharedEnums.Policies
---@return PipelineBuilder
function PipelineBuilder:WithPolicy(policy_enum)
    -- Accept enum (string). If a module/table is provided (already required in tests), ignore.
    self.policyRepository:AddEnum(policy_enum)
    return self
end

---WithUnitRepository seeds the real unit repository from a builder/mock
---@param self PipelineBuilder
---@param unitRepository any
---@return PipelineBuilder
function PipelineBuilder:WithUnitRepository(unitRepository)
    self.unitRepository = unitRepository
    return self
end

---WithTeamRepository stores a team repository for future use
---@param self PipelineBuilder
---@param teamRepository any
---@return PipelineBuilder
function PipelineBuilder:WithTeamRepository(teamRepository)
    self.teamRepository = teamRepository
    return self
end

---Build creates the final pipeline from the current configuration
---@param self PipelineBuilder
---@return TeamTransferPipeline
function PipelineBuilder:Build()
    local springRepo = self.springRepository
    if type(springRepo) == "table" and springRepo.Build then
        springRepo = springRepo:Build()
    end
    ServiceRegistry.register("SpringRepository", springRepo)

    local unitRepo = self.unitRepository
    if type(unitRepo) == "table" and unitRepo.Build then
        unitRepo = unitRepo:Build()
    end
    ServiceRegistry.register("UnitRepository", unitRepo)

    local teamRepo = self.teamRepository
    if type(teamRepo) == "table" and teamRepo.Build then
        teamRepo = teamRepo:Build()
    end
    ServiceRegistry.register("TeamRepository", teamRepo)

    local policyRepo = self.policyRepository
    if type(policyRepo) == "table" and policyRepo.Build then
        policyRepo = policyRepo:Build()
    end
    ServiceRegistry.register("PolicyRepository", policyRepo)

    return Pipeline.new()
end


return PipelineBuilder