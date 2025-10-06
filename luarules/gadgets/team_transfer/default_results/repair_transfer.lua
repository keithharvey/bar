local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class RepairTransferDefaults
local RepairTransferDefaults = {}

---Allow repair transfer
---@param ctx PolicyContext
---@return RepairTransferPolicyResult
function RepairTransferDefaults.Allow(ctx)
    return {
        allowRepairCommands = true,
        blockReason = nil
    }
end

---Deny repair transfer
---@param ctx PolicyContext
---@param reason? string
---@return RepairTransferPolicyResult
function RepairTransferDefaults.Deny(ctx, reason)
    return {
        allowRepairCommands = false,
        blockReason = reason or  SharedEnums.BlockReason.NoPolicy
    }
end

return RepairTransferDefaults
