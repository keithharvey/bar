---@class ServiceRegistry
local ServiceRegistry = {}

local services = {}

---@param serviceName string
---@param serviceInstance any
function ServiceRegistry.register(serviceName, serviceInstance)
    services[serviceName] = serviceInstance
end

---@param serviceName string
---@return any
function ServiceRegistry.get(serviceName)
    return services[serviceName]
end

---@param serviceName string
---@param factory function
---@return any
function ServiceRegistry.getOrCreate(serviceName, factory)
    if not services[serviceName] then
        services[serviceName] = factory()
    end
    return services[serviceName]
end

function ServiceRegistry.clear()
    services = {}
end

---@return TeamRepository
function ServiceRegistry.TeamRepository()
    return ServiceRegistry.get("TeamRepository")
end

---@return UnitRepository
function ServiceRegistry.UnitRepository()
    return ServiceRegistry.get("UnitRepository")
end

---@return SpringRepository
function ServiceRegistry.SpringRepository()
    return ServiceRegistry.get("SpringRepository")
end

---@return PolicyRepository
function ServiceRegistry.PolicyRepository()
    local repo = ServiceRegistry.get("PolicyRepository")
    if not repo then
        -- Create PolicyRepository on demand if it doesn't exist
        repo = VFS.Include("luarules/gadgets/team_transfer/repositories/policy_repository.lua")
        ServiceRegistry.register("PolicyRepository", repo)
    end
    return repo
end

return ServiceRegistry
