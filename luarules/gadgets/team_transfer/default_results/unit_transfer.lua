local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class UnitTransferDefaults
local UnitTransferDefaults = {}

---Allow unit transfer with full sharing capabilities
---@param ctx PolicyContext
---@return UnitTransferPolicyResult
function UnitTransferDefaults.Allow(ctx)
    return {
        canShareUnits = true,
        blockReason = nil
    }
end

---Deny unit transfer
---@param ctx PolicyContext
---@param reason? string
---@return UnitTransferPolicyResult
function UnitTransferDefaults.Deny(ctx, reason)
    return {
        canShareUnits = false,
        blockReason = reason or SharedEnums.BlockReason.NoPolicy
    }
end

return UnitTransferDefaults
