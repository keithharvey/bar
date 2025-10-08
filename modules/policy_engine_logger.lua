-- Policy Engine Logger - Comprehensive logging for policy execution and rule evaluation

---@load-file luaui/types/team_transfer.lua

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Local log function for consistent logging
local function log(tag, message)
    Spring.Log(tag, _G.CURRENT_LOG_LEVEL or LOG.INFO, message)
end

---@class PolicyEngineLogger
---Intelligent logging for policy execution plans and topology
local PolicyEngineLogger = {}

-- Logger-specific type definitions (uses types from luaui/types/team_transfer.lua)

---@class RuleEvaluationResult
---@field name string
---@field predicates PredicateInfo[]?
---@field result RuleResult?
---@field executed boolean?

---@class PredicateInfo
---@field name string
---@field type "scope"|"evaluative"|"use_block"|"action"
---@field passed boolean?
---@field metadata table?

---@class RuleResult
---@field allow boolean?
---@field deny boolean?
---@field expose table?
---@field reason string?

---@class ValidatorEntry
---@field policyName string?

---@class TransferHookEntry
---@field policyName string?

---@class InitializerEntry
---@field policyName string?

---@class PolicyInfo
---@field name string
---@field executed boolean?

---Create a new logger instance
---@return PolicyEngineLogger
function PolicyEngineLogger.new()
    local instance = setmetatable({}, {__index = PolicyEngineLogger})
    return instance
end

---Log a complete pipeline evaluation with results and execution plan
---@param result CombinedPolicyResult Combined policy result
---@param plan table|nil Pipeline execution plan (optional) -- TODO: Define proper PipelineExecutionPlan type
function PolicyEngineLogger:LogPlan(result, plan)
    if not result then
        log("PIPELINE PLAN", "No result to log.")
        return
    end


    log("PIPELINE PLAN", "=== PIPELINE PLAN ===")
    log("PIPELINE PLAN", "")
    
    
    
    -- Section 1: Context (from plan if available)
    if plan then
        PolicyEngineLogger.LogContext(plan)
    end
    
    -- Section 2: Validators
    if plan and plan.validators then
        PolicyEngineLogger.LogValidators(plan.validators)
    end

    -- Section 3: Transfer Hooks
    if plan and plan.transferHooks then
        PolicyEngineLogger.LogTransferHooks(plan.transferHooks)
    end

    -- Section 4: Initializers
    if plan and plan.initializers then
        PolicyEngineLogger.LogInitializers(plan.initializers)
    end

    -- Section 5: Policy Rule Topology
    if plan and plan.categories then
        log("PIPELINE PLAN", "[POLICY RULE TOPOLOGY]")
        for category, categoryPlan in pairs(plan.categories) do
            -- Always show category header, even if no rules
            ---@type string
            local dslCategoryName
            if category == "unit_transfer" then dslCategoryName = "UnitTransfers"
            elseif category == "metal_transfer" then dslCategoryName = "MetalTransfers"
            elseif category == "energy_transfer" then dslCategoryName = "EnergyTransfers"
            elseif category == "command_validation" then dslCategoryName = "Commands"
            elseif category == "guard_transfer" then dslCategoryName = "GuardCommands"
            elseif category == "repair_transfer" then dslCategoryName = "RepairCommands"
            elseif category == "reclaim_transfer" then dslCategoryName = "ReclaimCommands"
            else dslCategoryName = category
            end

            if categoryPlan and categoryPlan.rules and #categoryPlan.rules > 0 then
                PolicyEngineLogger.LogImprovedDSLTopology(categoryPlan.rules, result, category)
            else
                -- No rules for this category at all - log category name and default behavior
                log("PIPELINE PLAN", dslCategoryName)
                local contextType = plan.context and plan.context.areAlliedTeams and "Allied" or "Enemy"
                log("PIPELINE PLAN", string.format("  ✗ %s", contextType))
                log("PIPELINE PLAN", "    → default: Denied (No policy enabled)")
            end

            -- Show what happens for the opposite context (enemy vs allied)
            local currentContextAllied = plan.context and plan.context.areAlliedTeams
            local oppositeContextType = currentContextAllied and "Enemy" or "Allied"
            local hasOppositeRules = false

            if categoryPlan and categoryPlan.rules and #categoryPlan.rules > 0 then
                for _, rule in ipairs(categoryPlan.rules) do
                    if rule.predicates and #rule.predicates > 0 then
                        -- Check if this rule would apply to the opposite context
                        local ruleAppliesToAllied = (rule.name == "assist_ally" or rule.name == "allied_reclaim" or rule.name == "tax_resource_sharing" or rule.name == "unit_sharing_mode")
                        local ruleAppliesToEnemy = false -- No policies apply to enemy context by default

                        if (not currentContextAllied and ruleAppliesToAllied) or (currentContextAllied and ruleAppliesToEnemy) then
                            hasOppositeRules = true
                            break
                        end
                    end
                end
            end

            -- If no rules apply to opposite context, show default
            if not hasOppositeRules then
                log("PIPELINE PLAN", string.format("  ✗ %s", oppositeContextType))
                log("PIPELINE PLAN", "    → default: Denied (No policy enabled)")
            end

            log("PIPELINE PLAN", "")
        end
        log("PIPELINE PLAN", "")
    end

    log("PIPELINE PLAN", "=== END PLAN ===")
