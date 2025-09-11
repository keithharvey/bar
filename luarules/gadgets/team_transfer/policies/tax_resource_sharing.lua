local SharedEnums = require("luarules/gadgets/team_transfer/shared_enums")
local PipelineLogger = require("luarules/gadgets/team_transfer/pipeline_logger")
local FluentPolicy = require("luarules/gadgets/team_transfer/fluent_policy")

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

	---@type DefaultMetalTransferResult
	local metalExpose = {
		canShare = maxMetalAmount > 0,
		amountSendable = maxMetalAmount,
		blockReason = (maxMetalAmount <= 0) and "No metal available to send" or nil,
		taxRate = taxRate,
		remainingTaxFreeAllowance = 0
	}

	---@type DefaultEnergyTransferResult
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

-- Execute policy registration immediately instead of deferred
local ServiceRegistry = VFS.Include("luarules/gadgets/team_transfer/service_registry.lua")
local repo = ServiceRegistry.PolicyRepository()

local taxRate = 0.3

if repo and repo.RegisterPolicyAction then
    -- Register MetalTransfers policy
    local metalHandler = function(ctx)
        return UseTaxResourceCheck(ctx, taxRate)
    end

    repo.RegisterPolicyAction("metal_transfer", {
        name = "tax_resource_sharing_metal",
        predicates = {},
        conditions = {},
        handler = metalHandler
    })

    -- Register EnergyTransfers policy
    local energyHandler = function(ctx)
        return UseTaxResourceCheck(ctx, taxRate)
    end

    repo.RegisterPolicyAction("energy_transfer", {
        name = "tax_resource_sharing_energy",
        predicates = {},
        conditions = {},
        handler = energyHandler
    })
end