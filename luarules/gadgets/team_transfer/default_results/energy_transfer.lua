local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class EnergyTransferDefaults
local EnergyTransferDefaults = {}

---Allow energy transfer with full sharing capabilities
---@param ctx PolicyContext
---@return ResourcePolicyResult
function EnergyTransferDefaults.Allow(ctx)
    local maxReceivableAmount = ctx.receiver.energy.storage - ctx.receiver.energy.current
    local amountSendable = math.min(ctx.sender.energy.current, maxReceivableAmount)
    
    return {
        canShare = true,
        amountSendable = amountSendable,
        receivable = maxReceivableAmount,
        taxedPortion = 0,
        untaxedPortion = amountSendable,
        taxRate = 0,
        resourceType = SharedEnums.ResourceType.ENERGY
    }
end

---Deny energy transfer
---@param ctx PolicyContext
---@param reason? string
---@return ResourcePolicyResult
function EnergyTransferDefaults.Deny(ctx, reason)
    return {
        canShare = false,
        amountSendable = 0,
        receivable = 0,
        taxedPortion = 0,
        untaxedPortion = 0,
        taxRate = 0,
        resourceType = SharedEnums.ResourceType.ENERGY
    }
end

return EnergyTransferDefaults
