local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class ReclaimTransferDefaults
local ReclaimTransferDefaults = {}

---Allow reclaim transfer
---@param ctx PolicyContext
---@return ReclaimTransferPolicyResult
function ReclaimTransferDefaults.Allow(ctx)
    return {
        allowReclaimCommands = true,
        blockReason = nil
    }
end

---Deny reclaim transfer
---@param ctx PolicyContext
---@param reason? string
---@return ReclaimTransferPolicyResult
function ReclaimTransferDefaults.Deny(ctx, reason)
    return {
        allowReclaimCommands = false,
        blockReason = reason or SharedEnums.BlockReason.NoPolicy
    }
end

return ReclaimTransferDefaults
