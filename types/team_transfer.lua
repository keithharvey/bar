-- Team transfer type definitions: minimal types for IntelliSense and the linter.

---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"

--- Per-resource snapshot from the BAR-owned GG.GetTeamResourceData (Spring.GetTeamResources plus Lua-owned sent/received).
---@class ResourceData
---@field resourceType ResourceName
---@field current number Engine-owned snapshot; read-only to Lua
---@field storage number Engine-owned snapshot; read-only to Lua
---@field pull number Engine-owned snapshot; read-only to Lua
---@field income number Engine-owned snapshot; read-only to Lua
---@field expense number Engine-owned snapshot; read-only to Lua
---@field shareSlider number Engine stores, Lua interprets
---@field sent number
---@field received number
---@field excess number Overflow pool to redistribute (solver input); last tick's wasted amount in GetTeamResourceData

---@class TeamResourceData
---@field allyTeam number
---@field isDead boolean
---@field metal ResourceData
---@field energy ResourceData

---@class PolicyResult
---@field senderTeamId number
---@field receiverTeamId number

-- Unit Transfer Action
---@class UnitPolicyResult : PolicyResult
---@field canShare boolean
---@field sharingModes string[]
---@field stunSeconds number
---@field stunCategory string
---@field techBlocking? TechBlockingContext

---@class UnitTransferContext : PolicyActionContext
---@field unitIds number[]
---@field given boolean?
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

---@class UnitValidationResult
---@field status string TransferEnums.UnitValidationOutcome
---@field invalidUnitCount number
---@field invalidUnitIds number[]
---@field invalidUnitNames string[]
---@field validUnitCount number
---@field validUnitIds number[]
---@field validUnitNames string[]

---@class UnitTransferResult
---@field outcome string TransferEnums.UnitValidationOutcome
---@field senderTeamId number
---@field receiverTeamId number
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

---@class GameUnitTransferController
---@field AllowUnitTransfer fun(unitID: number, unitDefID: number, fromTeamID: number, toTeamID: number, capture: boolean): boolean
---@field TeamShare fun(srcTeamID: number, dstTeamID: number)

-- Resource Transfer Action

---@class ResourcePolicyResult : PolicyResult
---@field canShare boolean
---@field amountSendable number
---@field amountReceivable number
---@field taxedPortion number
---@field taxRate number
---@field resourceType ResourceName
---@field techBlocking? TechBlockingContext

---@class ResourceTransferContext : PolicyActionContext
---@field resourceType ResourceName
---@field desiredAmount number
---@field policyResult ResourcePolicyResult

---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId number
---@field receiverTeamId number
---@field policyResult ResourcePolicyResult

--- Policy Context

---@class TeamResources
---@field metal ResourceData
---@field energy ResourceData

---@class TechUnlockInfo
---@field unlockLevel number    Tech level at which this domain next changes
---@field unlockThreshold number Keystones needed to reach that level
---@field unlockValue any        What activates (mode string for units, rate number for tax)

---@class TechBlockingContext
---@field level number              Current latched tech level (1/2/3)
---@field points number             Alive Keystone count
---@field t2Threshold number        Computed T2 threshold (per-player * team size)
---@field t3Threshold number        Computed T3 threshold
---@field nextLevel number          Next tech level to reach (2 or 3, or 3 if maxed)
---@field nextThreshold number      Keystones needed for next level
---@field unitTransfer? TechUnlockInfo Next unit sharing mode change
---@field metalTransfer? TechUnlockInfo Next metal tax rate change
---@field energyTransfer? TechUnlockInfo Next energy tax rate change

---@class PolicyContextExtensions
---@field techBlocking? TechBlockingContext

---@class PolicyContext
---@field senderTeamId number
---@field receiverTeamId number
---@field sender TeamResources
---@field receiver TeamResources
---@field springRepo SpringSynced
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean
---@field ext PolicyContextExtensions
---@field unitSharingModes? string[] Effective sharing modes (set by enricher, e.g. tech blocking)
---@field taxRate? number           Effective tax rate (set by enricher, e.g. tech blocking)

---@class PolicyActionContext : PolicyContext
---@field transferCategory string TransferEnums.TransferCategory

---@class EconomyShareMember
---@field teamId number
---@field allyTeam number
---@field resourceType ResourceName
---@field resource ResourceData
---@field current number effective current = resource.current + resource.excess
---@field storage number
---@field shareCursor number
---@field target number?

--- Solver output; the controller applies pools, excess, and sent/received itself.
---@class EconomyTeamResult
---@field teamId number
---@field resourceType ResourceName
---@field delta number Net change vs the snapshot (informational; conservation/tests)
---@field sent number
---@field received number
---@field excess number Wasted overflow this tick

---@class EconomyFlowLedger
---@field received number
---@field sent number
---@field taxed number

---@alias EconomyFlowSummary table<number, table<ResourceName, EconomyFlowLedger>>

---@class ResourceShareParams
---@field senderTeamID number
---@field targetTeamID number
---@field resourceType string
---@field amount number
