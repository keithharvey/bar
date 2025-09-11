local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")
local FluentPolicy = VFS.Include("luarules/gadgets/team_transfer/fluent_policy.lua")

local MetalSendThreshold = SharedEnums.Policies.MetalSendThreshold
local TransferCategory = SharedEnums.TransferCategory
local CUMULATIVE_METAL_PARAM = "metal_share_cumulative_sent"

---@param ctx TeamTransferPolicyContext
---@param metalThreshold number Threshold set by mod option
---@return table Policy result with exposed metal data
local function UseMetalThresholdCheck(ctx, metalThreshold, taxRate)
	-- Calculate base amount sendable (what receiver can accept)
	local teamRepo = ctx.repositories.TeamRepository
	local receiverResources = ctx.resources.receiver
	local baseMaxAmount = 0
	
	baseMaxAmount = math.max(0, receiverResources.metal.storage - receiverResources.metal.current)

	-- Get cumulative metal sent (internal to this policy) - with defensive check
	local cumulativeMetal = teamRepo.GetCumulativeMetalSent(ctx.senderTeamId) or 0
	local allowanceRemaining = math.max(0, metalThreshold - cumulativeMetal)

	-- Apply threshold logic: only allow sending if sender has more than threshold
	local senderMetal = teamRepo.GetTeamResources(ctx.senderTeamId, "metal")
	local availableAfterThreshold = math.max(0, senderMetal - metalThreshold)
	local finalMaxAmount = math.min(baseMaxAmount, availableAfterThreshold)

	---@type MetalSendThresholdResult
	local metalExpose = {
		canShare = finalMaxAmount > 0,
		amountSendable = finalMaxAmount,
		blockReason = (finalMaxAmount <= 0) and "Metal threshold reached or no metal available",
		taxRate = taxRate,
		remainingTaxFreeAllowance = allowanceRemaining
	}

	return {
		expose = {
			[TransferCategory.MetalTransfer] = metalExpose
		}
	}
end

FluentPolicy.RegisterPolicy(MetalSendThreshold, function(policy)
	if not policy.mod_option or policy.mod_option == 0 then
		return
	end

	local metalThreshold = tonumber(policy.mod_option) or 0

	-- Get tax rate from mod options
	local taxRate = 0
	local modOptions = Spring.GetModOptions()
	if modOptions then
		local taxRateStr = modOptions[SharedEnums.Policies.TaxResourceSharing]
		if taxRateStr then
			taxRate = tonumber(taxRateStr) or 0
		end
	end

	-- Initialize cumulative tracking for all teams
	policy:RegisterInitialize(function(context)
		local teamList = Spring.GetTeamList()
		for _, teamID in ipairs(teamList) do
			if not Spring.GetTeamRulesParam(teamID, CUMULATIVE_METAL_PARAM) then
				Spring.SetTeamRulesParam(teamID, CUMULATIVE_METAL_PARAM, 0)
			end
		end
	end)

	policy:Allied():MetalTransfers()
		:Use(function(ctx)
			return UseMetalThresholdCheck(ctx, metalThreshold, taxRate)
		end)

	-- Update cumulative tracking after successful transfers
	policy:RegisterPostTransfer(function(transferData)
		if transferData.resource == SharedEnums.ResourceType.METAL then
			-- Defensive check: ensure valid team ID
			if transferData.senderTeamID and transferData.senderTeamID >= 0 then
				local currentCumulative = Spring.GetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM) or 0
				local newCumulative = currentCumulative + (transferData.amount or 0)
				Spring.SetTeamRulesParam(transferData.senderTeamID, CUMULATIVE_METAL_PARAM, newCumulative)
			else
				Spring.Log("TeamTransfer", "ERROR", "Invalid senderTeamID in PostTransfer: " .. tostring(transferData.senderTeamID))
			end
		end
	end)
end)