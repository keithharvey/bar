local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")

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
	policy.ForAlliedResourceTransfers.Use(function(ctx)
		if ctx.resource ~= SharedEnums.ResourceType.METAL then
			return { allow = true }
		end
		
		-- Calculate our own limits using context data
		local senderAvailable = ctx.senderResources.metal.current
		local receiverCapacity = math.max(0, ctx.receiverResources.metal.storage - ctx.receiverResources.metal.current)
		local baseMaxAmount = math.min(senderAvailable, receiverCapacity)
		
		-- Get cumulative metal sent (internal to this policy)
		local cumulativeMetal = Spring.GetTeamRulesParam(ctx.senderTeamId, CUMULATIVE_METAL_PARAM) or 0
		
		-- Apply threshold logic: only allow sending if sender has more than threshold
		local availableAfterThreshold = math.max(0, senderAvailable - metalThreshold)
		local finalMaxAmount = math.min(baseMaxAmount, availableAfterThreshold)
		
		return {
			expose = {
				[SharedEnums.TransferCategory.METAL_TRANSFER] = {
					maxShareAmount = finalMaxAmount,
					_policyData = {
						metalThreshold = metalThreshold,
						cumulativeSent = cumulativeMetal,
					}
				}
			}
		}
	end)
end)

-- Update cumulative tracking after successful transfers
GG.TeamTransfer.RegisterPostTransfer(function(transferData)
	if transferData.resource == SharedEnums.ResourceType.METAL then
		local currentCumulative = Spring.GetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM) or 0
		local newCumulative = currentCumulative + transferData.amount
		Spring.SetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM, newCumulative)
	end
end)
