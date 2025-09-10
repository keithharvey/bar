local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")

local PipelineLogger = VFS.Include("luarules/gadgets/team_transfer/pipeline_logger.lua")
local FluentPolicy = VFS.Include("luarules/gadgets/team_transfer/fluent_policy.lua")

local TaxResourceSharing = SharedEnums.Policies.TaxResourceSharing
local TransferCategory = SharedEnums.TransferCategory

---@param ctx TeamTransferPolicyContext
---@param taxRate integer Tax rate set by mod option
---@return table Policy result with exposed tax data
local function UseTaxResourceCheck(ctx, taxRate)
	local senderResources = ctx.resources.sender
	local receiverResources = ctx.resources.receiver

	local maxMetalAmount = 0
	local maxEnergyAmount = 0

	if senderResources and receiverResources then
		local senderMetal = senderResources.metal.current or 0
		local receiverMetal = receiverResources.metal.current or 0
		local metalDifference = math.max(0, senderMetal - receiverMetal)
		maxMetalAmount = math.floor(metalDifference * (1 + taxRate))

		-- Calculate the difference between sender and receiver resources (as per test expectation)
		local senderEnergy = senderResources.energy.current or 0
		local receiverEnergy = receiverResources.energy.current or 0
		local energyDifference = math.max(0, senderEnergy - receiverEnergy)
		maxEnergyAmount = math.floor(energyDifference * (1 + taxRate))
	end

	---@type TaxResourceSharingMetalResult
	local metalExpose = {
		canShare = maxMetalAmount > 0,
		amountSendable = maxMetalAmount,
		blockReason = (maxMetalAmount <= 0) and "No metal available to send" or nil,
		taxRate = taxRate
	}

	---@type TaxResourceSharingEnergyResult
	local energyExpose = {
		canShare = maxEnergyAmount > 0,
		amountSendable = maxEnergyAmount,
		blockReason = (maxEnergyAmount <= 0) and "No energy available to send" or nil,
		amountRemainingAllowance = maxEnergyAmount,
		taxRate = taxRate
	}


	return {
		expose = {
			[TransferCategory.MetalTransfer] = metalExpose,
			[TransferCategory.EnergyTransfer] = energyExpose
		}
	}
end

FluentPolicy.RegisterPolicy(TaxResourceSharing, function(policy)
	if not policy.mod_option or policy.mod_option == 0 then
		return
	end

	policy:Allied():MetalTransfers()
		:Use(function(ctx)
			local taxRate = tonumber(policy.mod_option) or 0
			return UseTaxResourceCheck(ctx, taxRate)
		end)

	policy:Allied():EnergyTransfers()
		:Use(function(ctx)
			local taxRate = tonumber(policy.mod_option) or 0
			return UseTaxResourceCheck(ctx, taxRate)
		end)
end)