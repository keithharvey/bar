-- Team Transfer Type Definitions
-- Minimal types focused on IntelliSense support and keeping the linter honest

---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
---@alias ResourceType "metal" | "energy"


---@class ValidationResult
---@field ok boolean
---@field reason string?
---@field translationTokens table?

-- Unit Transfer Action

---@class UnitTransferPolicyResult
---@field canShareUnits boolean
---@field sharingMode string
---@field blockReason string?

---@class UnitTransferContext : PolicyActionContext
---@field unitIds number[]
---@field given boolean?
---@field validationResults UnitValidationResult[]
---@field policyResult UnitTransferPolicyResult

---@class UnitValidationResult : ValidationResult
---@field unitId number

---@class ResourceValidationResult : ValidationResult
---@field amount number
---@field resourceType ResourceType
---@field suggestedAmount number

---@class UnitTransferResult
---@field success boolean
---@field outcome string
---@field reason string?
---@field successfulUnitIds number[]
---@field failedUnitIds number[]
---@field senderTeamId number
---@field receiverTeamId number
---@field validationResult ValidationResult[]
---@field policyResult UnitTransferPolicyResult

---@class PostUnitTransferContext : UnitTransferContext
---@field transferResult UnitTransferResult

-- Resource Transfer Action

---@class ResourcePolicyResult
---@field canShare boolean
---@field amountSendable number
---@field receivable number
---@field taxedPortion number
---@field untaxedPortion number
---@field taxRate number
---@field resourceType ResourceType
---@field remainingTaxFreeAllowance? number

---@class ResourceTransferContext : PolicyActionContext
---@field resourceType ResourceType
---@field desiredAmount number
---@field policyResult ResourcePolicyResult

---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId number
---@field receiverTeamId number
---@field policyResult ResourcePolicyResult

---@class PostResourceTransferContext : ResourceTransferContext
---@field transferResult ResourceTransferResult

-- Command Transfer Actions

---@class CommandTransferPolicyResult
---@field allowCommands boolean
---@field blockReason string?

--- Policy Context

---@class TeamInfo
---@field id number
---@field name string
---@field leader number
---@field isDead boolean
---@field isAI boolean
---@field side string
---@field allyTeam number

---@class ContextRepositories
---@field springRepo table

---@class RegisterInitializePolicyContext
---@field playerIds number[]
---@field repositories ContextRepositories

---@class TeamData
---@field id number
---@field isHuman boolean
---@field name string
---@field metal ResourceData
---@field energy ResourceData

---@class ResourceData
---@field current number
---@field storage number
---@field pull number
---@field income number
---@field expense number
---@field shareSlider number
---@field sent number
---@field received number

---@class TeamResources
---@field metal ResourceData
---@field energy ResourceData

---@class PolicyContext
---@field senderTeamId number
---@field receiverTeamId number
---@field resultSoFar table<TransferCategory, table>
---@field sender TeamResources
---@field receiver TeamResources
---@field repositories ContextRepositories
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean

---@class PolicyActionContext : PolicyContext
---@field transferCategory string SharedEnums.TransferCategory

---@class ResourceTransferPolicyContext : PolicyActionContext
---@field amount number
---@field resource ResourceType

---@class UnitTransferPolicyContext : PolicyActionContext
---@field unitID number
---@field policyResult UnitTransferPolicyResult

---@class CommandTransferContext : PolicyActionContext
---@field unitID number Unit being commanded
---@field unitDefID number Unit definition ID
---@field cmdID number Command ID
---@field cmdParams table Command parameters
---@field cmdOptions table Command options
---@field cmdTag number Command tag
---@field playerID number Player issuing command
---@field targetUnitID number Target unit ID (for guard/repair/reclaim)
---@field targetUnitDef table Target unit definition


---@class CombinedPolicyResult
---@field metal_transfer ResourcePolicyResult
---@field energy_transfer ResourcePolicyResult
---@field unit_transfer UnitTransferPolicyResult
---@field command_transfer CommandTransferPolicyResult


-- Sharing Mode Types

---@class ModOptionConfig
---@field value any The default value for this option
---@field locked boolean Whether this option can be changed by users
---@field bounds ModOptionBounds|nil Constraints on the option value
---@field ui string|nil UI hints (e.g., "hidden")

---@class ModOptionBounds
---@field min number|nil Minimum value (for numeric options)
---@field max number|nil Maximum value (for numeric options)
---@field step number|nil Step size for numeric options
---@field items table|nil Array of allowed values for list options

---@class PolicyModule
---@field name string SharedEnums.Policies The unique name/identifier of this policy
---@field func fun(builder: DSL) The policy builder function that receives our DSL
---@field enabled fun(ctx: RegisterInitializePolicyContext): boolean The function that determines if this policy should be enabled

---@class SharingModeConfig
---@field key SharingMode Unique identifier for this sharing mode
---@field name string Display name for this sharing mode
---@field desc string Description of this sharing mode
---@field allowRanked boolean Whether this mode is allowed in ranked games
---@field modOptions table<string, ModOptionConfig> Map of mod option keys to their configurations
