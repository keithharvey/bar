-- Team Transfer API Widget
-- Provides Team Transfer API to WG for other widgets

function widget:GetInfo()
	return {
		name = "Team Transfer API",
		desc = "Team Transfer API for widget communication",
		author = "BAR Team", 
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = true,
	}
end

-- Team Transfer API Widget

-- Widget cache to store data received from gadgets
local teamTransferCache = {}

-- Receive data from gadgets via Script.LuaUI call
function TeamTransferExposeUpdate(teamID, exposeData)
	Spring.Log("TeamTransfer", "info", string.format("[API_TEAM_TRANSFER] Received data for team %d", teamID))
	teamTransferCache[teamID] = exposeData
end

---@class TeamTransferAPI
local TeamTransferAPI = {}
TeamTransferAPI.__index = TeamTransferAPI

-- Core transfer function with tax calculation
---@param receiverTeamID number
---@param amount number
---@param receiverName string?
---@return boolean success
---@return table|string result Transfer breakdown or error message
function TeamTransferAPI.ShareMetal(receiverTeamID, amount, receiverName)
	if not receiverTeamID or not amount or amount <= 0 then
		return false, "Invalid parameters"
	end

	local senderTeamID = Spring.GetMyTeamID()

	-- Call service to handle transfer with full policy evaluation
	if Script.LuaRules and Script.LuaRules.TeamTransfer_ShareResource then
		local result = Script.LuaRules.TeamTransfer_ShareResource(senderTeamID, receiverTeamID, "metal", amount)
		if result then
			return result.success, result
		else
			return false, "TeamTransfer service unavailable"
		end
	end
end

-- Strongly typed data accessors

---Get metal transfer data
---@param receiverTeamID number
---@return MetalTransferResult
function TeamTransferAPI.GetMetalTransferData(receiverTeamID)
	local exposeData = teamTransferCache[receiverTeamID]
	if exposeData and exposeData.MetalTransfer then
		return exposeData.MetalTransfer
	end
	return { canShare = false, amountSendable = 0, blockReason = "No data available" }
end

---Get energy transfer data
---@param receiverTeamID number
---@return ResourcePolicyResult
function TeamTransferAPI.GetEnergyTransferData(receiverTeamID)
	local exposeData = teamTransferCache[receiverTeamID]
	if exposeData and exposeData.EnergyTransfer then
		return exposeData.EnergyTransfer
	end
	return { canShare = false, amountSendable = 0, blockReason = "No data available" }
end

---Get unit transfer data
---@param receiverTeamID number
---@return UnitTransferPolicyResult
function TeamTransferAPI.GetUnitTransferData(receiverTeamID)
	local exposeData = teamTransferCache[receiverTeamID]
	if exposeData and exposeData.UnitTransfer then
		return exposeData.UnitTransfer
	end
	return { canShareUnits = false, blockReason = "No data available" }
end

---Get policy expose data for transfer validation
---@param senderTeamID number
---@param receiverTeamID number
---@return CombinedPolicyResult
function TeamTransferAPI.GetPolicyExpose(senderTeamID, receiverTeamID)
	return teamTransferCache[receiverTeamID] or {
		MetalTransfer = { canShare = false, amountSendable = 0 },
		EnergyTransfer = { canShare = false, amountSendable = 0 },
		UnitTransfer = { canShareUnits = false }
	}
end

---Share energy with receiver team
---@param receiverTeamID number
---@param amount number
---@param receiverName string?
---@return boolean success
---@return table|string result Transfer result or error message
function TeamTransferAPI.ShareEnergy(receiverTeamID, amount, receiverName)
	if not receiverTeamID or not amount or amount <= 0 then
		return false, "Invalid parameters"
	end

	local senderTeamID = Spring.GetMyTeamID()

	-- Call service to handle transfer with full policy evaluation
	if Script.LuaRules and Script.LuaRules.TeamTransfer_ShareResource then
		local result = Script.LuaRules.TeamTransfer_ShareResource(senderTeamID, receiverTeamID, "energy", amount)
		if result then
			return result.success, result
		else
			return false, "TeamTransfer service unavailable"
		end
	else
		-- Fallback to simple transfer if service not available
		Spring.ShareResources(receiverTeamID, "energy", amount)
		return true, { success = true, sent = amount, received = amount }
	end
end

