-- Comprehensive type definitions for Team Transfer API
-- This file is for intellisense only and should not be executed
-- Covers both synced (gadget) and unsynced (widget) APIs

-- Enum-like type aliases (since Lua doesn't have native enums)
-- These provide IntelliSense autocomplete and type checking for enum values
-- Use these instead of generic 'string' types where enum values are expected

---Legacy policy types - DEPRECATED, use TransferCategory instead
---@deprecated Use TransferCategory instead
---@alias PolicyType "resource_transfer" | "unit_transfer" | "command" | "team_event"

---Transfer categories for expose data organization (PascalCase keys, snake_case values)
---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "command_validation" | "team_events"

---Resource types supported by the engine (PascalCase keys, Spring engine values)
---@alias ResourceType "metal" | "energy"

---Predicate scopes for team relationship queries (PascalCase keys, snake_case values)
---@alias PredicateScope "allied" | "enemy"

---Gadget API for Team Transfer system - provides policy registration and execution
---@class TeamTransferGadgetAPI

---Global gadget-to-gadget communication table
---@class GG
---@field TeamTransfer TeamTransferGadgetAPI

---UI scope for querying transfer capabilities
---@class PredicateUIScope
---@field GetExposeData fun(senderTeamID: number, receiverTeamID: number): ResourceTransferResult|UnitTransferResult


---Widget API for Team Transfer system - provides read-only access to transfer capabilities
---@class TeamTransferWidgetAPI
---@field Enums TeamTransferSharedEnums ---@see TeamTransferSharedEnums Use WG.TeamTransfer.Enums.PolicyType.ResourceTransfer instead of strings
---@field ForAlliedResourceTransfers PredicateUIScope Allied resource transfer queries
---@field ForEnemyResourceTransfers PredicateUIScope Enemy resource transfer queries  
---@field ForAlliedUnitTransfers PredicateUIScope Allied unit transfer queries
---@field ForEnemyUnitTransfers PredicateUIScope Enemy unit transfer queries
---@field CanTransfer fun(senderTeamID: number, receiverTeamID: number, transferCategory: TransferCategory, selectedUnitIDs: number[]?): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field CanShareMetal fun(senderTeamID: number, receiverTeamID: number): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field CanShareEnergy fun(senderTeamID: number, receiverTeamID: number): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field CanShareUnits fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[]): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field GetMaxMetalAmount fun(senderTeamID: number, receiverTeamID: number): number @see luarules/gadgets/team_transfer/api_widgets.lua
---@field GetMaxEnergyAmount fun(senderTeamID: number, receiverTeamID: number): number @see luarules/gadgets/team_transfer/api_widgets.lua
---@field GetResourceTransferData fun(senderTeamID: number, receiverTeamID: number): ResourceTransferResult @see luarules/gadgets/team_transfer/api_widgets.lua
---@field GetUnitTransferData fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[]): UnitTransferResult @see luarules/gadgets/team_transfer/api_widgets.lua
---@field handleShareButtonClick fun(targetTeamID: number): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field validateShareCommand fun(): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field IsSharingOption fun(optionName: string): boolean @see luarules/gadgets/team_transfer/api_widgets.lua
---@field MODOPTION_KEYS table
---@field Policies table
---@field ResourceShareTax table
---@field UnitSharing table
---@field ShareEnergy fun(senderTeamID: number, receiverTeamID: number, amount: number, receiverName: string): nil @see luarules/gadgets/team_transfer/api_widgets.lua
---@field ShareMetal fun(senderTeamID: number, receiverTeamID: number, amount: number, receiverName: string): nil @see luarules/gadgets/team_transfer/api_widgets.lua
---@field ShareUnits fun(senderTeamID: number, receiverTeamID: number, selectedUnitIDs: number[], receiverName: string): nil @see luarules/gadgets/team_transfer/api_widgets.lua

---Global widget-to-widget communication table with Team Transfer API
---@class WG
---@field TeamTransfer TeamTransferWidgetAPI

---Default Result data calculated by pipeline for each transfer category
---@class DefaultUnitTransferResult
---@field canShareUnits boolean Whether unit sharing is possible (based on sharing mode and team relationship)
---@field takeBypass boolean Whether take bypass is available for this team pair

