-- Pipeline plan logger - accepts a plan table and logs a readable summary

---@class PipelineLogger
---Intelligent logging for policy execution plans and topology
local PipelineLogger = {}

---Log a clear demonstration of the pipeline's plan
---@param plan table
---@param result table|nil Combined expose result (optional)
function PipelineLogger.LogPlan(plan, result)
    if not plan or type(plan) ~= "table" then
        Spring.Log("PIPELINE PLAN", "info", "No plan to log.")
        return
    end
    
    Spring.Log("PIPELINE PLAN", "info", "=== PIPELINE PLAN ===")
    Spring.Log("PIPELINE PLAN", "info", "")
    
    -- Section 1: Context
    Spring.Log("PIPELINE PLAN", "info", "[CONTEXT]")
    local ctx = plan.context or {}
    local senderName = ctx.senderName or ("Team " .. tostring(plan.senderTeamId))
    local receiverName = ctx.receiverName or ("Team " .. tostring(plan.receiverTeamId))
    Spring.Log("PIPELINE PLAN", "info", string.format("Sender: %s (ID: %d)", senderName, plan.senderTeamId or -1))
    Spring.Log("PIPELINE PLAN", "info", string.format("Receiver: %s (ID: %d)", receiverName, plan.receiverTeamId or -1))
    
    -- Tight resource summary
    if ctx.resources then
        local resources = ctx.resources
        -- Handle different resource data structures
        if type(resources.sender) == "number" then
            -- Simple number format
            Spring.Log("PIPELINE PLAN", "info", string.format("Resources: sender=%d receiver=%d", 
                resources.sender or 0,
                resources.receiver or 0))
        elseif type(resources.sender) == "table" then
            -- Detailed format
            local sr = resources.sender or {}
            local rr = resources.receiver or {}
            if sr.metal or sr.energy then
                Spring.Log("PIPELINE PLAN", "info", string.format("Sender Resources: M:%d/%d E:%d/%d", 
                    sr.metal and sr.metal.current or 0,
                    sr.metal and sr.metal.storage or 0,
                    sr.energy and sr.energy.current or 0,
                    sr.energy and sr.energy.storage or 0))
            end
            if rr.metal or rr.energy then
                Spring.Log("PIPELINE PLAN", "info", string.format("Receiver Resources: M:%d/%d E:%d/%d", 
                    rr.metal and rr.metal.current or 0,
                    rr.metal and rr.metal.storage or 0,
                    rr.energy and rr.energy.current or 0,
                    rr.energy and rr.energy.storage or 0))
            end
        end
    end
    Spring.Log("PIPELINE PLAN", "info", string.format("Allied: %s | Cheating: %s", 
        ctx.areAlliedTeams and "Yes" or "No",
        ctx.isCheatingEnabled and "Yes" or "No"))
    Spring.Log("PIPELINE PLAN", "info", "")
    
    -- Section 2: Policies
    -- For now, determine policy name from context (this should come from the plan)
    local policyName = "Unknown Policy"
    if plan.activePolicies and #plan.activePolicies > 0 then
        policyName = table.concat(plan.activePolicies, ", ")
    else
        -- Try to infer from the rules
        for _, rule in ipairs(plan.rules or {}) do
            if rule.name and rule.name:find("bothStorages") then
                policyName = "building_unlocks_sharing"
                break
            end
        end
        if policyName == "Unknown Policy" then
            policyName = plan.policyType or "Unknown Policy"
        end
    end
    
    Spring.Log("PIPELINE PLAN", "info", "[POLICIES]")
    Spring.Log("PIPELINE PLAN", "info", string.format("Policy Name: %s", policyName))
    
    local rules = plan.rules or {}
    Spring.Log("PIPELINE PLAN", "info", string.format("Active Rules: (%d)", #rules))
    for i = 1, #rules do
        local r = rules[i]
        local ruleName = r.name or ("Rule " .. i)
        local outcome = r.outcome
        local outcomeStr = "NO OUTCOME"
        if outcome then
            if outcome.allow then outcomeStr = "ALLOW" 
            elseif outcome.deny then outcomeStr = "DENY" end
        end
        
        Spring.Log("PIPELINE PLAN", "info", string.format("  %d. %s → %s", i, ruleName, outcomeStr))
        
        -- Show evaluative conditions
        local conditions = r.conditions or {}
        for j = 1, #conditions do
            local cond = conditions[j]
            if cond.passed ~= nil then
                local status = cond.passed and "✓" or "✗"
                Spring.Log("PIPELINE PLAN", "info", string.format("     %s %s", status, cond.name or ("Condition " .. j)))
            end
        end
    end
    Spring.Log("PIPELINE PLAN", "info", "")
    
    -- Section 3: Policy Rule Topology  
    Spring.Log("PIPELINE PLAN", "info", "[POLICY RULE TOPOLOGY]")
    Spring.Log("PIPELINE PLAN", "info", string.format("Policy Name: %s", policyName))
    PipelineLogger.LogRuleTopology(rules)
    Spring.Log("PIPELINE PLAN", "info", "")
    
    -- Section 4: Expose Data (if result provided)
    if result then
        Spring.Log("PIPELINE PLAN", "info", "[EXPOSE DATA]")
        PipelineLogger.LogExposeDataSummary(result)
    end
    
    Spring.Log("PIPELINE PLAN", "info", "=== END PLAN ===")
end

---Log rule topology in hierarchical format
---@param rules table[] Array of rules
function PipelineLogger.LogRuleTopology(rules)
    if not rules or #rules == 0 then
        Spring.Log("PIPELINE PLAN", "info", "  No rules defined")
        return
    end
    
    -- Build topology tree from rules
    local topology = {}
    for _, rule in ipairs(rules) do
        local conditions = rule.conditions or {}
        local path = {}
        
        -- Extract scope conditions to build path
        for _, cond in ipairs(conditions) do
            if cond.type == "scope" or cond.type == "evaluative" then
                table.insert(path, cond.name)
            elseif cond.type == "action" then
                -- Add action with outcome
                local action = cond.name
                if rule.outcome then
                    if rule.outcome.allow then
                        action = action .. " → ALLOW"
                    elseif rule.outcome.deny then
                        action = action .. " → DENY"
                    end
                end
                table.insert(path, action)
            end
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
                Spring.Log("PIPELINE PLAN", "info", indent .. item)
            elseif type(item) == "table" then
                Spring.Log("PIPELINE PLAN", "info", indent .. item.name)
                printTopology(item.children, indent .. "   ")
            end
        end
    end
    
    printTopology(topology, "")
end

---Log expose data summary
---@param result table Combined expose result
function PipelineLogger.LogExposeDataSummary(result)
    if not result then return end
    
    local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
    
    -- Command Validation
    if result.CommandValidation then
        local cv = result.CommandValidation
        local allowed = {}
        if cv.allowGuardCommands then table.insert(allowed, "Guard") end
        if cv.allowRepairCommands then table.insert(allowed, "Repair") end
        if cv.allowReclaimCommands then table.insert(allowed, "Reclaim") end
        
        if #allowed > 0 then
            Spring.Log("PIPELINE PLAN", "info", string.format("Commands: %s allowed", table.concat(allowed, ", ")))
        else
            Spring.Log("PIPELINE PLAN", "info", string.format("Commands: None allowed%s", 
                cv.blockReason and (" (" .. cv.blockReason .. ")") or ""))
        end
    end
    
    -- Metal Transfer
    if result.MetalTransfer then
        local mt = result.MetalTransfer
        if mt.canShare then
            Spring.Log("PIPELINE PLAN", "info", string.format("Metal Transfer: Allowed%s",
                mt.maxAmount and (" (max: " .. mt.maxAmount .. ")") or ""))
        else
            Spring.Log("PIPELINE PLAN", "info", string.format("Metal Transfer: Denied%s",
                mt.blockReason and (" (" .. mt.blockReason .. ")") or ""))
        end
    end
    
    -- Energy Transfer
    if result.EnergyTransfer then
        local et = result.EnergyTransfer
        if et.canShare then
            Spring.Log("PIPELINE PLAN", "info", string.format("Energy Transfer: Allowed%s",
                et.maxAmount and (" (max: " .. et.maxAmount .. ")") or ""))
        else
            Spring.Log("PIPELINE PLAN", "info", string.format("Energy Transfer: Denied%s",
                et.blockReason and (" (" .. et.blockReason .. ")") or ""))
        end
    end
    
    -- Unit Transfer
    if result.UnitTransfer then
        local ut = result.UnitTransfer
        if ut.canShareUnits then
            Spring.Log("PIPELINE PLAN", "info", "Unit Transfer: Allowed")
        else
            Spring.Log("PIPELINE PLAN", "info", string.format("Unit Transfer: Denied%s",
                ut.blockReason and (" (" .. ut.blockReason .. ")") or ""))
        end
    end
end

---Log the active policies and their topology
---@param policies table[] Array of active policy information
function PipelineLogger.LogPolicyTopology(policies)
    if not policies or #policies == 0 then
        Spring.Log("[PIPELINE LOGGER]", "info", "No active policies")
        return
    end
    
    Spring.Log("[PIPELINE LOGGER]", "info", "=== ACTIVE POLICIES ===")
    for i, policy in ipairs(policies) do
        local status = policy.executed and "ACTIVE" or "INACTIVE"
        Spring.Log("[PIPELINE LOGGER]", "info", string.format("%d. %s [%s]", i, policy.name or ("Policy " .. i), status))
        
        if policy.dependencies and #policy.dependencies > 0 then
            Spring.Log("[PIPELINE LOGGER]", "info", string.format("   Depends on: %s", table.concat(policy.dependencies, ", ")))
        end
        
        if policy.subPolicies and #policy.subPolicies > 0 then
            Spring.Log("[PIPELINE LOGGER]", "info", string.format("   Sub-policies: %d", #policy.subPolicies))
        end
    end
    Spring.Log("[PIPELINE LOGGER]", "info", "=== END POLICIES ===")
end

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---Log a complete policy execution plan with topology
---@param plan PolicyExecutionPlan The complete execution plan
function PipelineLogger.LogExecutionPlan(plan)
    Spring.Log("[PIPELINE LOGGER]", "info", "=== Team Transfer Pipeline Execution Plan ===")
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("Generated at game frame: %d", plan.gameFrame))
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("Sender Team: %d, Receiver Team: %d", plan.senderTeamId, plan.receiverTeamId))
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("Policy Type: %s", plan.policyType))
    Spring.Log("[PIPELINE LOGGER]", "info", "")

    -- Log context summary
    Spring.Log("[PIPELINE LOGGER]", "info", "CONTEXT:")
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("  Allied Teams: %s", plan.context.areAlliedTeams and "YES" or "NO"))
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("  Cheating Enabled: %s", plan.context.isCheatingEnabled and "YES" or "NO"))
    Spring.Log("[PIPELINE LOGGER]", "info", string.format("  Sender Resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
        plan.context.senderResources.metal.current, plan.context.senderResources.metal.storage,
        plan.context.senderResources.energy.current, plan.context.senderResources.energy.storage))
    if plan.context.receiverResources then
        Spring.Log("[PIPELINE LOGGER]", "info", string.format("  Receiver Resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
            plan.context.receiverResources.metal.current, plan.context.receiverResources.metal.storage,
            plan.context.receiverResources.energy.current, plan.context.receiverResources.energy.storage))
    end
    Spring.Log("[PIPELINE LOGGER]", "info", "")

    -- Log rules (simplified since we removed dependencies)
    if #plan.rules > 0 then
        Spring.Log("[PIPELINE LOGGER]", "info", "RULE EVALUATION:")
        for i, rule in ipairs(plan.rules) do
            PipelineLogger.LogRuleEvaluation(rule, i)
        end
        Spring.Log("[PIPELINE LOGGER]", "info", "")
    end
    Spring.Log("[PIPELINE LOGGER]", "info", "")

    -- No overarching final result - each rule has its own outcome

    Spring.Log("[PIPELINE LOGGER]", "info", "=== END Team Transfer Pipeline Execution Plan ===")
