---@meta

---@class TeamTransferPolicyContext
---@field type string
---@field resource? "metal"|"energy"
---@field amount? number
---@field amountClamped? number
---@field maxShare? number
---@field receiverCur? number
---@field cumulativeMetal? number
---@field senderTeamId? number
---@field receiverTeamId? number
---@field fromTeamID? number
---@field toTeamID? number
---@field areAlliedTeams? boolean
---@field isCheatingEnabled? boolean
---@field senderIsNonPlayer? boolean
---@field receiverIsNonPlayer? boolean
---@field fromIsNonPlayer? boolean
---@field toIsNonPlayer? boolean
---@field capture? boolean
---@field takeBypassAllowed? boolean
---@field unitID? number
---@field unitDefID? number
---@field unitTeam? number
---@field commandID? number
---@field cmdID? number
---@field cmdParams? number[]
---@field cmdOptions? table
---@field cmdTag? number
---@field synced? boolean
---@field targetID? number
---@field targetTeam? number
---@field targetUnitDef? table
---@field targetAllied? boolean
---@field targetIsComplete? boolean

---@alias TeamTransferPredicate fun(ctx: TeamTransferPolicyContext): boolean
---@alias TeamTransferHandler fun(ctx: TeamTransferPolicyContext): TeamTransferResult

---@field allow? boolean
---@field deny? boolean
---@field applyTransfer? TeamTransferApplyResult
---@field expose? TeamTransferExposeResult

---@field updateCumulativeMetal? boolean

---@field threshold? number
---@field taxRate? number

---@class PolicyBuilder
---@field For fun(self: PolicyBuilder, policyType: string): PolicyBuilder
---@field When fun(self: PolicyBuilder, predicate: TeamTransferPredicate): PolicyBuilder
---@field Use fun(self: PolicyBuilder, handler: TeamTransferHandler): PolicyBuilder




---@class TeamTransferAPI