---Default Result data calculated by pipeline for each transfer category
---@class DefaultCommandValidationResult
---@field allowGuardComm    nds boolean Whether guard commands are allowed
---@field allowRepairCommands boolean Whether repair commands are allowed
---@field allowReclaimCommands boolean Whether reclaim commands are allowed

---Default Result data calculated by pipeline for each transfer category
---@class DefaultTeamEventsResult
---@field canProcessEvent boolean Whether the event can be processed

---@class TeamTransferPolicyContext
---@field lastResult? TeamTransferResultTable Result from previous policy in dependency chain
---@field senderTeamId number Sender team ID
---@field receiverTeamId number Receiver team ID
---@field areAlliedTeams boolean Whether sender and receiver are allied
---@field isCheatingEnabled boolean Whether cheating is enabled
---@field gameFrame number Current game frame
---@field resources { sender: TeamResourcesData, receiver: TeamResourcesData }
---Default Result data pre-calculated by pipeline - policies can use or override these
---@field defaultMetalTransfer DefaultMetalTransferResult Default metal transfer calculations
---@field defaultEnergyTransfer DefaultEnergyTransferResult Default energy transfer calculations  
---@field defaultUnitTransfer DefaultUnitTransferResult Default unit transfer calculations
---@field defaultCommandValidation DefaultCommandValidationResult Default command validation
---@field defaultTeamEvents DefaultTeamEventsResult Default team event processing

---@class TeamTransferApplyCommands
---@field ClearLoad? number[] -- unitIDs to clear load orders from
---@field ClearSelfD? number[] -- unitIDs to clear self-destruct orders from
---@field ClearTeamSelfD? number[] -- teamIDs to clear all self-destruct orders from
---@field RemoveCommands? {unitID: number, cmdID: number, options?: string[]}[] -- commands to remove from units
---@field GiveCommands? {unitID: number, cmdID: number, params?: number[], options?: string[]}[] -- new commands to give to units

-- Default Policy Result Types - All policies must extend these base types
-- These define the minimum required fields that every policy must provide
---Default metal transfer policy result - all metal transfer policies must extend this

---Default energy transfer policy result - all energy transfer policies must extend this

---@class DefaultResourceTransferResult
---@field amountSendable number Maximum metal that can be sent based on sender resources and receiver capacity
---@field canShare boolean Whether metal sharing is possible (based on amounts > 0)
---Default expose data calculated by pipeline for each transfer category
---@see luarules/gadgets/team_transfer/default_policies/metal_transfer.lua
---@class DefaultMetalTransferResult : DefaultResourceTransferResult

---@see luarules/gadgets/team_transfer/default_policies/energy_transfer.lua
---@class DefaultEnergyTransferResult : DefaultResourceTransferResult


---Default unit transfer policy result - all unit transfer policies must extend this
---@see luarules/gadgets/team_transfer/default_policies/unit_transfer.lua
---@class DefaultUnitTransferResult
---@field canShareUnits boolean Whether unit sharing is allowed (required by pipeline)
---@field blockReason string? Reason why sharing is blocked (if blocked)

---Default command validation policy result - all command policies must extend this
---@see luarules/gadgets/team_transfer/default_policies/command_validation.lua
---@class DefaultCommandValidationResult
---@field allowGuardCommands boolean Whether guard commands are allowed (required by pipeline) @see luarules/gadgets/team_transfer/pipeline.lua Pipeline.GetAllowGuardCommands
---@field allowRepairCommands boolean Whether repair commands are allowed (required by pipeline) @see luarules/gadgets/team_transfer/pipeline.lua Pipeline.GetAllowRepairCommands
---@field allowReclaimCommands boolean Whether reclaim commands are allowed (required by pipeline) @see luarules/gadgets/team_transfer/pipeline.lua Pipeline.GetAllowReclaimCommands
---@field blockReason string? Reason why commands are blocked (if blocked) @see luarules/gadgets/team_transfer/pipeline.lua Pipeline.GetBlockReason

---Default team events policy result - all team event policies must extend this
---@see luarules/gadgets/team_transfer/default_policies/team_events.lua
---@class DefaultTeamEventsResult
---@field canProcessEvent boolean Whether the event can be processed (required by pipeline)
---@field blockReason string? Reason why event processing is blocked (if blocked)