end

---Log context information
---@param plan PipelineExecutionPlan Pipeline execution plan
function PolicyEngineLogger.LogContext(plan)
    log("PIPELINE PLAN", "[CONTEXT]")
    local ctx = plan.context or {}
    local senderName = ctx.senderName or ("Team " .. tostring(ctx.senderTeamId or -1))
    local receiverName = ctx.receiverName or ("Team " .. tostring(ctx.receiverTeamId or -1))
    log("PIPELINE PLAN", string.format("Sender: %s (ID: %d)", senderName, ctx.senderTeamId or -1))
    log("PIPELINE PLAN", string.format("Receiver: %s (ID: %d)", receiverName, ctx.receiverTeamId or -1))

    -- Use cached evaluation context for resource information
    -- This automatically provides all context data without policies having to include it
    local cachedContext = plan.engine and plan.engine:getLastEvaluationContext()
    if cachedContext then
        local senderResources = cachedContext.sender
        local receiverResources = cachedContext.receiver

        if senderResources and receiverResources then
            log("PIPELINE PLAN", string.format("Sender Resources: M:%d E:%d",
                senderResources.metal and senderResources.metal.current or 0,
                senderResources.energy and senderResources.energy.current or 0))
            log("PIPELINE PLAN", string.format("Receiver Resources: M:%d E:%d",
                receiverResources.metal and receiverResources.metal.current or 0,
                receiverResources.energy and receiverResources.energy.current or 0))
        end

        -- Log alliance and cheating status from cached context
        local areAlliedTeams = cachedContext.areAlliedTeams
        local isCheatingEnabled = cachedContext.isCheatingEnabled
        log("PIPELINE PLAN", string.format("Allied: %s | Cheating: %s", areAlliedTeams and "Yes" or "No", isCheatingEnabled and "Yes" or "No"))
    else
        -- Fallback to plan context if no cached context available
        local areAlliedTeams = ctx.areAlliedTeams
        local isCheatingEnabled = ctx.isCheatingEnabled
        log("PIPELINE PLAN", string.format("Allied: %s | Cheating: %s", areAlliedTeams and "Yes" or "No", isCheatingEnabled and "Yes" or "No"))
    end

    log("PIPELINE PLAN", "")
end

