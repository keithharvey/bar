-- Unsynced helper functions for widgets to access Team Transfer functionality
-- This file provides READ-ONLY access to Team Transfer data via expose cache
-- Policy pipeline execution happens ONLY in synced context (gadgets)

-- Shared logging utility
-- Removed shared_logging dependency
-- Removed Logger dependencies - using Spring.Log directly

Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Starting api_widgets.lua initialization")

---@load-file luaui/types/team_transfer.lua

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")

-- Helper function to get table keys (since Lua doesn't have table.keys)
local function tableKeys(t)
	if not t then return {} end
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, tostring(k))
	end
	return keys
end

-- Widget-side API provides expose-driven validation and thin transfer requests

---@class TeamTransferWidgetAPIImpl : TeamTransferWidgetAPI
local M = {}

local exposeCache = {}

-- Verify we're in unsynced context
if Spring.GetGameFrame then
	Spring.Log("[API_WIDGETS]", "error","[API_WIDGETS] WARNING: Detected synced context functions in unsynced widget!")
end

-- teamID -> expose data

-- Flag to prevent spammy logging
local hasLoggedSystemNotReady = false

-- Cache of recent query timestamps to prevent spam
local lastQueryTime = {}
local QUERY_COOLDOWN = 1000 -- 1 second cooldown between queries for the same team

-- Simplified cache structure: direct data by team ID
local resourceCache = {}  -- resourceCache[teamID] = ResourceTransfer data
local unitCache = {}      -- unitCache[teamID] = UnitTransfer data

-- Receive policy expose data from synced gadget
local function updateExposeCache(_, teamID, exposeData)
	Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Received expose data update for team %d", teamID))

	if not exposeData then
		Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] Received nil expose data for team %d", teamID))
		return
	end

	Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] ExposeData keys: %s", exposeData and table.concat(tableKeys(exposeData), ", ") or "none"))

	-- Store data in simplified cache structure
	if exposeData.ResourceTransfer then
		resourceCache[teamID] = exposeData.ResourceTransfer
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Cached ResourceTransfer data for team %d: %s", teamID, table.concat(tableKeys(exposeData.ResourceTransfer), ", ")))
	end
	
	if exposeData.UnitTransfer then
		unitCache[teamID] = exposeData.UnitTransfer
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Cached UnitTransfer data for team %d: %s", teamID, table.concat(tableKeys(exposeData.UnitTransfer), ", ")))
	end

	-- CRITICAL CACHE DEBUGGING: Log simplified cache state
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - Team %d data received", teamID))
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - Resource cache keys: [%s]", table.concat(tableKeys(resourceCache), ", ")))
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - Unit cache keys: [%s]", table.concat(tableKeys(unitCache), ", ")))

	-- Reset the logging flag since we now have data
	hasLoggedSystemNotReady = false
end

-- Public function for bridge widget to call
M.UpdateExposeCache = updateExposeCache

-- Note: RecvFromSynced is handled by the bridge widget, not this module

-- Include the core modules directly (these are stateless utility modules)
Spring.Log("[API_WIDGETS]", "info","[API_WIDGETS] Including core modules...")
local ResourceShareTax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Loaded resource_share_tax.lua")

local UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Loaded unit_sharing.lua")

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Loaded shared_enums.lua (second time)")

-- Transfer category shortcuts for cleaner code
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
	-- Return combined data from both caches
	local result = {}
	if resourceCache[teamID] then
		result.ResourceTransfer = resourceCache[teamID]
	end
	if unitCache[teamID] then
		result.UnitTransfer = unitCache[teamID]
	end
	return result
end

---Get expose data from a specific policy for a team
---@param teamID number  
---@param policyName string Policy name (use M.Policies.* constants)
---@return any Policy-specific expose data
M.GetPolicyExpose = function(teamID, policyName)
	-- Map policy names to appropriate cache
	if policyName == "ResourceTransfer" or policyName == "resource_transfer" then
		-- Legacy compatibility: return resource cache for backward compatibility
		return resourceCache[teamID]
	elseif policyName == "MetalTransfer" or policyName == "metal_transfer" then
		return resourceCache[teamID] -- Metal data is part of resource cache
	elseif policyName == "EnergyTransfer" or policyName == "energy_transfer" then
		return resourceCache[teamID] -- Energy data is part of resource cache
	elseif policyName == "UnitTransfer" or policyName == "unit_transfer" then
		return unitCache[teamID]
	end
	
	-- Fallback for other policy types
	return nil
end

