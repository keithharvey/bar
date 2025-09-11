-- Team Transfer API Widget
-- Reads cached data from GG and exposes sharing functions to WG

function widget:GetInfo()
	return {
		name = "Team Transfer API",
		desc = "Exposes Team Transfer sharing functions to WG",
		author = "BAR Team", 
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = true,
	}
end

-- Widget cache to store data received from gadgets
local teamTransferCache = {}

-- Receive data from gadgets via Script.LuaUI call
function TeamTransferExposeUpdate(teamID, exposeData)
	Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] Received data for team %d via Script.LuaUI", teamID))
	teamTransferCache[teamID] = exposeData
	
	-- Log cache state
	local keys = {}
	for k, _ in pairs(teamTransferCache) do
		table.insert(keys, tostring(k))
	end
	Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] Cache keys: [%s]", table.concat(keys, ", ")))
end

function widget:Initialize()
	-- Expose Team Transfer API to WG
	WG.TeamTransfer = {
		CanShareMetal = function(receiverTeamID)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].ResourceTransfer then
				local resourceData = teamTransferCache[receiverTeamID].ResourceTransfer
				return resourceData.metal and resourceData.metal.canShareMetal or false
			end
			return true  -- Default to allow
		end,
		
		CanShareEnergy = function(receiverTeamID)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].ResourceTransfer then
				local resourceData = teamTransferCache[receiverTeamID].ResourceTransfer
				return resourceData.energy and resourceData.energy.canShareEnergy or false
			end
			return true  -- Default to allow
		end,
		
		CanShareUnits = function(receiverTeamID, selectedUnits)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].UnitTransfer then
				local unitData = teamTransferCache[receiverTeamID].UnitTransfer
				
				-- If no units selected, return general policy
				if not selectedUnits or #selectedUnits == 0 then
					return unitData.canShareUnits or false
				end
				
				-- If units selected, check against global allowedUnits cache
				local allowedUnits = GG.TeamTransfer and GG.TeamTransfer.AllowedUnits or {}
				for _, unitID in ipairs(selectedUnits) do
					if Spring.ValidUnitID(unitID) then
						local unitDefID = Spring.GetUnitDefID(unitID)
						if unitDefID and allowedUnits[unitDefID] then
							return true  -- At least one unit is shareable
						end
					end
				end
				return false  -- No shareable units found in selection
			end
			return true  -- Default to allow
		end,
		
		GetResourceTransferData = function(receiverTeamID)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].ResourceTransfer then
				return teamTransferCache[receiverTeamID].ResourceTransfer
			end
			-- Return fallback data
			return {
				metal = { canShareMetal = true, maxMetalShareAmount = 5000, blockReason = nil },
				energy = { canShareEnergy = true, maxEnergyShareAmount = 5000, blockReason = nil }
			}
		end,
		
		GetUnitTransferData = function(receiverTeamID, selectedUnits)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].UnitTransfer then
				-- Return the policy data as-is (policies already calculated the correct values)
				return teamTransferCache[receiverTeamID].UnitTransfer
			end
			-- Return fallback data
			return {
				canShareUnits = true,
				shareableUnitCount = selectedUnits and #selectedUnits or 0,
				unshareableUnitCount = 0,
				blockReason = nil
			}
		end,
		
		-- Additional required functions for compatibility
		GetMaxMetalAmount = function(receiverTeamID)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].ResourceTransfer then
				local resourceData = teamTransferCache[receiverTeamID].ResourceTransfer
				return resourceData.metal and resourceData.metal.maxShareAmount
			end
			return 5000
		end,
		
		GetMaxEnergyAmount = function(receiverTeamID)
			if teamTransferCache[receiverTeamID] and teamTransferCache[receiverTeamID].ResourceTransfer then
				local resourceData = teamTransferCache[receiverTeamID].ResourceTransfer
				return resourceData.energy and resourceData.energy.maxShareAmount or 5000
			end
			return 5000
		end,
		
		handleShareButtonClick = function(targetTeamID)
			Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] handleShareButtonClick called for team %d", targetTeamID))
		end,
		
		validateShareCommand = function()
			return true
		end,
		
		ShareEnergy = function(receiverTeamID, amount, receiverName)
			Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] ShareEnergy: %d, amount=%d", receiverTeamID, amount))
			Spring.ShareResources(receiverTeamID, "energy", amount)
		end,
		
		ShareMetal = function(receiverTeamID, amount, receiverName) 
			Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] ShareMetal: %d, amount=%d", receiverTeamID, amount))
			Spring.ShareResources(receiverTeamID, "metal", amount)
		end,
		
		ShareUnits = function(receiverTeamID, selectedUnitIDs, receiverName)
			Spring.Log("TeamTransfer", LOG.ERROR, string.format("[API_TEAM_TRANSFER] ShareUnits: %d, units=%d", receiverTeamID, #selectedUnitIDs))
			for _, unitID in ipairs(selectedUnitIDs) do
				Spring.TransferUnit(unitID, receiverTeamID, false)
			end
		end,
		
		-- Stub implementations for missing fields
		Enums = {},
		ForAlliedResourceTransfers = function() return true end,
		ForEnemyResourceTransfers = function() return true end,
		ForAlliedUnitTransfers = function() return true end,
		ForEnemyUnitTransfers = function() return true end,
		CanTransfer = function() return true end,
		IsSharingOption = function() return true end,
		MODOPTION_KEYS = {},
		Policies = {},
		ResourceShareTax = {},
		UnitSharing = {}
		
	}
	
	Spring.Log("TeamTransfer", LOG.ERROR, "[API_TEAM_TRANSFER] WG.TeamTransfer API exposed successfully")
end

function widget:Shutdown()
	WG.TeamTransfer = nil
end