---Log rule topology in hierarchical format (preserved from original)
---@param rules RuleEvaluationResult[] Array of rule evaluation results
function PolicyEngineLogger.LogRuleTopology(rules)
    if not rules or #rules == 0 then
        log("PIPELINE PLAN", "  No rules defined")
        return
    end
    
    -- Build topology tree from rules
    local topology = {}
    for _, rule in ipairs(rules) do
        local predicates = rule.predicates or {}
        local path = {}
        
        -- Extract scope and evaluative conditions to build path
        for _, pred in ipairs(predicates) do
            if pred.type == "scope" or pred.type == "evaluative" then
                table.insert(path, pred.name)
            elseif pred.type == "action" then
                -- Add action with outcome
                local action = pred.name
                if rule.result then
                    if rule.result.allow then
                        action = action .. " → ALLOW"
                    elseif rule.result.deny then
                        action = action .. " → DENY"
                    elseif rule.result.expose then
                        action = action .. " → EXPOSE"
                    end
                end
                table.insert(path, action)
            end
        end
        
        -- If no typed predicates, use rule name and outcome
        if #path == 0 then
            local action = rule.name or "Unknown Rule"
            if rule.result then
                if rule.result.allow then
                    action = action .. " → ALLOW"
                elseif rule.result.deny then
                    action = action .. " → DENY"
                elseif rule.result.expose then
                    action = action .. " → EXPOSE"
                end
            end
            table.insert(path, action)
        end
        
        -- Build nested structure
        local current = topology
        for i, segment in ipairs(path) do
            if i == #path then
                -- Leaf node
                table.insert(current, segment)
            else
                -- Find or create branch
                local found = false
                for _, branch in ipairs(current) do
                    if type(branch) == "table" and branch.name == segment then
                        current = branch.children
                        found = true
                        break
                    end
                end
                if not found then
                    local newBranch = {name = segment, children = {}}
                    table.insert(current, newBranch)
                    current = newBranch.children
                end
            end
        end
    end
    
    -- Print topology
    local function printTopology(items, indent)
        for _, item in ipairs(items) do
            if type(item) == "string" then
                log("PIPELINE PLAN", indent .. item)
            elseif type(item) == "table" then
                log("PIPELINE PLAN", indent .. item.name)
                printTopology(item.children, indent .. "   ")
            end
        end
    end
    
    printTopology(topology, "")
end

---Log DSL topology showing the policy structure with outcomes
---@param rules RuleEvaluationResult[] Array of rule evaluation results
---@param result CombinedPolicyResult Pipeline result for outcome details
---@param category TransferCategory Transfer category
function PolicyEngineLogger.LogDSLTopology(rules, result, category)
    if not rules or #rules == 0 then
        log("PIPELINE PLAN", "  No rules defined")
        return
    end
    
    -- Build DSL-style topology
    local topology = {}
    
    for _, rule in ipairs(rules) do
        local predicates = rule.predicates or {}
        local current = topology
        
        -- Group by scope predicates first
        for _, pred in ipairs(predicates) do
            if pred.type == "scope" then
                local found = false
                for _, node in ipairs(current) do
                    if type(node) == "table" and node.name == pred.name then
                        current = node.children
                        found = true
                        break
                    end
                end
                if not found then
                    local newNode = {name = pred.name, children = {}, type = "scope"}
                    table.insert(current, newNode)
                    current = newNode.children
                end
            end
        end
        
        -- Add category node
        local categoryNode = nil
        for _, node in ipairs(current) do
            if type(node) == "table" and node.name == category then
                categoryNode = node
                break
            end
        end
        if not categoryNode then
            categoryNode = {name = category, children = {}, type = "category"}
            table.insert(current, categoryNode)
        end
        
        -- Add action with outcome and summary
        local actionName = "Allow()"
        local summary = ""
        
        if rule.result and rule.result.deny then
            actionName = "Deny()"
            summary = rule.result.reason or "Policy denied"
        elseif rule.result and rule.result.expose then
            actionName = "Allow()"
            -- Create summary from result
            if category == "unit_transfer" and result.unit_transfer then
                local ut = result.unit_transfer
                if ut.canShareUnits then
                    summary = string.format("Unit sharing enabled (mode: %s)", ut.sharingMode or "enabled")
                else
                    summary = ut.blockReason or "Unit sharing disabled"
                end
            elseif category == "metal_transfer" and result.metal_transfer then
                local mt = result.metal_transfer
                if mt.canShare then
                    summary = string.format("Metal sharing allowed (max: %d)", mt.maxMetalShareAmount or 0)
                else
                    summary = mt.blockReason or "Metal sharing denied"
                end
            elseif category == "energy_transfer" and result.energy_transfer then
                local et = result.energy_transfer
                if et.canShare then
                    summary = string.format("Energy sharing allowed (max: %d)", et.maxEnergyShareAmount or 0)
                else
                    summary = et.blockReason or "Energy sharing denied"
                end
            end
        end
        
        local actionWithSummary = actionName
        if summary ~= "" then
            actionWithSummary = actionWithSummary .. " → " .. summary
        end
        
        table.insert(categoryNode.children, actionWithSummary)
    end
    
    -- Print DSL topology
    local function printDSLTopology(items, indent)
        for _, item in ipairs(items) do
            if type(item) == "string" then
                log("PIPELINE PLAN", indent .. item)
            elseif type(item) == "table" then
                log("PIPELINE PLAN", indent .. item.name)
                if item.children and #item.children > 0 then
                    printDSLTopology(item.children, indent .. "  ")
                end
            end
        end
    end
    
    printDSLTopology(topology, "")