---Get unified resource transfer state for UI (reads current cached state)
---Calculate max energy amount for a specific receiver
---@param senderTeamID number
---@param receiverTeamID number
---@return number maxEnergyAmount
local function calculateMaxEnergyAmount(senderTeamID, receiverTeamID)
	-- Use shared utility for consistent calculation
	local maxShare, _ = SharingUtils.ComputeMaxShare(receiverTeamID, SharedEnums.ResourceType.ENERGY)
	return maxShare
end

---@param teamID number
---@return ResourceTransferExposeOutput? Direct pipeline output with proper types
M.GetResourceTransferState = function(teamID)
	-- Use simplified resource cache
	local resourceData = resourceCache[teamID]
	if resourceData then
		return resourceData
	end
	
	-- Return fallback structure if no data available
	return {
		metal = { canShareMetal = false, maxMetalShareAmount = 0, blockReason = "No data available" },
		energy = { canShareEnergy = false, maxEnergyShareAmount = 0, blockReason = "No data available" }
	}
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
	if transferType == SharedEnums.TransferCategory.MetalTransfer or transferType == SharedEnums.TransferCategory.EnergyTransfer then
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
M.CanShareMetal = function(receiverTeamID)
	-- Access expose data directly from cache/state
	local exposeData = M.GetResourceTransferData(receiverTeamID)
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
M.CanShareEnergy = function(receiverTeamID)
	-- Access expose data directly from cache/state
	local exposeData = M.GetResourceTransferData(receiverTeamID)
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
M.CanShareUnits = function(receiverTeamID, selectedUnitIDs)
	local exposeData = M.GetUnitTransferData(receiverTeamID, selectedUnitIDs)
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
M.GetResourceTransferData = function(receiverTeamID)
	Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] GetResourceTransferData called - receiverTeamID=%s", tostring(receiverTeamID)))
	
	local myTeamID = Spring.GetLocalTeamID()
	
	-- Handle self-transfers for resources (these are resource requests, not transfers)
	if myTeamID == receiverTeamID then
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Self-request query: team %d requesting resources", myTeamID))
		-- For self-transfers, get current storage capacity as max request amount
		local _, metalStorage = Spring.GetTeamResources(myTeamID, "metal")
		local _, energyStorage = Spring.GetTeamResources(myTeamID, "energy")
		
		-- Use storage capacity or reasonable defaults for resource requests
		local maxMetal = metalStorage and math.max(metalStorage, 5000) or 5000
		local maxEnergy = energyStorage and math.max(energyStorage, 5000) or 5000
		
		return {
			metal = { canShareMetal = true, maxMetalShareAmount = maxMetal, blockReason = nil },
			energy = { canShareEnergy = true, maxEnergyShareAmount = maxEnergy, blockReason = nil }
		}
	end
	
	-- SIMPLIFIED CACHE: Look up ResourceTransfer data directly by receiverTeamID
	local resourceData = resourceCache[receiverTeamID]
	
	-- CRITICAL CACHE DEBUGGING: Log what we're looking for vs what we have
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - GetResourceTransferData looking for receiverTeamID=%d", receiverTeamID))
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - Resource cache keys: [%s]", table.concat(tableKeys(resourceCache), ", ")))
	
	if resourceData then
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Found cached ResourceTransfer data for team %d", receiverTeamID))
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] ResourceTransfer result keys: %s", table.concat(tableKeys(resourceData), ", ")))
		if resourceData.energy then
			Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Energy data - canShare: %s, maxAmount: %s, blockReason: %s",
				tostring(resourceData.energy.canShareEnergy), tostring(resourceData.energy.maxEnergyShareAmount), tostring(resourceData.energy.blockReason)))
		end
		if resourceData.metal then
			Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Metal data - canShare: %s, maxAmount: %s, blockReason: %s",
				tostring(resourceData.metal.canShareMetal), tostring(resourceData.metal.maxMetalShareAmount), tostring(resourceData.metal.blockReason)))
		end
		return resourceData
	else
		Spring.Log("[API_WIDGETS]", "info",string.format("[API_WIDGETS] No cached ResourceTransfer data for team %d", receiverTeamID))
		-- If no cached data, trigger on-demand query from synced side (with cooldown)
		local currentTime = Spring.GetTimer()
		local lastQuery = lastQueryTime["resource_" .. myTeamID]

		if not lastQuery or Spring.DiffTimers(currentTime, lastQuery) > QUERY_COOLDOWN then
			Spring.Log("[API_WIDGETS]", "info","[API_WIDGETS] Requesting resource data for team " .. tostring(myTeamID))
			Spring.SendLuaRulesMsg("query_resource_data:" .. myTeamID)
			lastQueryTime["resource_" .. myTeamID] = currentTime
		else
			local remaining = QUERY_COOLDOWN - Spring.DiffTimers(currentTime, lastQuery)
			Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Resource query cooldown active for team " .. tostring(myTeamID) ..
				" (" .. string.format("%.1f", remaining/1000) .. "s remaining)")
		end

		-- Return fallback structure while we wait for data
		return {
			metal = { canShareMetal = false, maxMetalShareAmount = 0, blockReason = "Data requested" },
			energy = { canShareEnergy = false, maxEnergyShareAmount = 0, blockReason = "Data requested" }
		}
	end
