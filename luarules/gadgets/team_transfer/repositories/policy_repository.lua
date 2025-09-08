
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
-- Policies are loaded on-demand to avoid loading all policies during testing

---@class PolicyRepository
local PolicyRepository = {}

-- Policy path mapping using enum (loaded on-demand)
local policyPaths = {
    [SharedEnums.Policies.BuildingUnlocksSharing] = "luarules/gadgets/team_transfer/policies/building_unlocks_sharing.lua",
    [SharedEnums.Policies.UnitSharingMode] = "luarules/gadgets/team_transfer/policies/unit_sharing_mode.lua",
    [SharedEnums.Policies.AlliedReclaim] = "luarules/gadgets/team_transfer/policies/allied_reclaim.lua",
    [SharedEnums.Policies.EnemyTransfer] = "luarules/gadgets/team_transfer/policies/enemy_transfer.lua",
    [SharedEnums.Policies.MetalSendThreshold] = "luarules/gadgets/team_transfer/policies/metal_send_threshold.lua",
    [SharedEnums.Policies.PreventExcessiveShare] = "luarules/gadgets/team_transfer/policies/prevent_excessive_share.lua",
    [SharedEnums.Policies.SystemCleanup] = "luarules/gadgets/team_transfer/policies/system_cleanup.lua",
    [SharedEnums.Policies.TaxResourceSharing] = "luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua",
    [SharedEnums.Policies.AssistAlly] = "luarules/gadgets/team_transfer/policies/assist_ally.lua"
}

local loadedPolicies = {}

-- Cached sorted policies by type
local sortedPoliciesCache = {}

-- Topological sort for dependency-based policy ordering
local function topologicalSort(entries)
	local sorted = {}
	local visited = {}
	local visiting = {}
	
	local function visit(entry)
		if visiting[entry.name] then
			error("Circular dependency detected involving policy: " .. entry.name)
		end
		if visited[entry.name] then
			return
		end
		
		visiting[entry.name] = true
		
		-- Visit all dependencies first
		if entry.dependencies then
			for _, depName in ipairs(entry.dependencies) do
				for _, depEntry in ipairs(entries) do
					if depEntry.name == depName then
						visit(depEntry)
						break
					end
				end
			end
		end
		
		visiting[entry.name] = nil
		visited[entry.name] = true
		sorted[#sorted + 1] = entry
	end
	
	-- Visit all entries
	for _, entry in ipairs(entries) do
		visit(entry)
	end
	
	return sorted
end

---Load a specific policy by enum
---@param policyEnum string Policy enum from SharedEnums.Policies
function PolicyRepository.LoadPolicy(policyEnum)
    if not loadedPolicies[policyEnum] then
        local path = policyPaths[policyEnum]
        if path then
            local success, err = pcall(function()
                VFS.Include(path)
            end)
            if success then
                loadedPolicies[policyEnum] = true
            else
                Spring.Log("PolicyRepository", "ERROR", "Failed to load policy '" .. policyEnum .. "': " .. tostring(err))
            end
        end
    end
end

---Load all policies (they self-register via FluentPolicy)
function PolicyRepository.LoadAllPolicies()
    for policyEnum, _ in pairs(policyPaths) do
        PolicyRepository.LoadPolicy(policyEnum)
    end
end

-- Store policies directly in repository
local policies = {
    [SharedEnums.TransferCategory.MetalTransfer] = {},
    [SharedEnums.TransferCategory.EnergyTransfer] = {},
    [SharedEnums.TransferCategory.UnitTransfer] = {},
    [SharedEnums.TransferCategory.CommandValidation] = {},
    [SharedEnums.TransferCategory.TeamEvents] = {}
}

---Register a policy action (called by FluentPolicy)
---@param category string Policy category
---@param policyAction table Policy action entry
function PolicyRepository.RegisterPolicyAction(category, policyAction)
    local list = policies[category]
    if list then
        list[#list + 1] = policyAction
    else
        policies[category] = { policyAction }
    end
end

---Get all registered policies by type
---@return table<string, table[]> policies Policies organized by type
function PolicyRepository.GetPolicies()
    return policies
end

---Get topologically sorted policies for a category (cached)
---@param category string The policy category
---@return table[] sortedPolicies Policies sorted by dependencies
function PolicyRepository.GetSortedPolicies(category)
    if not sortedPoliciesCache[category] then
        local allPolicies = PolicyRepository.GetPolicies()
        local categoryPolicies = allPolicies[category] or {}
        sortedPoliciesCache[category] = topologicalSort(categoryPolicies)
    end
    return sortedPoliciesCache[category]
end

---Clear policy cache (for testing)
function PolicyRepository.ClearCache()
    sortedPoliciesCache = {}
end

---Get policy module by enum
---@param policyEnum string Policy enum from SharedEnums.Policies
---@return any policyModule The loaded policy module
function PolicyRepository.GetPolicyModule(policyEnum)
    return policyModules[policyEnum]
end

return PolicyRepository