end

---Log improved DSL topology that correctly shows Use blocks and implicit denies
---@param rules RuleEvaluationResult[] Array of rule evaluation results
---@param result CombinedPolicyResult Pipeline result for outcome details
---@param category TransferCategory Transfer category
function PolicyEngineLogger.LogImprovedDSLTopology(rules, result, category)
    if not rules or #rules == 0 then
        log("PIPELINE PLAN", "  No rules defined")
        return
    end
    
    -- Convert category to DSL name
    ---@type string
    local dslCategoryName
    if category == "unit_transfer" then dslCategoryName = "UnitTransfers"
    elseif category == "metal_transfer" then dslCategoryName = "MetalTransfers"
    elseif category == "energy_transfer" then dslCategoryName = "EnergyTransfers"
    elseif category == "command_validation" then dslCategoryName = "Commands"
    elseif category == "guard_transfer" then dslCategoryName = "GuardCommands"
    elseif category == "repair_transfer" then dslCategoryName = "RepairCommands"
    elseif category == "reclaim_transfer" then dslCategoryName = "ReclaimCommands"
    else dslCategoryName = category
    end
    
    log("PIPELINE PLAN", dslCategoryName)

    -- Deduplicate rules by policy name and outcome to avoid repetition
    local shownRules = {}

    for _, rule in ipairs(rules) do
        local policyName = rule.name or "Unknown Policy"

        -- Determine the outcome text
        local outcomeText
        if rule.result then
            outcomeText = PolicyEngineLogger.GetOutcomeSummary(category, rule.result)
        elseif rule.predicates and #rule.predicates > 0 then
            -- Rule didn't execute due to failed predicates
            outcomeText = "Skipped (predicates failed)"
        else
            outcomeText = "Not executed"
        end

        -- Create a unique key for this rule
        local ruleKey = string.format("%s:%s", policyName, outcomeText)

        -- Only show each unique rule once
        if not shownRules[ruleKey] then
            shownRules[ruleKey] = true

            -- Show all predicates with pass/fail status
            if rule.predicates then
                for _, pred in ipairs(rule.predicates) do
                    local status = pred.passed and "✓" or "✗"
                    local predName = pred.name or tostring(pred)
                    log("PIPELINE PLAN", string.format("  %s %s", status, predName))
                end
            end

            -- Show outcome with policy name
            log("PIPELINE PLAN", string.format("    → %s: %s", policyName, outcomeText))
        end
    end
end

---Get brief outcome reference for topology section
---@param categoryName TransferCategory Category name
---@param ruleResult RuleResult|nil Rule execution result
---@return string Brief outcome reference
function PolicyEngineLogger.GetBriefOutcome(categoryName, ruleResult)
    if not ruleResult then return "No outcome" end

    local expose = ruleResult.expose or ruleResult

    if ruleResult.deny or expose.deny then
        return "Denied"
    elseif expose then
        if categoryName == "unit_transfer" then
            return expose.canShareUnits and "Allowed" or "Denied"
        elseif categoryName == "metal_transfer" then
            return expose.canShare and "Allowed" or "Denied"
        elseif categoryName == "energy_transfer" then
            return expose.canShare and "Allowed" or "Denied"
        elseif categoryName == "command_validation" or categoryName == "guard_transfer" or categoryName == "repair_transfer" or categoryName == "reclaim_transfer" then
            local hasAnyAllowed = expose.allowGuardCommands or expose.allowRepairCommands or expose.allowReclaimCommands
            return hasAnyAllowed and "Allowed" or "Denied"
        end
    end

    return "Unknown"
end