end

---Log the dependency tree for policies
---@param policies PolicyInfo[] Array of policy information
---@param prefix string Current indentation prefix
function PipelineLogger.LogDependencyTree(policies, prefix)
    for i, policy in ipairs(policies) do
        local isLast = (i == #policies)
        local branch = isLast and "└── " or "├── "
        local nextPrefix = prefix .. (isLast and "    " or "│   ")

        local depsStr = ""
        if policy.dependencies and #policy.dependencies > 0 then
            depsStr = " (depends on: " .. table.concat(policy.dependencies, ", ") .. ")"
        end

        Spring.Log("[PIPELINE LOGGER]", "info",prefix .. branch .. policy.name .. depsStr)

        -- Recursively log children if this policy has sub-policies
        if policy.subPolicies and #policy.subPolicies > 0 then
            PipelineLogger.LogDependencyTree(policy.subPolicies, nextPrefix)
        end
    end
end

---Log individual rule evaluation details
---@param rule table Rule information
---@param index number Rule index in the list
function PipelineLogger.LogRuleEvaluation(rule, index)
    local outcomeDesc = rule.outcome and (rule.outcome.allow and "ALLOWED" or rule.outcome.deny and "DENIED" or "UNKNOWN") or "NO OUTCOME"

    Spring.Log("[PIPELINE LOGGER]", "info",string.format("Rule %d: %s [%s]", index, rule.name, outcomeDesc))

    if rule.conditions then
        for j, condition in ipairs(rule.conditions) do
            local condResult = condition.passed and "[✓]" or "[✗]"
            local condName = condition.name or ("Condition " .. j)
            local condType = condition.type and string.format(" (%s)", condition.type) or ""
            Spring.Log("[PIPELINE LOGGER]", "info",string.format("  %s %s%s", condResult, condName, condType))
        end
    end

    if rule.outcome then
        PipelineLogger.LogRuleOutcome(rule.outcome, "  ")
    end
end

---Log individual policy execution details (legacy function for backward compatibility)
---@param policy PolicyInfo Policy information
---@param index number Policy index in the list
function PipelineLogger.LogPolicyExecution(policy, index)
    local status = policy.executed and "EXECUTED" or "SKIPPED"
    local predStatus = policy.predicatesPassed and "PASSED" or "FAILED"

    Spring.Log("[PIPELINE LOGGER]", "info",string.format("Policy %d: %s [%s] [%s]", index, policy.name, status, predStatus))

    if policy.predicates then
        for j, predicate in ipairs(policy.predicates) do
            local predResult = predicate.passed and "[✓]" or "[✗]"
            local predName = predicate.name or ("Predicate " .. j)
            Spring.Log("[PIPELINE LOGGER]", "info",string.format("  %s %s", predResult, predName))
        end
    end

    if policy.executed and policy.result then
        PipelineLogger.LogPolicyResult(policy.result, "  ")
    end
end

---Log rule evaluation outcome
---@param outcome table Rule evaluation outcome
---@param indent string Indentation prefix
function PipelineLogger.LogRuleOutcome(outcome, indent)
    if outcome.allow then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "→ ALLOW")
    elseif outcome.deny then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "→ DENY")
    end

    if outcome.expose then
        for category, data in pairs(outcome.expose) do
            PipelineLogger.LogExposeData(data, category, indent .. "  ")
        end
    end
