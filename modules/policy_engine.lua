-- Policy Engine: A simple, generic policy evaluation system

---@class HandlerEntry
---@field handler function The handler function
---@field policyName string Name of the policy that registered this handler
---@field metadata table? Additional metadata

---@class PolicyEngine
---@field categories table<string, PolicyRule[]> Map of category names to arrays of rules
---@field defaultHandlers table<string, function> Map of category names to default handler functions
---@field initHandlers HandlerEntry[] Array of initialization handlers (global)
---@field validators table<string, HandlerEntry[]> Map of category names to validation functions
---@field postActionHandlers table<string, HandlerEntry[]> Map of category names to post-action handlers
local PolicyEngine = {}
PolicyEngine.__index = PolicyEngine

---@class PredicateInfo
---@field name string Display name of the predicate
---@field type "scope"|"evaluative"|"use_block"|"action" Type of predicate for logging
---@field passed boolean Whether the predicate passed evaluation
---@field metadata table? Additional metadata for the predicate

---@class RuleEvaluation
---@field name string Rule name
---@field predicates PredicateInfo[] Array of predicate evaluation results
---@field executed boolean Whether the rule's handler was executed
---@field result table? Result of the rule execution (allow/deny/expose)

---@class EvaluationPlan
---@field category string Category being evaluated
---@field context table Evaluation context
---@field senderTeamId number? Sender team ID from context
---@field receiverTeamId number? Receiver team ID from context
---@field policyName string Policy name for logging
---@field rules RuleEvaluation[] Array of rule evaluations

---@class PolicyPlan
---@field expose table? Policy expose data
---@field allow boolean? Whether the action is allowed
---@field _evaluationPlan EvaluationPlan? Internal evaluation plan for logging

---@class PolicyRule
---@field name string Rule name
---@field predicates function[] Array of predicate functions
---@field predicateMetadata table[]? Array of metadata for each predicate
---@field handler function Rule handler function
---@field dslMethod string? DSL method used to create this rule (Allow, Deny, Use)
---@field uniqueName string? Unique name for the rule (auto-generated if multiple rules share the same base name)
---@field denyHandler function? Handler to call when Allow rule predicates fail (evaluative When)

---Create a new policy engine
---@return PolicyEngine
function PolicyEngine.new()
    return setmetatable({
        categories = {},
        defaultHandlers = {},
        initHandlers = {},
        validators = {},
        postActionHandlers = {},
        _lastEvaluationContext = nil
    }, PolicyEngine)
end

---Get the last evaluation context (for logging)
---@return PolicyContext|nil
function PolicyEngine:getLastEvaluationContext()
    return self._lastEvaluationContext
end

---Register a default handler for a category
---@param category string
---@param handler function
function PolicyEngine:registerDefault(category, handler)
    self.defaultHandlers[category] = handler
end

---Register an initialization handler
---@param handler function
---@param policyName string
---@param metadata table?
function PolicyEngine:registerInitHandler(handler, policyName, metadata)
    table.insert(self.initHandlers, {
        handler = handler,
        policyName = policyName,
        metadata = metadata
    })
end

---Register a validator for a specific category
---@param category string
---@param validator function
---@param policyName string
---@param metadata table?
function PolicyEngine:registerValidator(category, validator, policyName, metadata)
    if not self.validators[category] then
        self.validators[category] = {}
    end
    table.insert(self.validators[category], {
        handler = validator,
        policyName = policyName,
        metadata = metadata
    })
end

---Register a post-action handler for a specific category
---@param category string
---@param handler function
---@param policyName string
---@param metadata table?
function PolicyEngine:registerPostActionHandler(category, handler, policyName, metadata)
    if not self.postActionHandlers[category] then
        self.postActionHandlers[category] = {}
    end
    table.insert(self.postActionHandlers[category], {
        handler = handler,
        policyName = policyName,
        metadata = metadata
    })
end

---Add a rule to a category
---@param category string
---@param rule PolicyRule
function PolicyEngine:addRule(category, rule)
    if not self.categories[category] then
        self.categories[category] = {}
    end
    
    local ruleName = rule.name
    if rule.dslMethod then
        ruleName = rule.name .. "_" .. rule.dslMethod
    end
    
    local existingCount = 0
    for _, existingRule in ipairs(self.categories[category]) do
        local existingBaseName = existingRule.name
        if existingRule.dslMethod then
            existingBaseName = existingRule.name .. "_" .. existingRule.dslMethod
        end
        if existingBaseName == ruleName then
            existingCount = existingCount + 1
        end
    end
    
    if existingCount > 0 then
        ruleName = ruleName .. "_" .. (existingCount + 1)
    end
    
    rule.uniqueName = ruleName
    
    table.insert(self.categories[category], rule)