---Get outcome summary for a rule result
---@param categoryName TransferCategory Category name
---@param ruleResult RuleResult|nil Rule execution result
---@return string Outcome summary
function PolicyEngineLogger.GetOutcomeSummary(categoryName, ruleResult)
    if not ruleResult then return "No outcome" end

    -- Handle both {expose = {...}} and direct expose formats
    local expose = ruleResult.expose or ruleResult

    if ruleResult.deny or expose.deny then
        return string.format("%s: Denied (%s)",
            PolicyEngineLogger.GetCategoryDisplayName(categoryName),
            ruleResult.reason or expose.reason or "Policy denied")
    elseif expose then
        if categoryName == "unit_transfer" then
            if expose.canShareUnits == false then
                return "Denied (No unit sharing policies allow this)"
            elseif expose.sharingMode then
                return string.format("Allowed (mode: %s)", expose.sharingMode)
            else
                return "Allowed"
            end
        elseif categoryName == "metal_transfer" then
            if not expose.canShare then
                return string.format("Denied (%s)", expose.blockReason or "No sharing allowed")
            end
            -- Show detailed tax information
            local details = {}
            if expose.amountSendable then
                table.insert(details, string.format("max sendable: %d", expose.amountSendable))
            elseif expose.maxMetalShareAmount then
                table.insert(details, string.format("max share: %d", expose.maxMetalShareAmount))
            end
            if expose.taxRate and expose.taxRate > 0 then
                table.insert(details, string.format("tax: %.1f%%", expose.taxRate * 100))
            end
            if expose.remainingTaxFreeAllowance and expose.remainingTaxFreeAllowance > 0 then
                table.insert(details, string.format("tax-free allowance: %d", expose.remainingTaxFreeAllowance))
            end
            local detailStr = #details > 0 and (" (" .. table.concat(details, ", ") .. ")") or ""
            return string.format("Allowed%s", detailStr)
        elseif categoryName == "energy_transfer" then
            if not expose.canShare then
                return string.format("Denied (%s)", expose.blockReason or "No sharing allowed")
            end
            -- Show detailed tax information
            local details = {}
            if expose.amountSendable then
                table.insert(details, string.format("max sendable: %d", expose.amountSendable))
            elseif expose.maxEnergyShareAmount then
                table.insert(details, string.format("max share: %d", expose.maxEnergyShareAmount))
            end
            if expose.taxRate and expose.taxRate > 0 then
                table.insert(details, string.format("tax: %.1f%%", expose.taxRate * 100))
            end
            if expose.remainingTaxFreeAllowance and expose.remainingTaxFreeAllowance > 0 then
                table.insert(details, string.format("tax-free allowance: %d", expose.remainingTaxFreeAllowance))
            end
            local detailStr = #details > 0 and (" (" .. table.concat(details, ", ") .. ")") or ""
            return string.format("Allowed%s", detailStr)
        elseif categoryName == "guard_transfer" or categoryName == "repair_transfer" or categoryName == "reclaim_transfer" then
            if expose.allowCommands then
                if categoryName == "guard_transfer" then return "Guard commands allowed"
                elseif categoryName == "repair_transfer" then return "Repair commands allowed"
                elseif categoryName == "reclaim_transfer" then return "Reclaim commands allowed"
                end
            else
                if categoryName == "guard_transfer" then return "Guard commands denied"
                elseif categoryName == "repair_transfer" then return "Repair commands denied"
                elseif categoryName == "reclaim_transfer" then return "Reclaim commands denied"
                end
            end
        end
    end

    return "Unknown outcome"
end

---Get display name for a category
---@param categoryName TransferCategory Category name
---@return string Display name
function PolicyEngineLogger.GetCategoryDisplayName(categoryName)
    if categoryName == "unit_transfer" then return "Unit Transfer"
    elseif categoryName == "metal_transfer" then return "Metal Transfer"
    elseif categoryName == "energy_transfer" then return "Energy Transfer"
    elseif categoryName == "guard_transfer" then return "Guard Commands"
    elseif categoryName == "repair_transfer" then return "Repair Commands"
    elseif categoryName == "reclaim_transfer" then return "Reclaim Commands"
    end
    return tostring(categoryName)
end