---@see luarules/gadgets/team_transfer/policies/unit_sharing_mode.lua
---@class UnitSharingModeResult : DefaultUnitTransferResult
---@field sharingMode string Current sharing mode (for UI/validator use)
---@field allowedUnits table<number, boolean> UnitDefID -> boolean mapping (for validator use)

---@see luarules/gadgets/team_transfer/policies/resource_tax.lua
---@class ResourceTaxExpose
---@field taxRate number The tax rate applied (0.0 to 1.0)
---@field taxedAmount number The amount after tax is applied
---@field taxCollected number The amount collected as tax

---@see luarules/gadgets/team_transfer/policies/metal_send_threshold.lua
---@class MetalSendThresholdResult : DefaultMetalTransferResult

---@see luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua
---@class TaxResourceSharing

---@class 

---@see luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua
---@class TaxResourceSharingMetalResult : DefaultMetalTransferResult
---@field taxRate number Tax rate applied to metal transfers (0.0 to 1.0)

---@see luarules/gadgets/team_transfer/policies/tax_resource_sharing.lua
---@class TaxResourceSharingEnergyResult : DefaultEnergyTransferResult
---@field taxRate number Tax rate applied to energy transfers (0.0 to 1.0)

---@see luarules/gadgets/team_transfer/policies/enemy_transfer.lua
---@class EnemyUnitTransferResult : UnitTransferResult

---@class MetalTransferResult : TaxResourceSharingMetalResult
---@field metalThreshold number Cumulative metal threshold

---@class EnergyTransferResult
---@field maxEnergyShareAmount number Maximum energy that can be shared to this specific receiver
---@field canShareEnergy boolean Whether energy sharing is allowed to this receiver
---@field blockReason string? Reason why energy sharing is blocked (if blocked)
---@field taxRate number? Tax rate applied to energy transfers (if applicable)
---@field energyThreshold number? Cumulative energy threshold (if applicable)hitting limits

---@class ResourceTransferResult
---@field metal MetalTransferResult Metal-specific transfer data
---@field energy EnergyTransferResult Energy-specific transfer data

---@class UnitTransferResult
---@field canShareUnits boolean Whether unit sharing is allowed to this receiver
---@field blockReason string? Reason why sharing is blocked (if canShareUnits is false)

---@class CommandResult
---@field allowGuardCommands boolean Whether guard commands to allies are allowed
---@field allowRepairCommands boolean Whether repair commands to allies are allowed  
---@field allowReclaimCommands boolean Whether reclaim commands to allies are allowed

---@class UnitTransferValidationResult : UnitTransferResult
---@field shareableUnitCount number
---@field unshareableUnitCount number

---Combined expose output for all transfer types - used by QueryExposeByPredicates
---@class CombinedExposeOutput
---@field CommandValidation DefaultCommandValidationResult
---@field UnitTransfer DefaultUnitTransferResult
---@field MetalTransfer DefaultMetalTransferResult
---@field EnergyTransfer DefaultEnergyTransferResult

---@class TeamTransferResultTable
---@field allow? boolean
---@field deny? boolean
---@field expose? table


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
---@see luarules/gadgets/team_transfer/fluent_policy.lua Guard definition
---@field Guard fun(): CommandPolicyContainer
---Get Repair command policy builder
---@see luarules/gadgets/team_transfer/fluent_policy.lua Repair definition
---@field Repair fun(): CommandPolicyContainer
---Get Reclaim command policy builder
---@see luarules/gadgets/team_transfer/fluent_policy.lua Reclaim definition
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
---@see luarules/gadgets/team_transfer/fluent_policy.lua GuardAllied implementation
---@field GuardAllied PolicyBuilderBase
---Create Guard command policy for Enemy scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua GuardEnemy implementation
---@field GuardEnemy PolicyBuilderBase
---Create Repair command policy for Allied scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua RepairAllied implementation
---@field RepairAllied PolicyBuilderBase
---Create Repair command policy for Enemy scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua RepairEnemy implementation
---@field RepairEnemy PolicyBuilderBase
---Create Reclaim command policy for Allied scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua ReclaimAllied implementation
---@field ReclaimAllied PolicyBuilderBase
---Create Reclaim command policy for Enemy scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua ReclaimEnemy implementation
---@field ReclaimEnemy PolicyBuilderBase
---Create Resource Transfer policy for Allied scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua ResourceTransferAllied implementation
---@field ResourceTransferAllied PolicyBuilderBase
---Create Resource Transfer policy for Enemy scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua ResourceTransferEnemy implementation
---@field ResourceTransferEnemy PolicyBuilderBase
---Create Unit Transfer policy for Allied scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua UnitTransferAllied implementation
---@field UnitTransferAllied PolicyBuilderBase
---Create Unit Transfer policy for Enemy scope
---@see luarules/gadgets/team_transfer/fluent_policy.lua UnitTransferEnemy implementation
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

