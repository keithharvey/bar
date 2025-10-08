---@class CalculateSenderTaxedAmountResult
---@field sentAmount number
---@field receivedAmount number

---@class ResourceTransferModule
---@field CalculateSenderTaxedAmount fun(policyResult: ResourcePolicyResult, desiredReceived: number): CalculateSenderTaxedAmountResult

local M = {}

--- Core helper: compute sender cost for a desired received amount under policyResult
---@param policyResult ResourcePolicyResult
---@param desiredReceived number
---@return CalculateSenderTaxedAmountResult
function M.CalculateSenderTaxedAmount(policyResult, desiredReceived)
    local maxReceivable = policyResult.amountReceivable
    local desired = math.min(desiredReceived, policyResult.amountSendable, maxReceivable)
    if desired <= 0 then
        return { sentAmount = 0, receivedAmount = 0 }
    end

    local untaxed = math.min(desired, policyResult.untaxedPortion)
    local taxed = desired - untaxed
    local r = policyResult.taxRate

    local received
    local sent
    if taxed > 0 then
        if r >= 1.0 then
            -- 100% tax means taxed portion cannot be sent (infinite cost)
            sent = untaxed
            received = untaxed  -- only untaxed portion reaches receiver
        else
            sent = untaxed + (taxed / (1 - r))
            received = desired  -- all desired amount reaches receiver
        end
    else
        sent = untaxed
        received = untaxed
    end

    return {
        sentAmount = sent,
        receivedAmount = received
    }
end

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
local function ResourceTransfer(ctx)
    local policyResult = ctx.policyResult
    local desiredAmount = ctx.desiredAmount

    local amounts = M.CalculateSenderTaxedAmount(policyResult, desiredAmount)
    local actualSent = amounts.sentAmount
    local actualReceived = amounts.receivedAmount

    local springRepo = ctx.repositories.springRepo
    springRepo:AddTeamResource(ctx.senderTeamId, policyResult.resourceType, -actualSent)
    springRepo:AddTeamResource(ctx.receiverTeamId, policyResult.resourceType, actualReceived)

    ---@type ResourceTransferResult
    local result = {
        success = true,
        sent = actualSent,
        received = actualReceived,
        senderTeamId = ctx.senderTeamId,
        receiverTeamId = ctx.receiverTeamId,
        policyResult = policyResult
    }

    return result
end

-- Make module callable: M(ctx) → perform transfer
setmetatable(M, { __call = function(_, ctx) return ResourceTransfer(ctx) end })

return M