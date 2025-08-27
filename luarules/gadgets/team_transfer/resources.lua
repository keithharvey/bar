---@class TeamTransferResources
local M = {}

-- Include shared enums for resource types
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---Share energy with unified validation and messaging
---@param senderTeamID number
---@param receiverTeamID number
---@param amount number
---@param receiverName string
M.ShareEnergy = function(senderTeamID, receiverTeamID, amount, receiverName)
	-- Handle self-requests (asking for energy)
	if receiverTeamID == senderTeamID then
		if amount == 0 then
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needEnergy')
		else
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needEnergyAmount:amount='..amount)
		end
		return
	end
	
	-- Validate energy sharing is allowed
	local canShare, blockReason = WG.TeamTransfer.CanShareEnergy(senderTeamID, receiverTeamID)
	if not canShare then
		Spring.Echo(Spring.I18N('ui.teamTransfer.energySharing.blocked', { reason = blockReason or Spring.I18N('ui.teamTransfer.energySharing.notAllowed') }))
		return
	end
	
	-- Execute the share if amount > 0
	if amount > 0 then
		Spring.ShareResources(receiverTeamID, SharedEnums.ResourceType.ENERGY, amount)
		Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..amount..':name='..receiverName)
		WG.sharedEnergyFrame = Spring.GetGameFrame()
	end
end

---Share metal with unified validation and messaging
---@param senderTeamID number
---@param receiverTeamID number
---@param amount number
---@param receiverName string
M.ShareMetal = function(senderTeamID, receiverTeamID, amount, receiverName)
	-- Handle self-requests (asking for metal)
	if receiverTeamID == senderTeamID then
		if amount == 0 then
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needMetal')
		else
			Spring.SendLuaRulesMsg('msg:ui.playersList.chat.needMetalAmount:amount='..amount)
		end
		return
	end
	
	-- Validate metal sharing is allowed
	local canShare, blockReason = WG.TeamTransfer.CanShareMetal(senderTeamID, receiverTeamID)
	if not canShare then
		Spring.Echo(Spring.I18N('ui.teamTransfer.metalSharing.blocked', { reason = blockReason or Spring.I18N('ui.teamTransfer.metalSharing.notAllowed') }))
		return
	end
	
	-- Execute the share if amount > 0
	if amount > 0 then
		Spring.ShareResources(receiverTeamID, SharedEnums.ResourceType.METAL, amount)
		Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveMetal:amount='..amount..':name='..receiverName)
		WG.sharedMetalFrame = Spring.GetGameFrame()
		
		-- Notify post-transfer hooks
		if GG.TeamTransfer and GG.TeamTransfer.NotifyPostTransfer then
			GG.TeamTransfer.NotifyPostTransfer({
				resource = SharedEnums.ResourceType.METAL,
				senderTeamID = senderTeamID,
				receiverTeamID = receiverTeamID,
				amount = amount
			})
		end
	end
end

---Share units with unified validation and messaging
---@param senderTeamID number
---@param receiverTeamID number?
---@param selectedUnitIDs number[]
---@param receiverName string?
M.ShareUnits = function(senderTeamID, receiverTeamID, selectedUnitIDs, receiverName)
	-- Basic parameter validation
	if not receiverTeamID then
		Spring.Echo(Spring.I18N('ui.teamTransfer.unitSharing.noTarget'))
		return
	end
	
	if receiverTeamID == senderTeamID then
		Spring.Echo(Spring.I18N('ui.teamTransfer.unitSharing.cannotShareToSelf'))
		return
	end
	
	-- Check if teams are allied
	local senderAllyTeam = Spring.GetTeamAllyTeamID(senderTeamID)
	local receiverAllyTeam = Spring.GetTeamAllyTeamID(receiverTeamID)
	if senderAllyTeam ~= receiverAllyTeam then
		Spring.Echo(Spring.I18N('ui.teamTransfer.unitSharing.onlyAlliedPlayers'))
		return
	end
	
	-- Validate unit sharing through policies
	local canShare, blockReason = WG.TeamTransfer.CanShareUnits(senderTeamID, receiverTeamID, selectedUnitIDs)
	if not canShare then
		Spring.Echo(Spring.I18N('ui.teamTransfer.unitSharing.blocked', { reason = blockReason or Spring.I18N('ui.teamTransfer.unitSharing.notAllowed') }))
		return
	end
	
	-- Execute the share
	Spring.ShareResources(receiverTeamID, "units")
	if receiverName then
		Spring.SendLuaRulesMsg('msg:ui.playersList.chat.giveUnits:count='..#selectedUnitIDs..':name='..receiverName)
	end
end

return M