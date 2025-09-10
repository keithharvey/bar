-- Fluent policy API with predicate-based composition
-- Supports both instance methods and static methods for better IDE navigation

-- Removed shared_logging dependency

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")

local M = {}

M.TransferCategory = SharedEnums.TransferCategory
M.Predicates = Predicates

-- In-memory policy registry
local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")

local function pushPolicyAction(policyType, entry)
    -- Delegate registration to the repository (orchestrator)
    local repo = ServiceRegistry.PolicyRepository()
    if repo and repo.RegisterPolicyAction then
        repo.RegisterPolicyAction(policyType, entry)
    end
end

---@class PolicyContext
---@field predicates table List of predicates that must pass
---@field conditions table List of additional conditions
---@field policyType string The transfer category
---@field policyName string Name of the policy
---@field commandFlag string? Specific command flag for command validation

---@class PredicateBuilder
---@field policyName string
---@field policyType string
---@field commandFlag string|nil
---@field predicates table
---@field conditions table
local PredicateBuilder = {}
PredicateBuilder.__index = PredicateBuilder

function PredicateBuilder.new(policyName, initialPredicates, policyType, commandFlag)
    return setmetatable({
        policyName = policyName,
        policyType = policyType,
        commandFlag = commandFlag,
        predicates = initialPredicates or {},
        conditions = {},
    }, PredicateBuilder)
end

local function evalPredicates(self, ctx)
    for i = 1, #self.predicates do
        local p = self.predicates[i]
        local ok = true
        if type(p) == "function" then
            ok = not not p(ctx)
        elseif type(p) == "table" and type(p.fn) == "function" then
            ok = not not p.fn(ctx)
        end
        if not ok then return false end
    end
    return true
end

local function evalConditions(self, ctx)
    for i = 1, #self.conditions do
        local c = self.conditions[i]
        if not c.fn(ctx) then return false end
    end
    return true
end

