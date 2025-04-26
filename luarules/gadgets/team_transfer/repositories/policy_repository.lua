
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@class PolicyRepository
---@field policies table<string, table> Policy definitions with name, func, and enabled function
local PolicyRepository = {}

function PolicyRepository.new()
    local instance = setmetatable({
        policies = {},
    }, { __index = PolicyRepository })

    -- Load all policies immediately when repository is created
    instance:LoadAllPolicies()

    return instance
end


---@param policyPath string Policy path
function PolicyRepository:LoadPolicy(policyPath)
    local success, err = pcall(function()
        local policy = VFS.Include(policyPath)

        -- Store the complete policy definition
        if type(policy) == "table" and policy.name and policy.func then
            self.policies[policy.name] = policy
        else
            error("Unexpected policy return format: expected table with name and func fields")
        end
    end)
    if not success then
        Spring.Log("PolicyRepository", LOG.ERROR, "Failed to load policy from " .. policyPath .. ": " .. tostring(err))
    end
end

local POLICIES_DIR = "luarules/gadgets/team_transfer/policies/"
function PolicyRepository:LoadAllPolicies()
    -- Game environment: use VFS to find and load all policies
    local policiesDir = "luarules/gadgets/team_transfer/policies/"
    local policyFiles = VFS.DirList(policiesDir, "*.lua")

    for _, path in ipairs(policyFiles) do
        self:LoadPolicy(path)
    end
end

---Get a policy by name
---@param policyName string The policy name
---@return table|nil The complete policy definition, or nil if not found
function PolicyRepository:GetPolicy(policyName)
    return self.policies[policyName]
end

---Get all policies
---@return table<string, table> All policy definitions indexed by name
function PolicyRepository:GetAllPolicies()
    return self.policies
end

return PolicyRepository
