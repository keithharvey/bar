local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Resources = VFS.Include("luarules/gadgets/team_transfer/resources.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("common/sharing_modoption_keys.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.TAX_RESOURCE_SHARING_AMOUNT) then
	return
end

local modOpts = Spring.GetModOptions()
local taxRate = modOpts[KEYS.TAX_RESOURCE_SHARING_AMOUNT] or 0
if taxRate == 0 then
	return
end

local metalThreshold = modOpts[KEYS.PLAYER_METAL_SEND_THRESHOLD] or 0
local cumulativeMetalSent = {}

local function clampToReceiverShare(receiverTeamId, resourceName, amount)
	local maxShare = Resources.ComputeMaxShare(receiverTeamId, resourceName)
	if amount > maxShare then
		return maxShare
	end
	return amount
end

local function getCumulative(teamId)
	return cumulativeMetalSent[teamId] or 0
end

local function setCumulative(teamId, value)
	cumulativeMetalSent[teamId] = value
	Spring.SetTeamRulesParam(teamId, "metal_share_cumulative_sent", value)
end

local function exposeTeamRules()
	Spring.SetGameRulesParam("resource_share_tax_rate", taxRate)
	Spring.SetGameRulesParam("metal_share_threshold", metalThreshold)
end

exposeTeamRules()

API.RegisterAllowResourceTransfer(function(senderTeamId, receiverTeamId, resourceName, amount)
	if amount <= 0 then
		return false
	end
	if not Spring.AreTeamsAllied(senderTeamId, receiverTeamId) then
		return false
	end

	local clampedAmount = clampToReceiverShare(receiverTeamId, resourceName, amount)

	local cumulative = (resourceName == "metal") and getCumulative(senderTeamId) or 0
	local sent, received, breakdown = Resources.ApplyTaxedTransfer(senderTeamId, receiverTeamId, resourceName, clampedAmount, taxRate, metalThreshold, cumulative)

	if resourceName == "metal" then
		setCumulative(senderTeamId, cumulative + sent)
	end

	return false
end)

API.RegisterAllowCommand(function(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD.RECLAIM and #cmdParams >= 1 then
		local targetID = cmdParams[1]
		if targetID and targetID < Game.maxUnits then
			local targetTeam = Spring.GetUnitTeam(targetID)
			if targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
				return false
			end
		end
		return true
	end

	if cmdID == CMD.GUARD then
		local targetID = cmdParams[1]
		if targetID then
			local targetTeam = Spring.GetUnitTeam(targetID)
			if targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
				local defID = Spring.GetUnitDefID(targetID)
				local def = defID and UnitDefs[defID]
				if def and def.canReclaim then
					return false
				end
			end
		end
		return true
	end

	return true
end)
