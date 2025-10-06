local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class GuardTransferDefaults
local GuardTransferDefaults = {}

---Allow guard transfer
---@param ctx PolicyContext
---@return GuardTransferPolicyResult
function GuardTransferDefaults.Allow(ctx)
    return {
        allowGuardCommands = true,
        blockReason = nil
    }
end

---Deny guard transfer
---@param ctx PolicyContext
---@param reason? string
---@return GuardTransferPolicyResult
function GuardTransferDefaults.Deny(ctx, reason)
    return {
        allowGuardCommands = false,
        blockReason = reason or SharedEnums.BlockReason.NoPolicy
    }
end

return GuardTransferDefaults