end

---Get full unit transfer data
---@param senderTeamID number
---@param receiverTeamID number
---@param selectedUnitIDs number[] Currently selected unit IDs
---@return UnitTransferExposeOutput
M.GetUnitTransferData = function(receiverTeamID, selectedUnitIDs)
	Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] GetUnitTransferData called - receiverTeamID=%s, selectedUnitCount=%s",
		tostring(receiverTeamID), selectedUnitIDs and tostring(#selectedUnitIDs) or "none"))
	
	local myTeamID = Spring.GetLocalTeamID()
	
	-- Reject self-transfers - they don't make logical sense
	if myTeamID == receiverTeamID then
		Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] Invalid self-transfer query: team %d -> %d", myTeamID, receiverTeamID))
		return {
			canShareUnits = false,
			shareableUnitCount = 0,
			unshareableUnitCount = #(selectedUnitIDs or {}),
			blockReason = "Invalid: self-transfer"
		}
	end
	
	-- For team-pair queries, we need to query the synced side directly since cache is single-team based
	Spring.SendLuaRulesMsg(string.format("query_unit_pair:%d,%d", myTeamID, receiverTeamID))
	
	-- Check GG.TeamTransferCache for the team pair result
	local cacheKey = string.format("team_%d_to_%d", myTeamID, receiverTeamID)
	local exposeData = nil
	if GG and GG.TeamTransferCache then
		exposeData = GG.TeamTransferCache[cacheKey]
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Checking GG.TeamTransferCache for key=%s - cache exists: %s",
			cacheKey, tostring(exposeData ~= nil)))
	else
		Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] GG.TeamTransferCache not available")
	end
	Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Checking exposeCache for myTeamID=%d - cache exists: %s",
		myTeamID, tostring(exposeData ~= nil)))
	
	-- CRITICAL CACHE DEBUGGING: Log what we're looking for vs what we have  
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - GetUnitTransferData looking for receiverTeamID=%d", receiverTeamID))
	Spring.Log("[API_WIDGETS]", "error",string.format("[API_WIDGETS] CACHE DEBUG - Unit cache keys: [%s]", table.concat(tableKeys(unitCache), ", ")))
	
	-- SIMPLIFIED CACHE: Look up UnitTransfer data directly by receiverTeamID
	local unitData = unitCache[receiverTeamID]
	
	if unitData then
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] Found cached UnitTransfer data for team %d", receiverTeamID))
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] UnitTransfer data keys: %s", table.concat(tableKeys(unitData), ", ")))
		Spring.Log("[API_WIDGETS]", "debug",string.format("[API_WIDGETS] UnitTransfer - canShare: %s, blockReason: %s",
			tostring(unitData.canShareUnits), tostring(unitData.blockReason)))

		-- If we have selectedUnitIDs, update counts based on current selection
		if selectedUnitIDs and #selectedUnitIDs > 0 then
			local shareableCount = 0
			local unshareableCount = 0

			for _, unitID in ipairs(selectedUnitIDs) do
				if Spring.ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == myTeamID then
					local unitDefID = Spring.GetUnitDefID(unitID)
					if unitDefID then
						-- Use the policy's allowedUnits cache if available
						local allowedUnits = unitData.allowedUnits or {}
						if allowedUnits[unitDefID] then
							shareableCount = shareableCount + 1
						else
							unshareableCount = unshareableCount + 1
						end
					end
				end
			end

			-- Return updated data with current selection counts
			return {
				canShareUnits = shareableCount > 0,
				shareableUnitCount = shareableCount,
				unshareableUnitCount = unshareableCount,
				blockReason = shareableCount == 0 and "No shareable units selected" or unitData.blockReason,
				allowedUnits = unitData.allowedUnits,
				sharingMode = unitData.sharingMode
			}
		end

		-- Return cached data as-is
		return unitData
	else
		Spring.Log("[API_WIDGETS]", "info",string.format("[API_WIDGETS] No cached UnitTransfer data for team %d", receiverTeamID))
		-- If no cached data, trigger on-demand query from synced side (with cooldown)
		local currentTime = Spring.GetTimer()
		local lastQuery = lastQueryTime["unit_" .. myTeamID]

		if not lastQuery or Spring.DiffTimers(currentTime, lastQuery) > QUERY_COOLDOWN then
			Spring.Log("[API_WIDGETS]", "info","[API_WIDGETS] Requesting unit data for team " .. tostring(myTeamID))
			Spring.SendLuaRulesMsg("query_unit_data:" .. myTeamID)
			lastQueryTime["unit_" .. myTeamID] = currentTime
		else
			local remaining = QUERY_COOLDOWN - Spring.DiffTimers(currentTime, lastQuery)
			Spring.Log("[API_WIDGETS]", "debug","[API_WIDGETS] Unit query cooldown active for team " .. tostring(myTeamID) ..
				" (" .. string.format("%.1f", remaining/1000) .. "s remaining)")
		end

		-- Fallback: return empty structure if no cached data
		return {
			canShareUnits = false,
			shareableUnitCount = 0,
			unshareableUnitCount = #(selectedUnitIDs or {}),
			blockReason = "Data requested"
		}
	end
