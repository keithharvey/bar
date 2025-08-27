-- Unsynced helper functions for widgets to access Team Transfer functionality
-- This file provides READ-ONLY access to Team Transfer data via expose cache
-- Policy pipeline execution happens ONLY in synced context (gadgets)

---@load-file luaui/types/team_transfer.lua

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class TeamTransferWidgetAPIImpl : TeamTransferWidgetAPI
local M = {}

-- Policy expose data cache (receives data from synced gadget)
local exposeCache = {} -- teamID -> expose data

-- Flag to prevent spammy logging
local hasLoggedSystemNotReady = false

-- Receive policy expose data from synced gadget
local function updateExposeCache(_, teamID, exposeData)
	exposeCache[teamID] = exposeData
end

-- Register to receive expose data updates from gadget
if gadgetHandler and gadgetHandler.AddSyncAction then
	gadgetHandler:AddSyncAction("TeamTransferExposeUpdate", updateExposeCache)
end

-- Include the core modules directly (these are stateless utility modules)
local ResourceShareTax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
local UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Policy type shortcuts for cleaner code
local PolicyType = SharedEnums.PolicyType
local TransferCategory = SharedEnums.TransferCategory

-- Unsynced sharing mode check helper
local sharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")

local function isSharingOption(modoptionKey)
	if not modoptionKey then return false, nil end
	local modOpts = Spring.GetModOptions()
	return sharingModeUtils.isOptionEnabledInCurrentMode(modoptionKey), modOpts[modoptionKey]
end

-- Resource Share Tax helpers
M.ResourceShareTax = {
	computeTransfer = function(...)
		return ResourceShareTax.computeTransfer(...)
	end
}

-- Unit Sharing helpers that work in unsynced context
M.UnitSharing = {
	getUnitSharingMode = function()
		return UnitSharing.getUnitSharingMode()
	end,
	countUnshareable = function(...)
		return UnitSharing.countUnshareable(...)
	end,
	shouldShowShareButton = function(...)
		return UnitSharing.shouldShowShareButton(...)
	end,
	blockMessage = function(...)
		return UnitSharing.blockMessage(...)
	end,
	isUnitShareAllowedByMode = function(...)
		return UnitSharing.isUnitShareAllowedByMode(...)
	end,
}

-- Direct access helpers (for backward compatibility)
M.getUnitSharingMode = M.UnitSharing.getUnitSharingMode
M.countUnshareable = M.UnitSharing.countUnshareable
M.shouldShowShareButton = M.UnitSharing.shouldShowShareButton
M.blockMessage = M.UnitSharing.blockMessage
M.isUnitShareAllowedByMode = M.UnitSharing.isUnitShareAllowedByMode
M.computeTransfer = M.ResourceShareTax.computeTransfer

---Handle share button click with full validation and unit sharing
---Performs complete workflow: validates sharing mode, checks selected units,
---shows appropriate error messages, and executes the share if allowed
---@param targetTeamID number The team ID to share units to
---@return boolean success Whether the share was executed successfully
---@see TeamTransferAPI.handleShareButtonClick @ luaui/types/team_transfer.lua:101
M.handleShareButtonClick = function(targetTeamID)
	local unitSharingMode = UnitSharing.getUnitSharingMode()
	if unitSharingMode == "disabled" then
		Spring.Echo(UnitSharing.blockMessage(nil, unitSharingMode))
		return false
	end
	
	local selected = Spring.GetSelectedUnits()
	local shareable, unshareable, total = UnitSharing.countUnshareable(selected, unitSharingMode)
	if total > 0 and shareable == 0 then
		Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
		return false
	end
	
	if unshareable and unshareable > 0 then
		Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
	end
	
	Spring.ShareResources(targetTeamID, "units")
	Spring.PlaySoundFile("beep4", 1)
	return true
end

---Validate whether a share command should proceed based on sharing mode
---Checks current sharing mode restrictions and selected units,
---displays appropriate error messages for invalid attempts
---@return boolean valid Whether the command should be allowed to proceed
---@see TeamTransferAPI.validateShareCommand @ luaui/types/team_transfer.lua:103
M.validateShareCommand = function()
	local unitSharingMode = UnitSharing.getUnitSharingMode()
	if unitSharingMode == "disabled" then
		Spring.Echo(UnitSharing.blockMessage(nil, unitSharingMode))
		return false
	end
	
	if unitSharingMode == "t2cons" then
		local selected = Spring.GetSelectedUnits()
		local shareable, unshareable, total = UnitSharing.countUnshareable(selected, unitSharingMode)
		if total > 0 and shareable == 0 then
			Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
			return false
		end
		if unshareable > 0 then
			Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
		end
	end
	
	return true
end

-- Policy expose API functions
---Get all expose data for a specific team
---@param teamID number
---@return table
M.GetTeamExposeData = function(teamID)
	return exposeCache[teamID] or {}
end

