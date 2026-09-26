local Policy = require("modules/policy")
local Shared = require("modules/transfer/resource/shared")
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

-- May this team send that one a resource, how much, and what the tax takes
--
---@class TransferResourcePolicyResult: TransferPolicyResult
---@field canShare boolean
---@field amountSendable number
---@field amountReceivable number
---@field taxedPortion number
---@field taxRate number
---@field resourceType ResourceName
---@field techBlocking? TechBlockingContext

---@class TransferResourceTransferPolicy: PolicySteps<TransferPolicyContext, TransferResourcePolicyResult>
---@field SharingDisabled "SharingDisabled"
---@field Allied "Allied"
---@field ReceiverHasNoPlayers "ReceiverHasNoPlayers"
---@field RateAndCapacity "RateAndCapacity"

---@class (partial) TransferContract
---@field ResourceTransfer TransferResourceTransferPolicy

---@type TransferResourceTransferPolicy
local ResourceTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	RateAndCapacity = "RateAndCapacity",
}
Policy.Single(ResourceTransfer)

local METAL = TransferEnums.ResourceType.METAL

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return TransferResourcePolicyResult
local function deny(ctx, resourceType)
	return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
end

Policies.On(ResourceTransfer)
	.Refusal(function(ctx, resourceType)
		return deny(ctx, resourceType)
	end)
	.Unless(ResourceTransfer.SharingDisabled, function(ctx)
		return not SharedConfig.isResourceSharingEnabled(ctx.springRepo)
	end)
	.If(ResourceTransfer.Allied, function(ctx)
		if ctx.isCheatingEnabled then
			return true
		end
		return ctx.areAlliedTeams or Shared.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId)
	end)
	.Unless(ResourceTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Answer(ResourceTransfer.RateAndCapacity, function(ctx, resourceType, rate, result)
		local senderData, receiverData
		if resourceType == METAL then
			senderData = ctx.sender.metal
			receiverData = ctx.receiver.metal
		else
			senderData = ctx.sender.energy
			receiverData = ctx.receiver.energy
		end
		local taxedSendable = math.max(0, senderData.current) * (1 - rate)
		local capacity = receiverData.storage - receiverData.current
		Shared.CombineResourcePolicy(
			taxedSendable,
			rate,
			capacity,
			ctx.senderTeamId,
			ctx.receiverTeamId,
			resourceType,
			result
		)
		result.techBlocking = ctx.techBlocking
		return result
	end)

-- The notes other modules attach to a resource-terms record for the player to read; providers get the modoptions
--
---@class TransferResourceNotesFacts: PolicyFacts<TransferResourcePolicyResult>
---@field TaxUnlock "taxUnlock"

---@class (partial) TransferContract
---@field ResourceTermsNotes TransferResourceNotesFacts

---@type TransferResourceNotesFacts
local ResourceTermsNotes = {
	TaxUnlock = "taxUnlock",
}
Policy.Facts(ResourceTermsNotes)

return { ResourceTransfer = ResourceTransfer, ResourceTermsNotes = ResourceTermsNotes }