---@return PredicateBuilder
function PredicateBuilder:When(conditionFn)
    self.conditions[#self.conditions + 1] = { fn = conditionFn, type = "positive" }
    return self
end

---@return PredicateBuilder
function PredicateBuilder:WhenNot(conditionFn)
    self.conditions[#self.conditions + 1] = { fn = function(ctx) return not conditionFn(ctx) end, type = "negative" }
    return self
end

local function buildAllowExpose(self)
    if self.policyType == M.TransferCategory.CommandValidation then
        if self.commandFlag then
            local expose = {}
            expose[self.commandFlag] = true
            return { allow = true, expose = { [M.TransferCategory.CommandValidation] = expose } }
        else
            local expose = {
                allowGuardCommands = true,
                allowRepairCommands = true,
                allowReclaimCommands = true,
                blockReason = nil,
            }
            return { allow = true, expose = { [M.TransferCategory.CommandValidation] = expose } }
        end
    elseif self.policyType == M.TransferCategory.UnitTransfer then
        return { allow = true, expose = { [M.TransferCategory.UnitTransfer] = { canShareUnits = true } } }
    elseif self.policyType == M.TransferCategory.MetalTransfer then
        return { allow = true, expose = { [M.TransferCategory.MetalTransfer] = { canShare = true, maxMetalShareAmount = 1000 } } }
    elseif self.policyType == M.TransferCategory.EnergyTransfer then
        return { allow = true, expose = { [M.TransferCategory.EnergyTransfer] = { canShare = true, maxEnergyShareAmount = 1000 } } }
    else
        return { allow = true }
    end
end

local function commitRulePair(self, allow)
    -- primary
    pushPolicyAction(self.policyType, {
        name = self.policyName .. (allow and ":allow" or ":deny"),
        parent = self.policyName,
        derived = false,
        inverse = false,
        predicates = self.predicates,
        conditions = self.conditions,
        handler = function(ctx)
            local ok = evalPredicates(self, ctx) and evalConditions(self, ctx)
            if not ok then return nil end
            if allow then return buildAllowExpose(self) else return { deny = true } end
        end,
    })
    -- inverse (negate conditions) as a derived action under the same policy
    pushPolicyAction(self.policyType, {
        name = self.policyName .. (allow and ":deny" or ":allow"),
        parent = self.policyName,
        derived = true,
        inverse = true,
        predicates = self.predicates,
        conditions = { { fn = function(ctx) return not evalConditions(self, ctx) end, type = "inverse" } },
        handler = function(ctx)
            local ok = evalPredicates(self, ctx) and evalConditions({ conditions = { { fn = function(_) return true end } } }, ctx) -- always true here to run inverse only on negation
            if not ok then return nil end
            if allow then return { deny = true } else return buildAllowExpose(self) end
        end,
    })
end

---@return PredicateBuilder
function PredicateBuilder:Allow()
    commitRulePair(self, true)
    return self
end

---@return PredicateBuilder
function PredicateBuilder:Deny()
    commitRulePair(self, false)
    return self
end

---@return PredicateBuilder
function PredicateBuilder:Use(handlerFn)
    pushPolicyAction(self.policyType, {
        name = self.policyName,
        predicates = self.predicates,
        conditions = self.conditions,
        handler = handlerFn,
    })
    return self
end

---@class PolicyScopeBuilder
---@field policyName string
---@field allied boolean
local PolicyScopeBuilder = {}
PolicyScopeBuilder.__index = PolicyScopeBuilder

function PolicyScopeBuilder.new(policyName, allied)
    return setmetatable({ policyName = policyName, allied = allied }, PolicyScopeBuilder)
end

---@return PredicateBuilder
function PolicyScopeBuilder:Guard()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { Predicates.Command["targetAllied"] } or { Predicates.Command["targetEnemy"] },
        M.TransferCategory.CommandValidation,
        "allowGuardCommands"
    )
end

---@return PredicateBuilder
function PolicyScopeBuilder:Repair()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { Predicates.Command["targetAllied"] } or { Predicates.Command["targetEnemy"] },
        M.TransferCategory.CommandValidation,
        "allowRepairCommands"
    )
end

---@return PredicateBuilder
function PolicyScopeBuilder:Reclaim()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { Predicates.Command["targetAllied"] } or { Predicates.Command["targetEnemy"] },
        M.TransferCategory.CommandValidation,
        "allowReclaimCommands"
    )
end

---@return PredicateBuilder
function PolicyScopeBuilder:MetalTransfers()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { { name = "areAlliedTeams", fn = function(ctx) return ctx.areAlliedTeams end } }
                 or { { name = "areEnemyTeams", fn = function(ctx) return not ctx.areAlliedTeams end } },
        M.TransferCategory.MetalTransfer,
        nil
    )
end

---@return PredicateBuilder
function PolicyScopeBuilder:EnergyTransfers()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { { name = "areAlliedTeams", fn = function(ctx) return ctx.areAlliedTeams end } }
                 or { { name = "areEnemyTeams", fn = function(ctx) return not ctx.areAlliedTeams end } },
        M.TransferCategory.EnergyTransfer,
        nil
    )
end

---@return PredicateBuilder
function PolicyScopeBuilder:UnitTransfers()
    return PredicateBuilder.new(
        self.policyName,
        self.allied and { { name = "areAlliedTeams", fn = function(ctx) return ctx.areAlliedTeams end } }
                 or { { name = "areEnemyTeams", fn = function(ctx) return not ctx.areAlliedTeams end } },
        M.TransferCategory.UnitTransfer,
        nil
    )
end

---@class RootPolicyBuilder
---@field policyName string
---@field mod_option any
local RootPolicyBuilder = {}
RootPolicyBuilder.__index = RootPolicyBuilder

---@param policyName string
---@param modOption any
---@return RootPolicyBuilder
function RootPolicyBuilder.new(policyName, modOption)
    return setmetatable({
        policyName = policyName,
        mod_option = modOption
    }, RootPolicyBuilder)
