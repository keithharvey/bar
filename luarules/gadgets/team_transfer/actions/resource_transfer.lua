---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function ResourceTransfer(ctx)
    local desiredAmount = ctx.desiredAmount
    local policyResult = ctx.policyResult
    local amount = math.min(desiredAmount, policyResult.amountSendable)

    local untaxedPortion = math.min(amount, policyResult.untaxedPortion)
    local taxablePortion = amount - untaxedPortion

    local actualReceived, actualSent
    if taxablePortion > 0 then
        if policyResult.taxRate >= 1.0 then
            -- 100% or more tax means taxed portion costs full amount but receiver gets nothing
            actualReceived = untaxedPortion
            actualSent = untaxedPortion + taxablePortion
        else
            local taxedPortionSent = taxablePortion / (1 - policyResult.taxRate)
            local taxedPortionReceived = taxedPortionSent * (1 - policyResult.taxRate)
            actualReceived = untaxedPortion + taxedPortionReceived
            actualSent = untaxedPortion + taxedPortionSent
        end
    else
        actualReceived = untaxedPortion
        actualSent = untaxedPortion
    end

    local springRepo = ctx.repositories.springRepo
    springRepo:AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -actualSent)
    springRepo:AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, actualReceived)

    ---@type ResourceTransferResult
    local setTeamResourcesResult = {
        success = true,
        sent = actualSent,
        received = actualReceived,
        senderTeamId = ctx.senderTeamId,
        receiverTeamId = ctx.receiverTeamId,
        policyResult = policyResult
    }

    return setTeamResourcesResult
end

return ResourceTransfer