local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---Execute unit transfer with pre-validated units
---@param ctx UnitTransferContext
---@return UnitTransferResult
function UnitTransfer(ctx)
    local transferredUnits = {}
    local failedUnits = {}


    -- Check if policy allows unit sharing
    if not ctx.policyResult.canShareUnits then
        -- Policy blocks sharing, fail all units
        for _, unitId in ipairs(ctx.unitIds) do
            table.insert(failedUnits, unitId)
        end
    else
        -- Process each unit based on validation results
        for _, unitId in ipairs(ctx.unitIds) do
            -- Check if this unit passed validation
            local unitPassed = true
            for _, result in ipairs(ctx.validationResults) do
                if result.unitId == unitId and result.ok == false then
                    unitPassed = false
                    break
                end
            end

            if unitPassed then
                local success = ctx.repositories.springRepo:TransferUnit(unitId, ctx.receiverTeamId, ctx.given or false)
                if success then
                    table.insert(transferredUnits, unitId)
                else
                    table.insert(failedUnits, unitId)
                end
            else
                table.insert(failedUnits, unitId)
            end
        end
    end

    local success = #transferredUnits > 0
    local reason = nil
    if not success and #failedUnits > 0 then
        reason = "Some units failed to transfer"
    elseif not success then
        reason = "No units to transfer"
    end

    return {
        success = success,
        outcome = success and "success" or "failed",
        reason = reason,
        successfulUnitIds = transferredUnits,
        failedUnitIds = failedUnits,
        senderTeamId = ctx.senderTeamId,
        receiverTeamId = ctx.receiverTeamId,
        validationResult = ctx.validationResults,
        policyResult = ctx.policyResult
    }
end

return UnitTransfer