end

---Log policy execution result (legacy function for backward compatibility)
---@param result table Policy execution result
---@param indent string Indentation prefix
function PipelineLogger.LogPolicyResult(result, indent)
    if result.allow then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "→ ALLOW")
    elseif result.deny then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "→ DENY")
    end

    if result.expose then
        for category, data in pairs(result.expose) do
            PipelineLogger.LogExposeData(data, category, indent .. "  ")
        end
    end
end

---Log expose data for a category
---@param data table Expose data
---@param category string Category name
---@param indent string Indentation prefix
function PipelineLogger.LogExposeData(data, category, indent)
    Spring.Log("[PIPELINE LOGGER]", "info",indent .. category .. ":")

    if category == SharedEnums.TransferCategory.CommandValidation then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Guard: " .. (data.allowGuardCommands and "ALLOWED" or "DENIED"))
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Repair: " .. (data.allowRepairCommands and "ALLOWED" or "DENIED"))
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Reclaim: " .. (data.allowReclaimCommands and "ALLOWED" or "DENIED"))
        if data.blockReason then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.MetalTransfer then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Can Share: " .. (data.canShare and "YES" or "NO"))
        if data.maxAmount then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Max Amount: " .. data.maxAmount)
        end
        if data.blockReason then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.EnergyTransfer then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Can Share: " .. (data.canShare and "YES" or "NO"))
        if data.maxAmount then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Max Amount: " .. data.maxAmount)
        end
        if data.blockReason then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.UnitTransfer then
        Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Can Share: " .. (data.canShareUnits and "YES" or "NO"))
        if data.blockReason then
            Spring.Log("[PIPELINE LOGGER]", "info",indent .. "  Reason: " .. data.blockReason)
        end
    end