---Get expose data from a specific policy for a team
---@param teamID number  
---@param policyName string Policy name (use M.Policies.* constants)
---@return any Policy-specific expose data
M.GetPolicyExpose = function(teamID, policyName)
	local teamData = exposeCache[teamID] or {}
	local expose = teamData.expose or {}
	
	-- Use the policy enum value directly as the field name
	local policies = SharedEnums.Policies
	local fieldName = policies[policyName] or policyName
	return expose[fieldName]
end

---Get unified resource transfer state for UI (reads current cached state)
---Calculate max energy amount for a specific receiver
---@param senderTeamID number
---@param receiverTeamID number
---@return number maxEnergyAmount
local function calculateMaxEnergyAmount(senderTeamID, receiverTeamID)
	-- Get receiver's energy storage capacity and current amount
	local eCur, eStor, ePull, eInc, eExp, eShare = Spring.GetTeamResources(receiverTeamID, SharedEnums.ResourceType.ENERGY)
	return math.max(0, eStor * eShare - eCur)
end

---@param teamID number
---@return ResourceTransferExposeOutput? Direct pipeline output with proper types
M.GetResourceTransferState = function(teamID)
	-- Use predicate-based cache query for allied resource transfers (most common UI case)
	local pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
	local exposeData = pipeline.QueryExposeByPredicates("allied", SharedEnums.PolicyType.ResourceTransfer, teamID, teamID)
	
	-- Return the properly typed pipeline output directly, or nil if not available
	---@type ResourceTransferExposeOutput?
	return exposeData
end

-- Legacy methods removed - use new simplified API instead

-- Preview API removed - pipeline handles messaging directly after transfers



-- Expose utilities
M.IsSharingOption = isSharingOption
-- Legacy: MODOPTION_KEYS is now just SharedEnums.Policies
M.MODOPTION_KEYS = SharedEnums.Policies
M.Policies = SharedEnums.Policies

-- Predicate-based UI interface that mirrors the policy system
-- This provides a clean, consistent interface for widgets to query transfer capabilities

---@class PredicateUIScope
---@field CanShare fun(senderTeamID: number): boolean Check if sharing is allowed for this predicate scope
---@field GetExposeData fun(senderTeamID: number): table Get combined expose data for this predicate scope
---@field GetTransferState fun(senderTeamID: number): ResourceTransferUIState Get transfer state (resource transfers only)

---@return PredicateUIScope
local function createPredicateUIScope(predicateScope, transferType)
	local scope = {}
	
	---Check if sharing is allowed for this predicate combination to a specific receiver
	---@param senderTeamID number
	---@param receiverTeamID number
	---@return boolean canShare
	scope.CanShare = function(senderTeamID, receiverTeamID)
		-- This is a widget API - it should use WG.TeamTransfer bridge, not access GG directly
		-- For now, return a placeholder until proper widget bridge integration
		return false -- TODO: Implement proper widget bridge communication
	end
	
	---Get combined expose data for this predicate combination to a specific receiver
	---@param senderTeamID number
	---@param receiverTeamID number
	---@return ResourceTransferExposeOutput|UnitTransferExposeOutput exposeData
	scope.GetExposeData = function(senderTeamID, receiverTeamID)
		-- This is a widget API - it should use WG.TeamTransfer bridge, not access GG directly
		-- For now, return empty data until proper widget bridge integration
		return {} -- TODO: Implement proper widget bridge communication
	end
	
	-- Only add GetTransferState for resource transfers
	if transferType == SharedEnums.PolicyType.ResourceTransfer then
		---Get resource transfer state for this predicate combination to a specific receiver
		---@param senderTeamID number
		---@param receiverTeamID number
		---@return ResourceTransferExposeOutput
		scope.GetTransferState = function(senderTeamID, receiverTeamID)
			local exposeData = scope.GetExposeData(senderTeamID, receiverTeamID)
			---@cast exposeData ResourceTransferExposeOutput
			return exposeData or {
				metal = { canShareMetal = false, maxMetalShareAmount = 0 },
				energy = { canShareEnergy = false, maxEnergyShareAmount = 0 }
			}
		end
	end
	
	return scope
end

-- Add predicate-based UI scopes to the main API

---@param senderTeamID number
---@param receiverTeamID number  
---@param transferCategory TransferCategory Use SharedEnums.TransferCategory values
---@param selectedUnitIDs number[]? Required for unit transfers
---@return ResourceTransferExposeOutput|UnitTransferExposeOutput
local function queryTransfer(senderTeamID, receiverTeamID, transferCategory, selectedUnitIDs)
	-- This function should not exist - widgets should use WG.TeamTransfer directly
	error("queryTransfer is deprecated - use WG.TeamTransfer API methods directly")
end