---Log outcomes section showing both policy-driven and default outcomes
---@param result CombinedPolicyResult Combined policy result
---@param plan table|nil Pipeline execution plan -- TODO: Define proper type
function PolicyEngineLogger.LogOutcomes(result, plan)
    local outcomeIndex = 1

    -- Show policy-driven outcomes first
    if plan and plan.categories then
        for category, categoryPlan in pairs(plan.categories) do
            if categoryPlan and categoryPlan.rules then
                for _, rule in ipairs(categoryPlan.rules) do
                    local summary = PolicyEngineLogger.GetOutcomeSummary(category, rule.result)
                    log("PIPELINE PLAN", string.format("(%d) %s", outcomeIndex, summary))
                    outcomeIndex = outcomeIndex + 1
                end
            end
        end
    end

    -- Show default outcomes for categories without policies
    local allCategories = {"metal_transfer", "energy_transfer", "unit_transfer", "guard_transfer", "repair_transfer", "reclaim_transfer"}
    for _, category in ipairs(allCategories) do
        local hasPolicy = plan and plan.categories and plan.categories[category] and
                         plan.categories[category].rules and
                         #plan.categories[category].rules > 0
        if not hasPolicy then
            local summary = PolicyEngineLogger.GetDefaultOutcomeSummary(category, result)
            log("PIPELINE PLAN", string.format("(%d) [DEFAULT] %s", outcomeIndex, summary))
            outcomeIndex = outcomeIndex + 1
        end
    end
end

---Get default outcome summary for categories without policies
---@param categoryName TransferCategory Category name
---@param result CombinedPolicyResult Combined policy result
---@return string Default outcome summary
function PolicyEngineLogger.GetDefaultOutcomeSummary(categoryName, result)
    if categoryName == "guard_transfer" then
        return "Guard Commands: Denied (No policies allowed guard commands)"
    elseif categoryName == "repair_transfer" then
        return "Repair Commands: Denied (No policies allowed repair commands)"
    elseif categoryName == "reclaim_transfer" then
        return "Reclaim Commands: Denied (No policies allowed reclaim commands)"
    elseif categoryName == "metal_transfer" then
        return "Metal Transfer: Denied (No policies allowed metal sharing)"
    elseif categoryName == "energy_transfer" then
        return "Energy Transfer: Denied (No policies allowed energy sharing)"
    elseif categoryName == "unit_transfer" then
        return "Unit Transfer: Denied (No policies allowed unit sharing)"
    end
    return "Unknown default outcome"
end

---Format expose result for display
---@param categoryName TransferCategory Category name
---@param expose ResourcePolicyResult|UnitTransferPolicyResult|CommandTransferPolicyResult Expose data
---@return string Formatted result
function PolicyEngineLogger.FormatExposeResult(categoryName, expose)
    local parts = {}

    if categoryName == "unit_transfer" then
        table.insert(parts, string.format("canShareUnits: %s", tostring(expose.canShareUnits)))
        if expose.blockReason then
            table.insert(parts, string.format("blockReason: \"%s\"", expose.blockReason))
        end
    elseif categoryName == "metal_transfer" then
        table.insert(parts, string.format("canShare: %s", tostring(expose.canShare)))
        -- Use amountSendable if available (from tax_resource_sharing), otherwise fallback to maxMetalShareAmount
        local maxAmount = expose.amountSendable or expose.maxMetalShareAmount or 0
        table.insert(parts, string.format("maxAmount: %d", maxAmount))
        if expose.taxRate then
            table.insert(parts, string.format("taxRate: %.2f", expose.taxRate))
        end
        if expose.blockReason then
            table.insert(parts, string.format("blockReason: \"%s\"", expose.blockReason))
        end
    elseif categoryName == "energy_transfer" then
        table.insert(parts, string.format("canShare: %s", tostring(expose.canShare)))
        -- Use amountSendable if available (from tax_resource_sharing), otherwise fallback to maxEnergyShareAmount
        local maxAmount = expose.amountSendable or expose.maxEnergyShareAmount or 0
        table.insert(parts, string.format("maxAmount: %d", maxAmount))
        if expose.taxRate then
            table.insert(parts, string.format("taxRate: %.2f", expose.taxRate))
        end
        if expose.blockReason then
            table.insert(parts, string.format("blockReason: \"%s\"", expose.blockReason))
        end
    elseif categoryName == "command_validation" then
        local commands = {}
        if expose.allowGuardCommands then table.insert(commands, "guard") end
        if expose.allowRepairCommands then table.insert(commands, "repair") end
        if expose.allowReclaimCommands then table.insert(commands, "reclaim") end
        table.insert(parts, string.format("allowed: [%s]", table.concat(commands, ", ")))
        if expose.blockReason then
            table.insert(parts, string.format("blockReason: \"%s\"", expose.blockReason))
        end
    end

    return "{ " .. table.concat(parts, ", ") .. " }"
