local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local MetalTransferDefaults = {}

---Allow metal transfer with full sharing capabilities
---@param ctx PolicyContext
---@return ResourcePolicyResult
function MetalTransferDefaults.Allow(ctx)
    local maxReceivableAmount = ctx.receiver.metal.storage - ctx.receiver.metal.current
    local amountSendable = math.min(ctx.sender.metal.current, maxReceivableAmount)
    
    return {
        canShare = true,
        amountSendable = amountSendable,
        receivable = maxReceivableAmount,
        taxedPortion = 0,
        untaxedPortion = amountSendable,
        taxRate = 0,
        resourceType = SharedEnums.ResourceType.METAL
    }
end

---Deny metal transfer
---@param ctx PolicyContext
---@param reason? string
---@return ResourcePolicyResult
function MetalTransferDefaults.Deny(ctx, reason)
    return {
        canShare = false,
        amountSendable = 0,
        receivable = 0,
        taxedPortion = 0,
        untaxedPortion = 0,
        taxRate = 0,
        resourceType = SharedEnums.ResourceType.METAL
    }
end

return MetalTransferDefaults