end

---Log final combined result
---@param result table Final combined expose result
function PipelineLogger.LogFinalResult(result)
    if result.CommandValidation then
        PipelineLogger.LogExposeData(result.CommandValidation, "CommandValidation", "  ")
    end
    if result.MetalTransfer then
        PipelineLogger.LogExposeData(result.MetalTransfer, "MetalTransfer", "  ")
    end
    if result.EnergyTransfer then
        PipelineLogger.LogExposeData(result.EnergyTransfer, "EnergyTransfer", "  ")
    end
    if result.UnitTransfer then
        PipelineLogger.LogExposeData(result.UnitTransfer, "UnitTransfer", "  ")
    end
end

---Log cache analysis
---@param cache table Current cache state
function PipelineLogger.LogCacheAnalysis(cache)
    local cacheCount = 0
    local scopeCounts = {}
    local policyTypeCounts = {}
    local frameCounts = {}

    for key, _ in pairs(cache) do
        cacheCount = cacheCount + 1

        -- Parse cache key: "scope_policyType_sender_receiver_frame"
        local parts = {}
        for part in key:gmatch("([^_]+)") do
            table.insert(parts, part)
        end

        if #parts >= 5 then
            local scope = parts[1]
            local policyType = parts[2]
            local frame = parts[5]

            scopeCounts[scope] = (scopeCounts[scope] or 0) + 1
            policyTypeCounts[policyType] = (policyTypeCounts[policyType] or 0) + 1
            frameCounts[frame] = (frameCounts[frame] or 0) + 1
        end
    end

    Spring.Log("[PIPELINE LOGGER]", "info","=== Predicate Cache Analysis ===")
    Spring.Log("[PIPELINE LOGGER]", "info",string.format("Total cache entries: %d", cacheCount))

    if next(scopeCounts) then
        Spring.Log("[PIPELINE LOGGER]", "info","Cache by scope:")
        for scope, count in pairs(scopeCounts) do
            Spring.Log("[PIPELINE LOGGER]", "info",string.format("  %s: %d entries", scope, count))
        end
    end

    if next(policyTypeCounts) then
        Spring.Log("[PIPELINE LOGGER]", "info","Cache by policy type:")
        for policyType, count in pairs(policyTypeCounts) do
            Spring.Log("[PIPELINE LOGGER]", "info",string.format("  %s: %d entries", policyType, count))
        end
    end

    if next(frameCounts) then
        Spring.Log("[PIPELINE LOGGER]", "info","Cache by frame:")
        for frame, count in pairs(frameCounts) do
            Spring.Log("[PIPELINE LOGGER]", "info",string.format("  Frame %s: %d entries", frame, count))
        end
    end

    Spring.Log("[PIPELINE LOGGER]", "info","=== END Cache Analysis ===")
end

return PipelineLogger
