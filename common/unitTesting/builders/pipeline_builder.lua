---@class PipelineBuilder
---@field springBuilder any
---@field springRepository any
---@field policies table
---@field unitRepository any
---@field teamRepository any
local PipelineBuilder = {}
PipelineBuilder.__index = PipelineBuilder
local ServiceRegistry = require("luarules.gadgets.team_transfer.service_registry")
local PolicyRepository = require("luarules.gadgets.team_transfer.repositories.policy_repository")
local RealUnitRepository = require("luarules.gadgets.team_transfer.unit_repository")
local UnitRepositoryBuilder = require("common/unitTesting/builders/unit_repository_builder")
local SpringRepositoryBuilder = require("common/unitTesting/builders/spring_repository_builder")
local TeamRepositoryBuilder = require("common/unitTesting/builders/team_repository_builder")

-- Default data for PipelineBuilder instances
local defaultData = {
    springBuilder = nil,
    springRepository = nil,
    policies = {},
    unitRepository = nil,
    teamRepository = nil,
}

---Create a new PipelineBuilder instance
---@see PipelineBuilder.new_static
---@return PipelineBuilder
function PipelineBuilder.new()
    local instance = setmetatable({}, PipelineBuilder)
    -- Copy default data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end
    -- Ensure repository builders exist by default so policies can rely on them
    instance.springRepository = instance.springRepository or SpringRepositoryBuilder.new()
    instance.teamRepository = instance.teamRepository or TeamRepositoryBuilder.new()
    instance.unitRepository = instance.unitRepository or UnitRepositoryBuilder.new()
    return instance
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
---@param policy table The loaded policy module
---@return PipelineBuilder
function PipelineBuilder:WithPolicy(policy)
    table.insert(self.policies, policy)
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
    -- Inject repository mocks into service registry

    -- Clear any existing services for clean test state
    ServiceRegistry.clear()

    -- Register repository mocks (build them if they're builders)
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

    -- Register PolicyRepository (use real implementation for tests)
    ServiceRegistry.register("PolicyRepository", PolicyRepository)

    -- Load all policies so deferred registrations exist before pipeline executes them
    if PolicyRepository and PolicyRepository.LoadAllPolicies then
        PolicyRepository.LoadAllPolicies()
    end

    local springRepo = ServiceRegistry.SpringRepository()
    if springRepo then
        _G.Spring.GetGameFrame = springRepo.GetGameFrame
        _G.Spring.IsCheatingEnabled = springRepo.IsCheatingEnabled
        _G.Spring.GetModOptions = springRepo.GetModOptions
        _G.Spring.Log = springRepo.Log
    end
    
    -- Load the pipeline module fresh each time to reset any internal caches
    if package and package.loaded then
        package.loaded["luarules.gadgets.team_transfer.pipeline"] = nil
    end
    local pipeline = require("luarules.gadgets.team_transfer.pipeline")

    -- Ensure global reference for modules that expect it
    _G.TeamTransferPipeline = pipeline


    -- Seed the real unit repository if a builder/mock was provided
    if self and self.unitRepository and type(self.unitRepository) == "table" then
        local realRepo = RealUnitRepository
        local teamUnits = self.unitRepository.teamUnits or {}
        for teamID, units in pairs(teamUnits) do
            for unitID, unitDefID in pairs(units) do
                if realRepo and type(realRepo.unitAdded) == "function" then
                    realRepo.unitAdded(unitID, unitDefID, teamID)
                end
            end
        end
    end
    return pipeline
end


return PipelineBuilder