---@class UnitTransferValidationResult
---@field canShare boolean Whether unit sharing is possible
---@field shareableCount number Number of currently selected units that can be shared
---@field unshareableCount number Number of currently selected units that cannot be shared
---@field blockReason string? Reason why sharing is blocked (if blocked)

-- Pipeline Function Signatures with Strong Typing

---Pipeline initialization function
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.Initialize
---@param transferCategory TransferCategory The transfer category to initialize
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param options table? Optional parameters (amount, unitIDs, etc.)
---@return table Pipeline evaluation result with expose data

---Pipeline resource transfer evaluation
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.RunResourceTransfer
---@param senderTeamId number The sender team ID
---@param receiverTeamId number The receiver team ID
---@param resourceType "metal"|"energy" The resource type
---@param amount number The transfer amount
---@return table? Expose data or nil if transfer not allowed

---Pipeline team event processing
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.RunTeamEvent
---@param eventType "PlayerAbandoned"|"TeamDestroyed"|"PlayerReconnected" The event type
---@param teamID number The team ID affected by the event
---@param playerID number? The player ID (if applicable)
---@param gameFrame number The current game frame
---@return table? Event processing result

---Pipeline expose data query by predicates
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.QueryExposeByPredicates
---@param predicateScope "allied"|"enemy" The predicate scope
---@param transferCategory TransferCategory The transfer category
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@return CombinedExposeOutput? Strongly-typed expose data for all transfer categories

---Pipeline expose data query for specific transfer category (automatically determines scope)
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.GetExpose
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param transferCategory TransferCategory The transfer category to query
---@return table The strongly-typed expose result based on transferCategory and active policies

---Pipeline unit transfer validation
---@see luarules/gadgets/team_transfer/pipeline.lua Pipeline.ValidateUnitTransfer
---@param senderTeamID number The sender team ID
---@param receiverTeamID number The receiver team ID
---@param unitID number? The unit ID being transferred
---@param unitDefID number? The unit definition ID
---@return boolean isValid Whether the transfer is valid

-- Validator Types for Category-Specific Registration

---Metal transfer validator function signature
---@alias MetalTransferValidator fun(ctx: TeamTransferPolicyContext, exposeResults: table<string, PolicyMetalTransferExpose>): boolean, string?, number?

---Energy transfer validator function signature  
---@alias EnergyTransferValidator fun(ctx: TeamTransferPolicyContext, exposeResults: table<string, PolicyEnergyTransferExpose>): boolean, string?, number?

---Unit transfer validator function signature
---@alias UnitTransferValidator fun(ctx: TeamTransferPolicyContext, exposeResults: table<string, PolicyUnitTransferExpose>): boolean, string?, number?

---Command validation validator function signature
---@alias CommandValidationValidator fun(ctx: TeamTransferPolicyContext, exposeResults: table<string, table>): boolean, string?, number?

---Team events validator function signature
---@alias TeamEventsValidator fun(ctx: TeamTransferPolicyContext, exposeResults: table<string, table>): boolean, string?, number?

-- Category-Specific Validator Registration Functions

---Register a metal transfer validator
---@see luarules/gadgets/team_transfer/policy_hooks.lua M.RegisterMetalTransferValidator
---@param validatorFn MetalTransferValidator The validator function
---@return nil

---Register an energy transfer validator
---@see luarules/gadgets/team_transfer/policy_hooks.lua M.RegisterEnergyTransferValidator
---@param validatorFn EnergyTransferValidator The validator function
---@return nil

---Register a unit transfer validator
---@see luarules/gadgets/team_transfer/policy_hooks.lua M.RegisterUnitTransferValidator
---@param validatorFn UnitTransferValidator The validator function
---@return nil

