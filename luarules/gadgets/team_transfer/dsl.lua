local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local MetalTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/metal_transfer.lua")
local EnergyTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/energy_transfer.lua")
local UnitTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/unit_transfer.lua")
local GuardTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/guard_transfer.lua")
local RepairTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/repair_transfer.lua")
local ReclaimTransferDefaults = VFS.Include("luarules/gadgets/team_transfer/default_results/reclaim_transfer.lua")

---@class DSL
---@field engine PolicyEngine
---@field policyName string
---@field mod_options table
---@field predicates table[]
---@field category TransferCategory?
local DSL = {}
DSL.__index = function(table, key)
    if key == "mod_option" then
        return table.mod_options[table.policyName]
    end
    return DSL[key]
end

---Create a new TeamTransfer DSL builder bound to a policy engine
---@param engine PolicyEngine
---@param policyName string
---@param modOptions table
---@return DSL
function DSL.new(engine, policyName, modOptions)
    local instance = setmetatable({
        engine = engine,
        policyName = policyName,
        mod_options = modOptions or {},
        predicates = {},
        category = nil,
    }, DSL)

    return instance
end

---Category to defaults mapping
local categoryDefaultsMap = {
    [SharedEnums.TransferCategory.MetalTransfer] = MetalTransferDefaults,
    [SharedEnums.TransferCategory.EnergyTransfer] = EnergyTransferDefaults,
    [SharedEnums.TransferCategory.UnitTransfer] = UnitTransferDefaults,
    [SharedEnums.TransferCategory.GuardTransfer] = GuardTransferDefaults,
    [SharedEnums.TransferCategory.RepairTransfer] = RepairTransferDefaults,
    [SharedEnums.TransferCategory.ReclaimTransfer] = ReclaimTransferDefaults,
}

---Return the defaults module for a given transfer category
---@param category TransferCategory
---@return table
local function getDefaultsForCategory(category)
    return categoryDefaultsMap[category]
end

---Register default deny handlers for all transfer categories on an engine
---@param engine PolicyEngine
function DSL.registerDefaults(engine)
    for category, defaults in pairs(categoryDefaultsMap) do
        engine:registerDefault(category, function(ctx)
            return defaults.Deny(ctx, SharedEnums.BlockReason.NoPolicy)        
        end)
    end
end

---Convert DSL predicates to engine predicate functions
---@param predicates table
---@return function[]
local function convertPredicatesToEngineFormat(predicates)
    local enginePredicates = {}
    for i, pred in ipairs(predicates) do
        enginePredicates[i] = type(pred) == "function" and pred or pred.func
    end
    return enginePredicates
end

---Reset DSL state for next rule
---@param dsl DSL
---@return DSL
local function resetDslState(dsl)
    dsl.predicates = {}
    dsl.category = nil
    return dsl
end

---@param handler fun(ctx: RegisterInitializePolicyContext)
---@return DSL
function DSL:RegisterInitialize(handler)
    self.engine:registerInitHandler(handler, self.policyName)
    return self
end

---@param validatorFn fun(ctx: ResourceTransferContext): ValidationResult
---@return DSL
function DSL:RegisterMetalValidator(validatorFn)
    self.engine:registerValidator(SharedEnums.TransferCategory.MetalTransfer, validatorFn, self.policyName)
    return self
end

---@param validatorFn fun(ctx: ResourceTransferContext): ValidationResult
---@return DSL
function DSL:RegisterEnergyValidator(validatorFn)
    self.engine:registerValidator(SharedEnums.TransferCategory.EnergyTransfer, validatorFn, self.policyName)
    return self
end

---@param validatorFn fun(ctx: UnitTransferPolicyContext): ValidationResult
---@return DSL
function DSL:RegisterUnitTransferValidator(validatorFn)
    self.engine:registerValidator(SharedEnums.TransferCategory.UnitTransfer, validatorFn, self.policyName)
    return self
end

---@param validatorFn fun(ctx: GuardTransferContext): ValidationResult
---@return DSL
function DSL:RegisterGuardValidator(validatorFn)
    self.engine:registerValidator(SharedEnums.TransferCategory.GuardTransfer, validatorFn, self.policyName)
    return self
end

---@param validatorFn fun(ctx: RepairTransferContext): ValidationResult
---@return DSL
function DSL:RegisterRepairValidator(validatorFn)
    self.engine:registerValidator(SharedEnums.TransferCategory.RepairTransfer, validatorFn, self.policyName)
    return self
end