end

---Evaluate rules for a category
---@param category string
---@param context PolicyContext
---@return PolicyPlan result
function PolicyEngine:evaluate(category, context)
    self._lastEvaluationContext = context

    local rules = self.categories[category] or {}
    ---@type PolicyPlan
    local result = {}
    local exposeSoFar = {}

    -- Initialize evaluation plan for this category
    ---@type EvaluationPlan
    local evaluationPlan = {
        category = category,
        context = context,
        senderTeamId = context.senderTeamId,
        receiverTeamId = context.receiverTeamId,
        policyName = category,
        rules = {}
    }

    local function mergeExpose(dst, src)
        if not src then return dst end
        dst = dst or {}
        for k, v in pairs(src) do
            if type(v) == "boolean" and type(dst[k]) == "boolean" then
                dst[k] = dst[k] and v
            elseif k == "blockReason" and dst[k] == nil and v ~= nil then
                dst[k] = v
            elseif dst[k] == nil or type(dst[k]) ~= "boolean" then
                dst[k] = v
            end
        end
        return dst
    end

    for i, rule in ipairs(rules) do
        local passed = true
        local hasEvaluativePredicateFailed = false
        ---@type RuleEvaluation
        local ruleEval = {
            name = rule.name or ("Rule " .. i),
            predicates = {},
            executed = false,
            result = nil
        }

        for j, predicate in ipairs(rule.predicates or {}) do
            local predicatePassed = predicate(context)
            local predicateName = "Predicate " .. j
            local predicateType = "evaluative"
            if rule.predicateMetadata and rule.predicateMetadata[j] then
                local meta = rule.predicateMetadata[j]
                predicateName = meta.name or predicateName
                predicateType = meta.type or predicateType
            end

            ---@type PredicateInfo
            local predicateInfo = {
                name = predicateName,
                passed = predicatePassed,
                type = predicateType
            }

            table.insert(ruleEval.predicates, predicateInfo)

            if not predicatePassed then
                passed = false
                if predicateType == "evaluative" then
                    hasEvaluativePredicateFailed = true
                end
            end
        end

        if passed and rule.handler then
            context.resultSoFar = context.resultSoFar or {}
            context.resultSoFar[category] = exposeSoFar

            local ruleResult = rule.handler(context)
            ruleEval.executed = true
            ruleEval.result = ruleResult

            if ruleResult and ruleResult.deny then
                result._evaluationPlan = evaluationPlan
                return ruleResult
            end

            local exposeData = ruleResult.expose or ruleResult
            result.expose = mergeExpose(result.expose, exposeData)
            exposeSoFar = mergeExpose(exposeSoFar, exposeData)

            if ruleResult and ruleResult.allow ~= nil then
                result.allow = ruleResult.allow
            end
        elseif hasEvaluativePredicateFailed and rule.dslMethod == "Allow" and rule.denyHandler then
            context.resultSoFar = context.resultSoFar or {}
            context.resultSoFar[category] = exposeSoFar

            local denyResult = rule.denyHandler(context)
            ruleEval.executed = true
            ruleEval.result = denyResult

            local exposeData = denyResult.expose or denyResult
            result.expose = mergeExpose(result.expose, exposeData)
            exposeSoFar = mergeExpose(exposeSoFar, exposeData)
        end

        table.insert(evaluationPlan.rules, ruleEval)
    end

    -- Apply default if no rules provided expose data
    if not result.expose and self.defaultHandlers[category] then
        result.expose = self.defaultHandlers[category](context)
    end

    -- Attach the evaluation plan to the result
    result._evaluationPlan = evaluationPlan

    return result
end

---Validate a single item using category validators and a context builder
---@param category string The transfer category
---@param item any Item to validate
---@param contextBuilder fun(item: any): table Function that builds validation context for the item
---@return table[] Array of validation results
function PolicyEngine:validateItem(category, item, contextBuilder)
    local categoryValidators = self.validators[category] or {}
    local ctx = contextBuilder(item)
    return table.map(categoryValidators, function(validator)
        return validator.handler(ctx)
    end)
end

---Validate items using category validators and a context builder closure
---@param category string The transfer category
---@param items any[] Array of items to validate
---@param contextBuilder fun(item: any): table Function that builds validation context for each item
---@return table[] Flattened array of validation results
function PolicyEngine:validateItems(category, items, contextBuilder)
    local categoryValidators = self.validators[category] or {}
    return table.flatmap(items, function(item)
        local ctx = contextBuilder(item)
        return table.map(categoryValidators, function(validator)
            return validator.handler(ctx)
        end)
    end)
end

return PolicyEngine