---Check if a transfer is allowed
---@param senderTeamID number
---@param receiverTeamID number
---@param transferCategory TransferCategory Use SharedEnums.TransferCategory values  
---@param selectedUnitIDs number[]? Required for unit transfers
---@return boolean isAllowed
M.CanTransfer = function(senderTeamID, receiverTeamID, transferCategory, selectedUnitIDs)
	if transferCategory == SharedEnums.TransferCategory.MetalTransfer then
		local canShare, _ = M.CanShareMetal(senderTeamID, receiverTeamID)
		return canShare
	elseif transferCategory == SharedEnums.TransferCategory.EnergyTransfer then
		local canShare, _ = M.CanShareEnergy(senderTeamID, receiverTeamID)
		return canShare
	elseif transferCategory == SharedEnums.TransferCategory.UnitTransfer then
		return M.CanShareUnits(senderTeamID, receiverTeamID, selectedUnitIDs or {})
	end
	
	return false
end

---Check if metal sharing is allowed and get block reason
---@param senderTeamID number
---@param receiverTeamID number
---@return boolean canShareMetal
---@return string? blockReason Reason why sharing is blocked (if blocked)
M.CanShareMetal = function(senderTeamID, receiverTeamID)
	-- Access expose data directly from cache/state
	local exposeData = M.GetResourceTransferData(senderTeamID, receiverTeamID)
	if exposeData and exposeData.metal then
		return exposeData.metal.canShareMetal, exposeData.metal.blockReason
	else
		return false, "No metal transfer data available"
	end
end

---Check if energy sharing is allowed and get block reason
---@param senderTeamID number
---@param receiverTeamID number
---@return boolean canShareEnergy
---@return string? blockReason Reason why sharing is blocked (if blocked)
M.CanShareEnergy = function(senderTeamID, receiverTeamID)
	-- Access expose data directly from cache/state
	local exposeData = M.GetResourceTransferData(senderTeamID, receiverTeamID)
	if exposeData and exposeData.energy then
		return exposeData.energy.canShareEnergy, exposeData.energy.blockReason
	else
		return false, "No energy transfer data available"
	end
end

---Check if unit sharing is allowed
---@param senderTeamID number
---@param receiverTeamID number
---@param selectedUnitIDs number[] Currently selected unit IDs
---@return boolean canShareUnits
M.CanShareUnits = function(senderTeamID, receiverTeamID, selectedUnitIDs)
	local exposeData = M.GetUnitTransferData(senderTeamID, receiverTeamID, selectedUnitIDs)
	return exposeData and exposeData.canShareUnits == true
end

---Get maximum metal amount that can be shared
---@param senderTeamID number
---@param receiverTeamID number
---@return number maxMetalAmount
M.GetMaxMetalAmount = function(senderTeamID, receiverTeamID)
	local exposeData = M.GetResourceTransferData(senderTeamID, receiverTeamID)
	return exposeData.metal and exposeData.metal.maxMetalShareAmount or 0
end

---Get maximum energy amount that can be shared
---@param senderTeamID number
---@param receiverTeamID number
---@return number maxEnergyAmount
M.GetMaxEnergyAmount = function(senderTeamID, receiverTeamID)
	local exposeData = M.GetResourceTransferData(senderTeamID, receiverTeamID)
	return exposeData.energy and exposeData.energy.maxEnergyShareAmount or 0
end

---Get full resource transfer data
---@param senderTeamID number
---@param receiverTeamID number
---@return ResourceTransferExposeOutput
M.GetResourceTransferData = function(senderTeamID, receiverTeamID)
	-- Access cached expose data from the bridge widget
	if WG.TeamTransfer and WG.TeamTransfer.GetResourceTransferData then
		return WG.TeamTransfer.GetResourceTransferData(senderTeamID, receiverTeamID)
	else
		-- Fallback: return empty structure
		return {
			metal = { canShareMetal = false, maxMetalShareAmount = 0, blockReason = "API not available" },
			energy = { canShareEnergy = false, maxEnergyShareAmount = 0, blockReason = "API not available" }
		}
	end
end

---Get full unit transfer data
---@param senderTeamID number
---@param receiverTeamID number
---@param selectedUnitIDs number[] Currently selected unit IDs
---@return UnitTransferExposeOutput
M.GetUnitTransferData = function(senderTeamID, receiverTeamID, selectedUnitIDs)
	-- Access cached expose data from the bridge widget
	if WG.TeamTransfer and WG.TeamTransfer.GetUnitTransferData then
		return WG.TeamTransfer.GetUnitTransferData(senderTeamID, receiverTeamID, selectedUnitIDs)
	else
		-- Fallback: return empty structure
		return {
			canShareUnits = false,
			shareableUnitCount = 0,
			unshareableUnitCount = #(selectedUnitIDs or {}),
			blockReason = "API not available"
		}
	end
end

-- Include resources module for sharing functionality
local Resources = VFS.Include("luarules/gadgets/team_transfer/resources.lua")

-- Expose resource and unit sharing methods
M.ShareEnergy = Resources.ShareEnergy
M.ShareMetal = Resources.ShareMetal
M.ShareUnits = Resources.ShareUnits

-- Clean enum interface instead of awkward SharedEnums
M.Enums = SharedEnums

---@return TeamTransferWidgetAPI
return M
