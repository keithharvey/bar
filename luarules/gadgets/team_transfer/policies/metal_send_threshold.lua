local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")

local CUMULATIVE_METAL_PARAM = "metal_share_cumulative_sent"

local enabled = SharingUtils.shouldGadgetRun("player_metal_send_threshold")
local metalThreshold = enabled and (Spring.GetModOptions().player_metal_send_threshold or 0) or 0

if not enabled or not metalThreshold or metalThreshold <= 0 then
	return
end

-- Initialize cumulative tracking for all teams
GG.TeamTransfer.RegisterInitialize(function()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not Spring.GetTeamRulesParam(teamID, CUMULATIVE_METAL_PARAM) then
			Spring.SetTeamRulesParam(teamID, CUMULATIVE_METAL_PARAM, 0)
		end
	end
end)

-- Register the policy
GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.MetalSendThreshold, function(policy)
	policy.ForAlliedMetalTransfers.Use(function(ctx)

		-- Use pre-calculated default metal transfer data from pipeline context
		local baseMaxAmount = ctx.defaultMetalTransfer.amountSendable

		-- Get cumulative metal sent (internal to this policy) - with defensive check
		local cumulativeMetal = 0
		if ctx.senderTeamId and ctx.senderTeamId >= 0 then
			cumulativeMetal = Spring.GetTeamRulesParam(ctx.senderTeamId, CUMULATIVE_METAL_PARAM) or 0
		end

		-- Apply threshold logic: only allow sending if sender has more than threshold
		local senderMetal = Spring.GetTeamResources(ctx.senderTeamId, "metal")
		local availableAfterThreshold = math.max(0, senderMetal - metalThreshold)
		local finalMaxAmount = math.min(baseMaxAmount, availableAfterThreshold)
		
		---@type MetalSendThresholdResult
		local metalExpose = {
			canShare = finalMaxAmount > 0,
			amountSendable = finalMaxAmount,  -- Required by DefaultMetalTransferResult
			blockReason = (finalMaxAmount <= 0) and "Metal threshold reached or no metal available" or nil,
			amountRemainingAllowance = math.max(0, availableAfterThreshold) -- Common concept on base type
		}

		return {
			expose = {
				[SharedEnums.TransferCategory.MetalTransfer] = metalExpose
			}
		}
	end)
end)

-- Update cumulative tracking after successful transfers
GG.TeamTransfer.RegisterPostTransfer(function(transferData)
	if transferData.resource == SharedEnums.ResourceType.METAL then
		-- Defensive check: ensure valid team ID
		if transferData.senderTeamID and transferData.senderTeamID >= 0 then
			local currentCumulative = Spring.GetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM) or 0
			local newCumulative = currentCumulative + (transferData.amount or 0)
			Spring.SetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM, newCumulative)
		else
			Spring.Log("TeamTransfer", LOG.ERROR, "Invalid senderTeamID in PostTransfer: " .. tostring(transferData.senderTeamID))
		end
	end
end)
