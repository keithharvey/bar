local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

local CUMULATIVE_METAL_PARAM = "metal_share_cumulative_sent"
local CUMULATIVE_ENERGY_PARAM = "energy_share_cumulative_sent"

local function getCumulativeParam(resourceType)
	if resourceType == SharedEnums.ResourceType.METAL then
		return CUMULATIVE_METAL_PARAM
	elseif resourceType == SharedEnums.ResourceType.ENERGY then
		return CUMULATIVE_ENERGY_PARAM
	end
end

local function getCumulativeSent(teamID, resourceType, springRepo)
	local param = getCumulativeParam(resourceType)
	return tonumber(springRepo:GetTeamRulesParam(teamID, param)) or 0
end

local buildResultFactory = function(taxRate, metalThreshold, energyThreshold)
	---@param resourceType ResourceType
	local function getThreshold(resourceType)
		if resourceType == SharedEnums.ResourceType.METAL then
			return metalThreshold
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			return energyThreshold
		end
	end

	---@param ctx PolicyContext
	---@param resourceType ResourceType
	---@return ResourcePolicyResult
	local function calcResourcePolicyResult(ctx, resourceType)
		local resource = {
			cumulativeSent = getCumulativeSent(ctx.senderTeamId, resourceType, ctx.repositories.springRepo) or 0,
			threshold = getThreshold(resourceType)
		}
		if resourceType == SharedEnums.ResourceType.METAL then
			resource.sender_current = ctx.sender.metal.current
			resource.sender_storage = ctx.sender.metal.storage
			resource.receiver_current = ctx.receiver.metal.current
			resource.receiver_storage = ctx.receiver.metal.storage
		elseif resourceType == SharedEnums.ResourceType.ENERGY then
			resource.sender_current = ctx.sender.energy.current
			resource.sender_storage = ctx.sender.energy.storage
			resource.receiver_current = ctx.receiver.energy.current
			resource.receiver_storage = ctx.receiver.energy.storage
		end

		local receiverCapacity = resource.receiver_storage - resource.receiver_current

		local amountSendable = receiverCapacity
		local amountReceivable = receiverCapacity

		-- Calculate tax-free allowance remaining (considering cumulative sent)
		local allowanceRemaining = math.max(0, resource.threshold - resource.cumulativeSent)

		-- Calculate portions for transfer logic
		local senderBudget = resource.sender_current
		local untaxedPortion = math.min(allowanceRemaining, receiverCapacity, senderBudget)
		local taxedPortion = math.max(0, receiverCapacity - untaxedPortion)

		---@type ResourcePolicyResult
		return {
			canShare = amountSendable > 0,
			amountSendable = amountSendable,
			amountReceivable = amountReceivable,
			taxedPortion = taxedPortion,
			untaxedPortion = untaxedPortion,
			taxRate = taxRate,
			resourceType = resourceType,
			remainingTaxFreeAllowance = allowanceRemaining
		}
	end
	return calcResourcePolicyResult
end

---@param builder DSL
local function buildPolicy(builder)
	local taxRate = tonumber(builder.mod_options[ModOptions.Options.TaxResourceSharingAmount]) or 0

	local metalThreshold = tonumber(builder.mod_options[ModOptions.Options.PlayerMetalSendThreshold]) or 0
	local energyThreshold = tonumber(builder.mod_options[ModOptions.Options.PlayerEnergySendThreshold]) or 0

	local calcResourcePolicyResult = buildResultFactory(taxRate, metalThreshold, energyThreshold)

	builder:Allied():MetalTransfers():Use(function(ctx)
		return calcResourcePolicyResult(ctx, SharedEnums.ResourceType.METAL)
	end)

	builder:Allied():EnergyTransfers():Use(function(ctx)
		return calcResourcePolicyResult(ctx, SharedEnums.ResourceType.ENERGY)
	end)

	builder:RegisterPostMetalTransfer(function(transferResult, springRepo)
		local cumMetal = getCumulativeParam(SharedEnums.ResourceType.METAL)
		local current = tonumber(springRepo:GetTeamRulesParam(transferResult.senderTeamId, cumMetal)) or 0
		springRepo:SetTeamRulesParam(transferResult.senderTeamId, cumMetal, current + transferResult.sent)
	end)

	builder:RegisterPostEnergyTransfer(function(transferResult, springRepo)
		local cumEnergy = getCumulativeParam(SharedEnums.ResourceType.ENERGY)
		local current = tonumber(springRepo:GetTeamRulesParam(transferResult.senderTeamId, cumEnergy)) or 0
		springRepo:SetTeamRulesParam(transferResult.senderTeamId, cumEnergy, current + transferResult.sent)
	end)
end

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.TaxResourceSharing,
    func = buildPolicy,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        return modOptions[ModOptions.Options.TaxResourceSharingAmount] ~= nil
    end
}
return module