---Share units with receiver team
---@param receiverTeamID number
---@param selectedUnitIDs number[]
---@param receiverName string?
---@return boolean success
---@return string|number result Error message or number of units shared
function TeamTransferAPI.ShareUnits(receiverTeamID, selectedUnitIDs, receiverName)
	if not receiverTeamID or not selectedUnitIDs or #selectedUnitIDs == 0 then
		return false, "Invalid parameters"
	end
	
	-- Get cached expose data for validation
	local exposeData = teamTransferCache[receiverTeamID]
	if exposeData and exposeData.UnitTransfer then
		local unitData = exposeData.UnitTransfer
		
		if not unitData.canShareUnits then
			return false, unitData.blockReason or "Unit sharing not allowed"
		end
	end
	
	-- Execute unit transfers via clean wrapper exposed by gadget
	if Script.LuaRules and Script.LuaRules.TeamTransfer_ShareUnits then
		Script.LuaRules.TeamTransfer_ShareUnits(receiverTeamID, selectedUnitIDs)
	else
		Spring.Log("TeamTransfer", "error", "TeamTransfer_ShareUnits wrapper missing in LuaRules. Unit share aborted.")
		return false, "TeamTransfer unavailable"
	end
	
	return true, #selectedUnitIDs
end

---Handle share button click for units
---@param targetTeamID number
---@return boolean success
function TeamTransferAPI.handleShareButtonClick(targetTeamID)
	local selectedUnits = Spring.GetSelectedUnits()
	if not selectedUnits or #selectedUnits == 0 then
		return false
	end
	
	local success, result = TeamTransferAPI.ShareUnits(targetTeamID, selectedUnits)
	if success then
		Spring.PlaySoundFile("beep4", 1, 'ui')
	end
	return success
end

-- Unit sharing utility functions for compatibility

---Get current unit sharing mode
---@return string mode Current sharing mode
function TeamTransferAPI.getUnitSharingMode()
	local modOptions = Spring.GetModOptions()
	return modOptions and modOptions.unit_sharing_mode or "enabled"
end

---Count shareable vs unshareable units in selection
---@param selectedUnits number[]
---@param sharingMode string
---@return number shareable
---@return number unshareable  
---@return number total
function TeamTransferAPI.countUnshareable(selectedUnits, sharingMode)
	if not selectedUnits or #selectedUnits == 0 then
		return 0, 0, 0
	end
	
	local shareable = 0
	local unshareable = 0
	
	for _, unitID in ipairs(selectedUnits) do
		if Spring.ValidUnitID(unitID) then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if TeamTransferAPI.isUnitShareAllowedByMode(unitDefID, sharingMode) then
				shareable = shareable + 1
			else
				unshareable = unshareable + 1
			end
		end
	end
	
	return shareable, unshareable, #selectedUnits
end

---Check if a unit type is allowed by sharing mode
---@param unitDefID number
---@param sharingMode string?
---@return boolean allowed
function TeamTransferAPI.isUnitShareAllowedByMode(unitDefID, sharingMode)
	sharingMode = sharingMode or TeamTransferAPI.getUnitSharingMode()
	
	if sharingMode == "disabled" then
		return false
	elseif sharingMode == "enabled" then
		return true
	elseif sharingMode == "t2cons" then
		-- Only T2 constructors allowed
		local unitDef = UnitDefs[unitDefID]
		return unitDef and TeamTransferAPI.isT2Constructor(unitDef) or false
	end
	
	return false
end

---Check if unit definition is a T2 constructor
---@param unitDef table
---@return boolean isT2Constructor
function TeamTransferAPI.isT2Constructor(unitDef)
	if not unitDef then return false end
	-- Simple heuristic: T2 constructors typically have "t2" in name and can build
	local name = unitDef.name and unitDef.name:lower() or ""
	return name:find("t2") and unitDef.canBuild or false
end

---Check if share button should be shown for current selection
---@param selectedUnits number[]
---@param sharingMode string?
---@return boolean shouldShow
function TeamTransferAPI.shouldShowShareButton(selectedUnits, sharingMode)
	sharingMode = sharingMode or TeamTransferAPI.getUnitSharingMode()
	
	if sharingMode == "disabled" then
		return false
	end
	
	if not selectedUnits or #selectedUnits == 0 then
		return false
	end
	
	local shareable, _, _ = TeamTransferAPI.countUnshareable(selectedUnits, sharingMode)
	return shareable > 0
end

-- Legacy compatibility - expose UnitSharing submodule
TeamTransferAPI.UnitSharing = {
	isT2ConstructorDef = TeamTransferAPI.isT2Constructor
}

function widget:Initialize()
	-- Expose strongly typed Team Transfer API to WG
	WG.TeamTransfer = TeamTransferAPI
	
	Spring.Log("TeamTransfer", LOG.INFO, "[API_TEAM_TRANSFER] Strongly typed WG.TeamTransfer API exposed successfully")
end

function widget:Shutdown()
	WG.TeamTransfer = nil
end