end

---Check if a specific unit type is allowed to be shared
---@param unitDefID number Unit definition ID
---@param senderTeamID number? Team ID to check (defaults to current team)
---@return boolean isAllowed True if the unit type can be shared
M.IsUnitTypeAllowed = function(unitDefID, senderTeamID)
	local teamID = senderTeamID or Spring.GetLocalTeamID()
	local unitData = unitCache[teamID]

	if unitData and unitData.allowedUnits then
		return unitData.allowedUnits[unitDefID] == true
	end

	-- Fallback to utility function
	return UnitSharing.isUnitShareAllowedByMode(unitDefID)
end



-- Thin transfer request layer - sends to gadget for execution
M.ShareEnergy = function(senderTeamID, receiverTeamID, amount, receiverName)
	-- Validate inputs
	if not senderTeamID or not receiverTeamID or not amount or amount <= 0 then
		return false, "Invalid parameters"
	end
	
	-- Use expose data for client-side validation
	local canShare, blockReason = M.CanShareEnergy(senderTeamID, receiverTeamID)
	if not canShare then
		return false, blockReason or "Energy sharing not allowed"
	end
	
	-- Send request to gadget for execution
	if gadgetHandler and gadgetHandler.SyncAction then
		gadgetHandler:SyncAction("TeamTransferShareEnergy", {
			senderTeamID = senderTeamID,
			receiverTeamID = receiverTeamID,
			amount = amount,
			receiverName = receiverName or "Unknown"
		})
		return true, amount
	else
		return false, "Team Transfer system not available"
	end
end

M.ShareMetal = function(senderTeamID, receiverTeamID, amount, receiverName)
	-- Validate inputs
	if not senderTeamID or not receiverTeamID or not amount or amount <= 0 then
		return false, "Invalid parameters"
	end
	
	-- Use expose data for client-side validation
	local canShare, blockReason = M.CanShareMetal(senderTeamID, receiverTeamID)
	if not canShare then
		return false, blockReason or "Metal sharing not allowed"
	end
	
	-- Send request to gadget for execution
	if gadgetHandler and gadgetHandler.SyncAction then
		gadgetHandler:SyncAction("TeamTransferShareMetal", {
			senderTeamID = senderTeamID,
			receiverTeamID = receiverTeamID,
			amount = amount,
			receiverName = receiverName or "Unknown"
		})
		return true, amount
	else
		return false, "Team Transfer system not available"
	end
end

M.ShareUnits = function(senderTeamID, receiverTeamID, selectedUnitIDs, receiverName)
	-- Validate inputs
	if not senderTeamID or not receiverTeamID or not selectedUnitIDs or #selectedUnitIDs == 0 then
		return false, "Invalid parameters"
	end
	
	-- Use expose data for client-side validation
	local canShare, blockReason = M.CanShareUnits(senderTeamID, receiverTeamID, selectedUnitIDs)
	if not canShare then
		return false, blockReason or "Unit sharing not allowed"
	end
	
	-- Send request to gadget for execution
	if gadgetHandler and gadgetHandler.SyncAction then
		gadgetHandler:SyncAction("TeamTransferShareUnits", {
			senderTeamID = senderTeamID,
			receiverTeamID = receiverTeamID,
			selectedUnitIDs = selectedUnitIDs,
			receiverName = receiverName or "Unknown"
		})
		return true, #selectedUnitIDs
	else
		return false, "Team Transfer system not available"
	end
end

-- Clean enum interface instead of awkward SharedEnums
M.Enums = SharedEnums

Spring.Log("[API_WIDGETS]", "info","[API_WIDGETS] api_widgets.lua initialization completed successfully")

---@return TeamTransferWidgetAPI
return M