end

---Check if an expose result represents an implicit deny
---@param categoryName TransferCategory Category name
---@param expose ResourcePolicyResult|UnitTransferPolicyResult|CommandTransferPolicyResult Expose data
---@return boolean True if this is an implicit deny
function PolicyEngineLogger.IsImplicitDeny(categoryName, expose)
    if categoryName == "unit_transfer" then
        return not expose.canShareUnits
    elseif categoryName == "metal_transfer" then
        return not expose.canShare
    elseif categoryName == "energy_transfer" then
        return not expose.canShare
    elseif categoryName == "command_validation" then
        return not (expose.allowGuardCommands or expose.allowRepairCommands or expose.allowReclaimCommands)
    end
    return false
end

---Log expose data summary (updated for new result structure)
---@param result CombinedPolicyResult Combined policy result
function PolicyEngineLogger.LogExposeDataSummary(result)
    if not result then return end

    -- Command Transfers (Guard, Repair, Reclaim)
    local commandAllowed = {}
    if result.guard_transfer and result.guard_transfer.allowCommands then
        table.insert(commandAllowed, "Guard")
    end
    if result.repair_transfer and result.repair_transfer.allowCommands then
        table.insert(commandAllowed, "Repair")
    end
    if result.reclaim_transfer and result.reclaim_transfer.allowCommands then
        table.insert(commandAllowed, "Reclaim")
    end

    if #commandAllowed > 0 then
        log("PIPELINE PLAN", string.format("Commands: %s allowed", table.concat(commandAllowed, ", ")))
    else
        log("PIPELINE PLAN", "Commands: None allowed")
    end

    -- Metal Transfer
    if result.metal_transfer then
        local mt = result.metal_transfer
        if mt.canShare then
            -- Use amountSendable if available (from tax_resource_sharing), otherwise fallback to maxMetalShareAmount
            local maxAmount = mt.amountSendable or mt.maxMetalShareAmount
            log("PIPELINE PLAN", string.format("Metal Transfer: Allowed%s",
                maxAmount and (" (max: " .. maxAmount .. ")") or ""))
        else
            log("PIPELINE PLAN", string.format("Metal Transfer: Denied%s",
                mt.blockReason and (" (" .. mt.blockReason .. ")") or ""))
        end
    end

    -- Energy Transfer
    if result.energy_transfer then
        local et = result.energy_transfer
        if et.canShare then
            -- Use amountSendable if available (from tax_resource_sharing), otherwise fallback to maxEnergyShareAmount
            local maxAmount = et.amountSendable or et.maxEnergyShareAmount
            log("PIPELINE PLAN", string.format("Energy Transfer: Allowed%s",
                maxAmount and (" (max: " .. maxAmount .. ")") or ""))
        else
            log("PIPELINE PLAN", string.format("Energy Transfer: Denied%s",
                et.blockReason and (" (" .. et.blockReason .. ")") or ""))
        end
    end

    -- Unit Transfer
    if result.unit_transfer then
        local ut = result.unit_transfer
        if ut.canShareUnits then
            log("PIPELINE PLAN", "Unit Transfer: Allowed")
        else
            log("PIPELINE PLAN", string.format("Unit Transfer: Denied%s",
                ut.blockReason and (" (" .. ut.blockReason .. ")") or ""))
        end
    end
end


