---@class PolicyRepositoryBuilder
---@field policyEnums string[]
local PolicyRepositoryBuilder = {}
PolicyRepositoryBuilder.__index = PolicyRepositoryBuilder

local PolicyRepository = require("luarules.gadgets.team_transfer.repositories.policy_repository")

---@return PolicyRepositoryBuilder
function PolicyRepositoryBuilder.new()
    return setmetatable({ policyEnums = {} }, PolicyRepositoryBuilder)
end


---@param self PolicyRepositoryBuilder
---@param enum string SharedEnums.Policies
---@return PolicyRepositoryBuilder
function PolicyRepositoryBuilder:AddEnum(enum)
    self.policyEnums[#self.policyEnums + 1] = enum
    return self
end

---@param self PolicyRepositoryBuilder
---@return table
function PolicyRepositoryBuilder:Build()
    -- Load policies using the already loaded PolicyRepository
    for i = 1, #self.policyEnums do
        PolicyRepository.LoadPolicy(self.policyEnums[i])
    end
    return PolicyRepository
end

return PolicyRepositoryBuilder