---@param handler fun(transferResult: ResourceTransferResult, springRepo: SpringRepository)
---@return DSL
function DSL:RegisterPostMetalTransfer(handler)
    self.engine:registerPostActionHandler(SharedEnums.TransferCategory.MetalTransfer, handler, self.policyName)
    return self
end

---@param handler fun(transferResult: ResourceTransferResult, springRepo: SpringRepository)
---@return DSL
function DSL:RegisterPostEnergyTransfer(handler)
    self.engine:registerPostActionHandler(SharedEnums.TransferCategory.EnergyTransfer, handler, self.policyName)
    return self
end


---@param handler fun(ctx: PostUnitTransferContext)
---@return DSL
function DSL:RegisterPostUnitTransfer(handler)
    -- Register handler for unit transfer category
    self.engine:registerPostActionHandler(SharedEnums.TransferCategory.UnitTransfer, handler, self.policyName)
    return self
end

---@return DSL
function DSL:Allied()
    self.predicates[#self.predicates + 1] = {
        name = "Allied",
        type = "scope",
        func = function(ctx) return ctx.areAlliedTeams end
    }
    return self
end

---@return DSL
function DSL:Enemy()
    self.predicates[#self.predicates + 1] = {
        name = "Enemy",
        type = "scope", 
        func = function(ctx) return not ctx.areAlliedTeams end
    }
    return self
end

---@return DSL
function DSL:MetalTransfers() self.category = SharedEnums.TransferCategory.MetalTransfer return self end
---@return DSL
function DSL:EnergyTransfers() self.category = SharedEnums.TransferCategory.EnergyTransfer return self end
---@return DSL
function DSL:UnitTransfers() self.category = SharedEnums.TransferCategory.UnitTransfer return self end
---@return DSL
function DSL:Commands() self.category = SharedEnums.TransferCategory.CommandValidation return self end

---@return DSL
function DSL:Guard()
    self.category = SharedEnums.TransferCategory.GuardTransfer
    return self
end

---@return DSL
function DSL:Repair()
    self.category = SharedEnums.TransferCategory.RepairTransfer
    return self
end

---@return DSL
function DSL:Reclaim()
    self.category = SharedEnums.TransferCategory.ReclaimTransfer
    return self
end

---@param predicate fun(ctx: PolicyContext): boolean
---@return DSL
function DSL:When(predicate)
    self.predicates[#self.predicates + 1] = {
        name = "Custom Condition",
        type = "evaluative",
        func = predicate
    }
    return self
end

---@param handler fun(ctx: PolicyContext): table
---@return DSL
function DSL:Use(handler)
    if not self.category then error("Must specify category before Use()") end

    local category = self.category
    ---@cast category TransferCategory

    self.engine:addRule(category, {
        name = self.policyName,
        predicates = convertPredicatesToEngineFormat(self.predicates),
        predicateMetadata = self.predicates,
        handler = handler,
        dslMethod = "Use"
    })

    return resetDslState(self)
end

---@return DSL
function DSL:Allow()
    if not self.category then error("Must specify category before Allow()") end

    local category = self.category
    ---@cast category TransferCategory
    self.engine:addRule(self.category, {
        name = self.policyName,
        predicates = convertPredicatesToEngineFormat(self.predicates),
        predicateMetadata = self.predicates,
        handler = function(ctx)
            local defaults = getDefaultsForCategory(category)
            return defaults.Allow(ctx)
        end,
        denyHandler = function(ctx)
            local defaults = getDefaultsForCategory(category)
            return defaults.Deny(ctx)
        end,
        dslMethod = "Allow"
    })

    return resetDslState(self)
end

---@param reason string
---@return DSL
function DSL:Deny(reason)
    if not self.category then error("Must specify category before Deny()") end

    local category = self.category
    ---@cast category TransferCategory
    self.engine:addRule(self.category, {
        name = self.policyName,
        predicates = convertPredicatesToEngineFormat(self.predicates),
        predicateMetadata = self.predicates,
        handler = function(ctx)
            local defaults = getDefaultsForCategory(category)
            return defaults.Deny(ctx, reason)
        end,
        dslMethod = "Deny"
    })

    return resetDslState(self)
end

---Get registered validators (for testing)
---@return HandlerEntry[]
function DSL:GetValidators()
    -- Flatten all validators from all categories for backward compatibility
    local allValidators = {}
    for category, categoryValidators in pairs(self.engine.validators) do
        for _, validator in ipairs(categoryValidators) do
            table.insert(allValidators, validator)
        end
    end
    return allValidators
end

return DSL


