-- Comprehensive type definitions for Team Transfer API
-- This file is for intellisense only and should not be executed
-- Covers both synced (gadget) and unsynced (widget) APIs

-- Enum-like type aliases (since Lua doesn't have native enums)
-- These provide IntelliSense autocomplete and type checking for enum values
-- Use these instead of generic 'string' types where enum values are expected

---Policy types for the Team Transfer system (PascalCase keys, snake_case values)
---@alias PolicyType "resource_transfer" | "unit_transfer" | "command" | "team_event"

---Transfer categories for expose data organization (PascalCase keys, snake_case values)
---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "command_validation" | "team_events"

---Resource types supported by the engine (PascalCase keys, Spring engine values)
---@alias ResourceType "metal" | "energy"

---Predicate scopes for team relationship queries (PascalCase keys, snake_case values)
---@alias PredicateScope "allied" | "enemy"

---Gadget API for Team Transfer system - provides policy registration and execution
---@class TeamTransferGadgetAPI
---@field RegisterPolicy fun(policyName: string, builderFn: function): void
---@field Enums TeamTransferSharedEnums
---@field UnitSharing table
---@field RegisterInitialize fun(initFn: function): void
---@field RegisterPreProcess fun(preProcessFn: function): void
---@field RegisterPostTransfer fun(listenerFn: function): void
---@field RegisterValidator fun(config: table, validatorFn: function): void
---@field NotifyPostTransfer fun(transferData: table): void
---@field Debug table

---Global gadget-to-gadget communication table
---@class GG
---@field TeamTransfer TeamTransferGadgetAPI

---UI scope for querying transfer capabilities
---@class PredicateUIScope
---@field GetExposeData fun(senderTeamID: number, receiverTeamID: number): ResourceTransferExposeOutput|UnitTransferExposeOutput


---Widget API for Team Transfer system - provides read-only access to transfer capabilities
---@class TeamTransferWidgetAPI
---@field Enums TeamTransferSharedEnums Clean enum interface
---@see TeamTransferSharedEnums Use WG.TeamTransfer.Enums.PolicyType.ResourceTransfer instead of strings
---@field ForAlliedResourceTransfers PredicateUIScope Allied resource transfer queries
---@field ForEnemyResourceTransfers PredicateUIScope Enemy resource transfer queries  
---@field ForAlliedUnitTransfers PredicateUIScope Allied unit transfer queries
---@field ForEnemyUnitTransfers PredicateUIScope Enemy unit transfer queries
---@field CanTransfer fun(senderTeamID: number, receiverTeamID: number, transferCategory: TransferCategory, selectedUnitIDs: number[]?): boolean
---@field CanShareMetal fun(senderTeamID: number, receiverTeamID: number): boolean
---@field CanShareEnergy fun(senderTeamID: number, receiverTeamID: number): boolean
---@field CanShareUnits fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[]): boolean
---@field GetMaxMetalAmount fun(senderTeamID: number, receiverTeamID: number): number
---@field GetMaxEnergyAmount fun(senderTeamID: number, receiverTeamID: number): number
---@field GetResourceTransferData fun(senderTeamID: number, receiverTeamID: number): ResourceTransferExposeOutput
---@field GetUnitTransferData fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[]): UnitTransferExposeOutput
---@field handleShareButtonClick fun(targetTeamID: number): boolean
---@field validateShareCommand fun(): boolean
---@field IsSharingOption fun(optionName: string): boolean
---@field MODOPTION_KEYS table
---@field Policies table
---@field ResourceShareTax table
---@field UnitSharing table
---@field ShareEnergy fun(senderTeamID: number, receiverTeamID: number, amount: number, receiverName: string): nil
---@field ShareMetal fun(senderTeamID: number, receiverTeamID: number, amount: number, receiverName: string): nil
---@field ShareUnits fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[], receiverName: string): nil

---Global widget-to-widget communication table with Team Transfer API
---@class WG
---@field TeamTransfer TeamTransferWidgetAPI

---Legacy unified resource transfer UI state (abstracts away policy hierarchy)
---@deprecated Use ResourceTransferExposeOutput instead
---@class ResourceTransferUIState
---@field maxMetalAmount number Maximum metal amount that can be sent right now
---@field metalThreshold number? Metal threshold (if applicable)
---@field taxRate number Tax rate (0 if no tax policy active)
---@field amountSendable number Amount that can be sent right now (legacy)
---@field amountAlreadySent number Amount already sent (cumulative, legacy)
---@field amountRemainingAllowance number Amount remaining in allowance/threshold (legacy)
---@field maxPossibleSend number Maximum possible send amount (legacy)

---@class TeamTransferPolicyContext
---@field type string
---@field resource? "metal"|"energy"
---@field amount? number
---@field amountClamped? number
---@field maxShare? number
---@field receiverCur? number
---@field cumulativeMetal? number
---@field lastResult? TeamTransferResultTable -- Result from previous policy in the dependency chain
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
---@field teamID? number
---@field eventType? "PlayerAbandoned"|"TeamDestroyed"|"PlayerReconnected"
---@field playerID? number
---@field gameFrame? number

---@class TeamTransferApplyTransfer
---@field sent number
---@field received number

