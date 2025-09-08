---@class PipelineLogger
---Intelligent logging for policy execution plans and topology
local PipelineLogger = {}

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

---Log a complete policy execution plan with topology
---@param plan PolicyExecutionPlan The complete execution plan
function PipelineLogger.LogExecutionPlan(plan)
    LogInfo("=== Team Transfer Pipeline Execution Plan ===")
    LogInfo(string.format("Generated at game frame: %d", plan.gameFrame))
    LogInfo(string.format("Sender Team: %d, Receiver Team: %d", plan.senderTeamId, plan.receiverTeamId))
    LogInfo(string.format("Policy Type: %s", plan.policyType))
    LogInfo("")

    -- Log context summary
    LogInfo("CONTEXT:")
    LogInfo(string.format("  Allied Teams: %s", plan.context.areAlliedTeams and "YES" or "NO"))
    LogInfo(string.format("  Cheating Enabled: %s", plan.context.isCheatingEnabled and "YES" or "NO"))
    LogInfo(string.format("  Sender Resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
        plan.context.senderResources.metal.current, plan.context.senderResources.metal.storage,
        plan.context.senderResources.energy.current, plan.context.senderResources.energy.storage))
    if plan.context.receiverResources then
        LogInfo(string.format("  Receiver Resources: Metal=%.1f/%.1f, Energy=%.1f/%.1f",
            plan.context.receiverResources.metal.current, plan.context.receiverResources.metal.storage,
            plan.context.receiverResources.energy.current, plan.context.receiverResources.energy.storage))
    end
    LogInfo("")

    -- Log dependency tree
    if #plan.policies > 0 then
        LogInfo("POLICY DEPENDENCY TREE:")
        PipelineLogger.LogDependencyTree(plan.policies, "")
        LogInfo("")
    end

    -- Log execution plan
    LogInfo("POLICY EXECUTION PLAN:")
    for i, policy in ipairs(plan.policies) do
        PipelineLogger.LogPolicyExecution(policy, i)
    end
    LogInfo("")

    -- Log final result
    LogInfo("FINAL RESULT:")
    PipelineLogger.LogFinalResult(plan.result)
    LogInfo("")

    LogInfo("=== END Team Transfer Pipeline Execution Plan ===")
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

        LogInfo(prefix .. branch .. policy.name .. depsStr)

        -- Recursively log children if this policy has sub-policies
        if policy.subPolicies and #policy.subPolicies > 0 then
            PipelineLogger.LogDependencyTree(policy.subPolicies, nextPrefix)
        end
    end
end

---Log individual policy execution details
---@param policy PolicyInfo Policy information
---@param index number Policy index in the list
function PipelineLogger.LogPolicyExecution(policy, index)
    local status = policy.executed and "EXECUTED" or "SKIPPED"
    local predStatus = policy.predicatesPassed and "PASSED" or "FAILED"

    LogInfo(string.format("Policy %d: %s [%s] [%s]", index, policy.name, status, predStatus))

    if policy.predicates then
        for j, predicate in ipairs(policy.predicates) do
            local predResult = predicate.passed and "[✓]" or "[✗]"
            local predName = predicate.name or ("Predicate " .. j)
            LogInfo(string.format("  %s %s", predResult, predName))
        end
    end

    if policy.executed and policy.result then
        PipelineLogger.LogPolicyResult(policy.result, "  ")
    end
end

---Log policy execution result
---@param result table Policy execution result
---@param indent string Indentation prefix
function PipelineLogger.LogPolicyResult(result, indent)
    if result.allow then
        LogInfo(indent .. "→ ALLOW")
    elseif result.deny then
        LogInfo(indent .. "→ DENY")
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
    LogInfo(indent .. category .. ":")

    if category == SharedEnums.TransferCategory.CommandValidation then
        LogInfo(indent .. "  Guard: " .. (data.allowGuardCommands and "ALLOWED" or "DENIED"))
        LogInfo(indent .. "  Repair: " .. (data.allowRepairCommands and "ALLOWED" or "DENIED"))
        LogInfo(indent .. "  Reclaim: " .. (data.allowReclaimCommands and "ALLOWED" or "DENIED"))
        if data.blockReason then
            LogInfo(indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.MetalTransfer then
        LogInfo(indent .. "  Can Share: " .. (data.canShare and "YES" or "NO"))
        if data.maxAmount then
            LogInfo(indent .. "  Max Amount: " .. data.maxAmount)
        end
        if data.blockReason then
            LogInfo(indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.EnergyTransfer then
        LogInfo(indent .. "  Can Share: " .. (data.canShare and "YES" or "NO"))
        if data.maxAmount then
            LogInfo(indent .. "  Max Amount: " .. data.maxAmount)
        end
        if data.blockReason then
            LogInfo(indent .. "  Reason: " .. data.blockReason)
        end
    elseif category == SharedEnums.TransferCategory.UnitTransfer then
        LogInfo(indent .. "  Can Share: " .. (data.canShareUnits and "YES" or "NO"))
        if data.blockReason then
            LogInfo(indent .. "  Reason: " .. data.blockReason)
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

    LogInfo("=== Predicate Cache Analysis ===")
    LogInfo(string.format("Total cache entries: %d", cacheCount))

    if next(scopeCounts) then
        LogInfo("Cache by scope:")
        for scope, count in pairs(scopeCounts) do
            LogInfo(string.format("  %s: %d entries", scope, count))
        end
    end

    if next(policyTypeCounts) then
        LogInfo("Cache by policy type:")
        for policyType, count in pairs(policyTypeCounts) do
            LogInfo(string.format("  %s: %d entries", policyType, count))
        end
    end

    if next(frameCounts) then
        LogInfo("Cache by frame:")
        for frame, count in pairs(frameCounts) do
            LogInfo(string.format("  Frame %s: %d entries", frame, count))
        end
    end

    LogInfo("=== END Cache Analysis ===")
end

return PipelineLogger