end

-- Create the new flat architecture with specific command methods
---@return PolicyScopeBuilder
function RootPolicyBuilder:Allied()
    return PolicyScopeBuilder.new(self.policyName, true)
end

---@return PolicyScopeBuilder
function RootPolicyBuilder:Enemy()
    return PolicyScopeBuilder.new(self.policyName, false)
end

-- Store deferred policy registrations
local deferredPolicies = {}

---Register a policy using the fluent builder (deferred execution)
---@overload fun(policyName: string, registrationFn: fun(policy: RootPolicyBuilder))
---@param policyName string
---@param options table|fun(policy: RootPolicyBuilder)
---@param registrationFn fun(policy: RootPolicyBuilder)
function M.RegisterPolicy(policyName, options, registrationFn)
    -- Handle function overloading: RegisterPolicy(name, fn) or RegisterPolicy(name, options, fn)
    if type(options) == "function" then
        registrationFn = options
        options = {}
    end

    -- All policies use deferred execution by default
    table.insert(deferredPolicies, {
        name = policyName,
        options = options,
        registrationFn = registrationFn
    })
end

---Check if there are deferred policies to execute
---@return boolean
function M.HasDeferredPolicies()
    return #deferredPolicies > 0
end

---Execute all deferred policy registrations
---@param context table Context containing Spring mocks and other dependencies
function M.ExecuteDeferredPolicies(context)
    print("DEBUG: ExecuteDeferredPolicies called with", #deferredPolicies, "policies")
    for _, policy in ipairs(deferredPolicies) do

        -- Get mod option value for this policy
        local modOptionValue = nil
        if context.repositories and context.repositories.SpringRepository then
            local springRepo = context.repositories.SpringRepository
            local modOptions = springRepo.GetModOptions and springRepo.GetModOptions() or nil
            if modOptions then
                modOptionValue = modOptions[policy.name]
            end
        end

        -- Execute the policy registration without modifying globals
        local success, err = pcall(function()
            local builder = RootPolicyBuilder.new(policy.name, modOptionValue)
            policy.registrationFn(builder)
        end)

        if not success then
            -- Use context Spring for logging if available
            local logFunc = context.Spring and context.Spring.Log or Spring.Log
            logFunc("[FLUENT_POLICY]", "ERROR", "Failed to execute deferred policy '" .. policy.name .. "': " .. tostring(err))
        end
    end

    -- Clear the deferred policies after execution
    deferredPolicies = {}
end

-- The following named no-op functions are F12 navigation targets for the fluent API.
-- They intentionally do nothing at runtime; they exist purely for LSP navigation.

---F12 target for When()
function M.Action_When() end

---F12 target for Use()
function M.Action_Use() end

---F12 target for Allow()
function M.Action_Allow() end

---F12 target for Deny()
function M.Action_Deny() end

---F12 target for Allied Guard command policy
function M.ForAlliedCommands_WhenGuard() end

---F12 target for Allied Repair command policy
function M.ForAlliedCommands_WhenRepair() end

---F12 target for Allied Reclaim command policy
function M.ForAlliedCommands_WhenReclaim() end

---F12 target for Allied Unit Transfers policy
function M.ForAlliedUnitTransfers_Target() end

---@class PolicyBuilder
---@field new fun(): PolicyBuilder
local PolicyBuilder = {}
PolicyBuilder.__index = PolicyBuilder

function PolicyBuilder.new()
    return setmetatable({}, PolicyBuilder)
end

---@param self PolicyBuilder
---@return PolicyScopeBuilder
function PolicyBuilder:Allied()
    return RootPolicyBuilder.new("static"):Allied()
end

---@param self PolicyBuilder
---@return PolicyScopeBuilder
function PolicyBuilder:Enemy()
    return RootPolicyBuilder.new("static"):Enemy()
end

M.PolicyBuilder = PolicyBuilder

return M