---@class TeamTransferApplyCommands
---@field ClearLoad? number[] -- unitIDs to clear load orders from
---@field ClearSelfD? number[] -- unitIDs to clear self-destruct orders from
---@field ClearTeamSelfD? number[] -- teamIDs to clear all self-destruct orders from
---@field RemoveCommands? {unitID: number, cmdID: number, options?: string[]}[] -- commands to remove from units
---@field GiveCommands? {unitID: number, cmdID: number, params?: number[], options?: string[]}[] -- new commands to give to units

---Policy-specific expose types for strongly typed policy chaining
---@see luarules/gadgets/team_transfer/policies/game_prevent_excessive_share.lua
---@class PreventExcessiveShareExpose
---@field maxShareAmount number The maximum amount that can be shared based on receiver's storage capacity
---@field cappedAmount number The actual amount after applying the storage cap
---@field wasAmountCapped boolean Whether the original amount was reduced due to storage limits
---@field amountSendable number How much can be sent right now (UI-focused)
---@field maxPossibleSend number Maximum they could ever send to this receiver (UI-focused)

---@see luarules/gadgets/team_transfer/policies/resource_tax.lua
---@class ResourceTaxExpose
---@field taxRate number The tax rate applied (0.0 to 1.0)
---@field taxedAmount number The amount after tax is applied
---@field taxCollected number The amount collected as tax

---@see luarules/gadgets/team_transfer/policies/metal_send_threshold.lua
---@class MetalSendThresholdExpose
---@field metalThreshold number The cumulative threshold for metal sending
---@field cumulativeSent number Current cumulative amount sent
---@field allowanceRemaining number How much more can be sent before hitting threshold

---@see luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua
---@class TaxResourceSharingExpose
---@field maxShareAmount number Maximum amount that can be shared after tax constraints
---@field _policyData {taxRate: number} Internal policy calculation data

-- Shared Output Types - Used by both policies and UI
-- These provide strongly-typed interfaces for expose data rollup

---@class MetalTransferExposeOutput
---@field maxMetalShareAmount number Maximum metal that can be shared to this specific receiver
---@field canShareMetal boolean Whether metal sharing is allowed to this receiver
---@field blockReason string? Reason why metal sharing is blocked (if blocked)
---@field taxRate number? Tax rate applied to metal transfers (if applicable)
---@field metalThreshold number? Cumulative metal threshold (if applicable)
---@field amountAlreadySent number? Metal amount already sent in current period
---@field amountRemainingAllowance number? Remaining metal allowance before hitting limits

---@class EnergyTransferExposeOutput
---@field maxEnergyShareAmount number Maximum energy that can be shared to this specific receiver
---@field canShareEnergy boolean Whether energy sharing is allowed to this receiver
---@field blockReason string? Reason why energy sharing is blocked (if blocked)
---@field taxRate number? Tax rate applied to energy transfers (if applicable)
---@field energyThreshold number? Cumulative energy threshold (if applicable)
---@field amountAlreadySent number? Energy amount already sent in current period
---@field amountRemainingAllowance number? Remaining energy allowance before hitting limits

---@class ResourceTransferExposeOutput
---@field metal MetalTransferExposeOutput Metal-specific transfer data
---@field energy EnergyTransferExposeOutput Energy-specific transfer data

---@class UnitTransferExposeOutput  
---@field canShareUnits boolean Whether unit sharing is allowed to this receiver
---@field shareableUnitCount number? Number of currently selected units that can be shared
---@field unshareableUnitCount number? Number of currently selected units that cannot be shared
---@field blockReason string? Reason why sharing is blocked (if canShareUnits is false)

---@class CommandExposeOutput
---@field allowGuardCommands boolean Whether guard commands to allies are allowed
---@field allowRepairCommands boolean Whether repair commands to allies are allowed  
---@field allowReclaimCommands boolean Whether reclaim commands to allies are allowed

---@class TeamTransferResultTable
---@field allow? boolean -- explicitly allow the transfer
---@field deny? boolean -- explicitly deny the transfer
---@field applyTransfer? TeamTransferApplyTransfer -- modify the transfer amounts
---@field applyCommands? TeamTransferApplyCommands -- apply commands to units during transfer
---@field expose? table -- expose data to the UI (specific structure depends on policy)

-- Specific policy result types - each policy defines its own strongly-typed result
---@class PreventExcessiveShareResult : TeamTransferResultTable
---@field expose {preventExcessiveShare: PreventExcessiveShareExpose}

---@class TaxResourceSharingResult : TeamTransferResultTable  
---@field expose {taxResourceSharing: TaxResourceSharingExpose}

---@alias TeamTransferResult boolean|TeamTransferResultTable|nil
---@alias TeamTransferPredicate fun(ctx: TeamTransferPolicyContext): boolean
---@alias TeamTransferHandler fun(ctx: TeamTransferPolicyContext): TeamTransferResult