---Log validators section
---@param validators ValidatorEntry[] List of validator functions
function PolicyEngineLogger.LogValidators(validators)
    log("PIPELINE PLAN", "[VALIDATORS]")
    
    if not validators or #validators == 0 then
        log("PIPELINE PLAN", "  No validators registered")
        return
    end
    
    log("PIPELINE PLAN", string.format("  %d validator(s) registered:", #validators))
    -- Create a set to track unique policy names
    local policyNames = {}
    for i, validatorEntry in ipairs(validators) do
        local policyName = validatorEntry.policyName or "Unknown Policy"
        policyNames[policyName] = true
    end
    local i = 1
    for policyName, _ in pairs(policyNames) do
        log("PIPELINE PLAN", string.format("    %d. %s", i, policyName))
        i = i + 1
    end
    log("PIPELINE PLAN", "")
end

---Log transfer hooks section
---@param transferHooks TransferHookEntry[] List of post-transfer hook functions
function PolicyEngineLogger.LogTransferHooks(transferHooks)
    log("PIPELINE PLAN", "[TRANSFER HOOKS]")
    
    if not transferHooks or #transferHooks == 0 then
        log("PIPELINE PLAN", "  No transfer hooks registered")
        return
    end
    
    log("PIPELINE PLAN", string.format("  %d transfer hook(s) registered:", #transferHooks))
    -- Create a set to track unique policy names
    local policyNames = {}
    for i, hookEntry in ipairs(transferHooks) do
        local policyName = hookEntry.policyName or "Unknown Policy"
        policyNames[policyName] = true
    end
    local i = 1
    for policyName, _ in pairs(policyNames) do
        log("PIPELINE PLAN", string.format("    %d. %s", i, policyName))
        i = i + 1
    end
    log("PIPELINE PLAN", "")
end

---Log initializers section
---@param initializers InitializerEntry[] List of initialization functions
function PolicyEngineLogger.LogInitializers(initializers)
    log("PIPELINE PLAN", "[INITIALIZERS]")
    
    if not initializers or #initializers == 0 then
        log("PIPELINE PLAN", "  No initializers registered")
        return
    end
    
    log("PIPELINE PLAN", string.format("  %d initializer(s) registered:", #initializers))
    -- Create a set to track unique policy names
    local policyNames = {}
    for i, initializerEntry in ipairs(initializers) do
        local policyName = initializerEntry.policyName or "Unknown Policy"
        policyNames[policyName] = true
    end
    local i = 1
    for policyName, _ in pairs(policyNames) do
        log("PIPELINE PLAN", string.format("    %d. %s", i, policyName))
        i = i + 1
    end
    log("PIPELINE PLAN", "")
end

---Log individual sections for granular analysis
---@param section string Section name
---@param data table Section data
function PolicyEngineLogger.LogSection(section, data)
    log("PIPELINE PLAN", string.format("=== %s ===", section:upper()))
    
    if section == "context" then
        PolicyEngineLogger.LogContext({context = data})
    elseif section == "rules" then
        -- Log rules - implementation depends on data structure
        if data.rules then
            PolicyEngineLogger.LogRuleTopology(data.rules)
        end
    elseif section == "topology" then
        PolicyEngineLogger.LogRuleTopology(data.rules or {})
    elseif section == "results" then
        PolicyEngineLogger.LogExposeDataSummary(data)
    end
    
    log("PIPELINE PLAN", string.format("=== END %s ===", section:upper()))
end

-- Legacy compatibility functions (simplified)
---@param plan table Legacy plan structure
function PolicyEngineLogger.LogExecutionPlan(plan)
    PolicyEngineLogger.LogPlan(plan.result, plan)
end

---@param policies PolicyInfo[]
function PolicyEngineLogger.LogPolicyTopology(policies)
    log("PIPELINE PLAN", "=== ACTIVE POLICIES ===")
    for i, policy in ipairs(policies or {}) do
        local status = policy.executed and "ACTIVE" or "INACTIVE"
        log("PIPELINE PLAN", string.format("%d. %s [%s]", i, policy.name or ("Policy " .. i), status))
    end
    log("PIPELINE PLAN", "=== END POLICIES ===")
end

---@param result CombinedPolicyResult
function PolicyEngineLogger.LogFinalResult(result)
    PolicyEngineLogger.LogExposeDataSummary(result)
end

-- Create PolicyLogger alias for convenience
---@deprecated Use PolicyEngineLogger instead
_G.PolicyLogger = PolicyEngineLogger

return PolicyEngineLogger