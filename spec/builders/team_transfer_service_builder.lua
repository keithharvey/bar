local TeamTransferService = require("luarules/gadgets/team_transfer/team_transfer_service")
local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local ModOptions = require("luarules/gadgets/team_transfer/modoption_enums")
local PolicyRepository = require("luarules/gadgets/team_transfer/repositories/policy_repository")
local SharingModeRepository = require("luarules/gadgets/team_transfer/repositories/sharing_mode_repository")
local SpringRepositoryBuilder = require("spec/builders/spring_repository_builder")

---@class TeamTransferServiceBuilder
---@field springRepo any
---@field sharingModeRepository SharingModeRepository
---@field policies table
---@field inlinePolicies table
local TeamTransferServiceBuilder = {}
TeamTransferServiceBuilder.__index = TeamTransferServiceBuilder

-- Default data for TeamTransferServiceBuilder instances
local defaultData = {
    policies = {},
    inlinePolicies = {},
}

---Create a new TeamTransferServiceBuilder instance
---@return TeamTransferServiceBuilder
function TeamTransferServiceBuilder.new()
    local instance = setmetatable({}, TeamTransferServiceBuilder)
    for k, v in pairs(defaultData) do
        instance[k] = v
    end
    -- Ensure repositories exist by default so policies can rely on them
    instance.springRepo = SpringRepositoryBuilder.new()
    instance.sharingModeRepository = SharingModeRepository.new()
    return instance
end

---WithSpringRepository applies a Spring repository (mod options, etc.)
---@param self TeamTransferServiceBuilder
---@param springRepository table The Spring repository/builder to use
---@return TeamTransferServiceBuilder
function TeamTransferServiceBuilder:WithSpringRepository(springRepository)
    self.springRepo = springRepository
    return self
end

---WithPolicy adds a specific policy module for testing
---@param self TeamTransferServiceBuilder
---@param policy_enum string SharedEnums.Policies
---@return TeamTransferServiceBuilder
function TeamTransferServiceBuilder:WithPolicy(policy_enum)
    -- Accept enum (string). If a module/table is provided (already required in tests), ignore.
    self._enabledPolicies = self._enabledPolicies or {}
    table.insert(self._enabledPolicies, policy_enum)
    return self
end

---WithPolicyFunction adds an inline policy function for testing
---@param self TeamTransferServiceBuilder
---@param policyFunction function|table A function that receives a DSL builder, or a policy table with {name, func}
---@return TeamTransferServiceBuilder
function TeamTransferServiceBuilder:WithPolicyFunction(policyFunction)
    self._inlinePolicies = self._inlinePolicies or {}
    table.insert(self._inlinePolicies, policyFunction)
    return self
end

---WithSharingMode applies a sharing mode preset configuration
---@param self TeamTransferServiceBuilder
---@param sharingMode string A value from SharedEnums.SharingModes
---@return TeamTransferServiceBuilder
function TeamTransferServiceBuilder:WithSharingMode(sharingMode)
    -- Set the sharing mode
    self.springRepo:WithModOption(ModOptions.Options.SharingMode, sharingMode)

    -- print("Sharing mode: " .. tostring(sharingMode))
    -- Try to load from repository first, fallback to hardcoded values for test environment
    if self.sharingModeRepository and self.sharingModeRepository.LoadSharingMode then
        local success, config = pcall(self.sharingModeRepository.LoadSharingMode, self.sharingModeRepository, sharingMode)
        if success and config and config.modOptions then
            for modOptionKey, modOptionConfig in pairs(config.modOptions) do
                self.springRepo:WithModOption(modOptionKey, modOptionConfig.value)
            end
        end
    end

    return self
end

---Build creates the TeamTransferService instance
---@param self TeamTransferServiceBuilder
---@return TeamTransferService
function TeamTransferServiceBuilder:Build()
    local springRepo = self.springRepo
    if type(springRepo) == "table" and springRepo.Build then
        springRepo = springRepo:Build()
    end

    -- Create policy repository (loads all policies automatically)
    local policyRepo = PolicyRepository.new()

    -- Create the service with policy whitelist (if any)
    local service = TeamTransferService.new(springRepo, policyRepo, SharingModeRepository, self._enabledPolicies)

    return service
end

return TeamTransferServiceBuilder