---Base policy builder with fluent interface methods
---@class PolicyBuilderBase
---Add a condition predicate to the policy
---@see luarules/gadgets/team_transfer/api_gadgets.lua:39 When() implementation
---@field When fun(self: PolicyBuilderBase, predicate: TeamTransferPredicate): PolicyBuilderBase
---Set the handler function for the policy
---@see luarules/gadgets/team_transfer/api_gadgets.lua:48 Use() implementation
---@field Use fun(self: PolicyBuilderBase, handler: TeamTransferHandler): PolicyBuilderBase
---Create an allow policy (shorthand for Use with allow result)
---@see luarules/gadgets/team_transfer/api_gadgets.lua:53 Allow() implementation
---@field Allow fun(self: PolicyBuilderBase): PolicyBuilderBase
---Create a deny policy (shorthand for Use with deny result)
---@see luarules/gadgets/team_transfer/api_gadgets.lua:58 Deny() implementation
---@field Deny fun(self: PolicyBuilderBase): PolicyBuilderBase

---Policy builder for commands with Allied/Enemy scope selection
---@class CommandPolicyContainer
---Get Allied scope policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:69 Allied() implementation
---@field Allied fun(self: CommandPolicyContainer): PolicyBuilderBase
---Get Enemy scope policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:70 Enemy() implementation  
---@field Enemy fun(self: CommandPolicyContainer): PolicyBuilderBase

---Policy builder for transfers with Allied/Enemy scope selection
---@class TransferPolicyContainer
---Get Allied scope policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:69 Allied() implementation
---@field Allied fun(self: TransferPolicyContainer): PolicyBuilderBase
---Get Enemy scope policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:70 Enemy() implementation
---@field Enemy fun(self: TransferPolicyContainer): PolicyBuilderBase

---Command policy builders organized by command type
---@class CommandPolicyBuilders
---Get Guard command policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:115 Guard definition
---@field Guard fun(): CommandPolicyContainer
---Get Repair command policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:127 Repair definition
---@field Repair fun(): CommandPolicyContainer
---Get Reclaim command policy builder
---@see luarules/gadgets/team_transfer/api_gadgets.lua:134 Reclaim definition
---@field Reclaim fun(): CommandPolicyContainer

---Team event policy builders organized by event type
---@class TeamEventPolicyBuilders
---Get policy builder for player abandonment events
---@see luarules/gadgets/team_transfer/api_gadgets.lua:161 PlayerAbandoned definition
---@field PlayerAbandoned fun(): PolicyBuilderBase
---Get policy builder for team destruction events
---@see luarules/gadgets/team_transfer/api_gadgets.lua:164 TeamDestroyed definition
---@field TeamDestroyed fun(): PolicyBuilderBase
---Get policy builder for player reconnection events
---@see luarules/gadgets/team_transfer/api_gadgets.lua:167 PlayerReconnected definition
---@field PlayerReconnected fun(): PolicyBuilderBase

---Main policy builder with all configuration options
---@class PolicyBuilder
---Flat, scope-specific builder helpers (preferred API for discoverability)
---Create Guard command policy for Allied scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:113 GuardAllied implementation
---@field GuardAllied PolicyBuilderBase
---Create Guard command policy for Enemy scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:121 GuardEnemy implementation
---@field GuardEnemy PolicyBuilderBase
---Create Repair command policy for Allied scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:129 RepairAllied implementation
---@field RepairAllied PolicyBuilderBase
---Create Repair command policy for Enemy scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:137 RepairEnemy implementation
---@field RepairEnemy PolicyBuilderBase
---Create Reclaim command policy for Allied scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:145 ReclaimAllied implementation
---@field ReclaimAllied PolicyBuilderBase
---Create Reclaim command policy for Enemy scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:152 ReclaimEnemy implementation
---@field ReclaimEnemy PolicyBuilderBase
---Create Resource Transfer policy for Allied scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:159 ResourceTransferAllied implementation
---@field ResourceTransferAllied PolicyBuilderBase
---Create Resource Transfer policy for Enemy scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:165 ResourceTransferEnemy implementation
---@field ResourceTransferEnemy PolicyBuilderBase
---Create Unit Transfer policy for Allied scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:171 UnitTransferAllied implementation
---@field UnitTransferAllied PolicyBuilderBase
---Create Unit Transfer policy for Enemy scope
---@see luarules/gadgets/team_transfer/api_gadgets.lua:177 UnitTransferEnemy implementation
---@field UnitTransferEnemy PolicyBuilderBase




-- Policy Result Types

---Resource data for a single resource type (metal or energy)
---@class TeamResourceData
---@field current number Current amount of resource
---@field storage number Total storage capacity
---@field pull number Resource consumption rate
---@field income number Resource production rate
---@field expense number Resource spending rate
---@field shareSlider number Share slider position (0.0-1.0)

---Complete resource data for a team (both metal and energy)
---@class TeamResourcesData
---@field metal TeamResourceData Metal resource data
---@field energy TeamResourceData Energy resource data

---Result returned by prevent excessive share policy (expose-only)
---@class PreventExcessiveShareResult
---@field expose table<string, PreventExcessiveShareExpose> Expose data by transfer category

---Result returned by tax resource sharing policy (expose-only)
---@class TaxResourceSharingResult
---@field expose table<string, TaxResourceSharingExpose> Expose data by transfer category
