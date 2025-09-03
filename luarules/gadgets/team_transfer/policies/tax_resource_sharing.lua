-- Team Transfer Policy: Tax Resource Sharing (Hook-based)
-- Self-contained policy that mirrors the original game_tax_resource_sharing.lua structure
-- Uses pipeline hooks for complete encapsulation of state and logic

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

Spring.Log("[TAX POLICY INIT]", LOG.ERROR, "Running INSIDE TAX POLICY (HOOKED VERSION)")

-- Policy enum shortcuts for cleaner code
-- Policies use SharedEnums directly, not the external GG.TeamTransfer interface
local TaxResourceSharing = SharedEnums.Policies.TaxResourceSharing
local TransferCategory = SharedEnums.TransferCategory

-- Include internal modules directly (policies are part of the internal system)
local Tax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
local Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")

-- Include sharing utilities for modoption checking
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")

-- Check modoptions to see if this policy should be active
local enabled, taxRate = SharingUtils.IsSharingOption(SharedEnums.Policies.TaxResourceSharing)

Spring.Log("[TAX POLICY INIT]", LOG.ERROR, "enabled=" .. tostring(enabled) .. ", taxRate=" .. tostring(taxRate))

if not enabled then
	Spring.Log("[TAX POLICY INIT]", LOG.ERROR, "Policy not registering - tax disabled")
	return
end

-- Normalize the values
if not enabled or (tonumber(taxRate) or 0) == 0 then
	taxRate = 0
else
	taxRate = tonumber(taxRate) or 0
end

Spring.Log("[TAX POLICY]", LOG.ERROR, "Tax rate: " .. taxRate)

--- Reusable Tax Resource Sharing handler
--- Eliminates duplication across different transfer types and resources
---@param ctx TeamTransferPolicyContext
---@param teamField string Field name to extract team ID from context
---@param transferType string Transfer type for logging
---@return table Policy result with exposed tax data
local function UseTaxResourceCheck(ctx, teamField, transferType)
	-- Defensive programming: ensure context has valid team IDs
	local teamID = ctx[teamField]
	if not teamID or teamID < 0 then
		Spring.Log("[TAX POLICY]", LOG.ERROR, "Invalid team ID in context - using safe defaults")
		return {
			expose = {

				-- @type PolicyMetalTransferExpose
				[TransferCategory.MetalTransfer] = {
					amountSendable = 0,
					taxRate = taxRate,
					_policyData = { taxRate = taxRate }
				},
				-- @type PolicyEnergyTransferExpose
				[TransferCategory.EnergyTransfer] = {
					amountSendable = 0,
					taxRate = taxRate,
					_policyData = { taxRate = taxRate }
				}
			}
		}
	end

	-- Defensive programming: ensure resource data exists
	if not ctx.senderResources or not ctx.senderResources.metal or not ctx.receiverResources or not ctx.receiverResources.metal then
		Spring.Log("[TAX POLICY]", LOG.ERROR, "Missing resource data in context - using safe defaults")
		return {
			expose = {
				-- @type PolicyMetalTransferExpose
				[TransferCategory.MetalTransfer] = {
					amountSendable = 0,
					taxRate = taxRate,
					_policyData = { taxRate = taxRate }
				},
				-- @type PolicyEnergyTransferExpose
				[TransferCategory.EnergyTransfer] = {
					amountSendable = 0,
					taxRate = taxRate,
					_policyData = { taxRate = taxRate }
				}
			}
		}
	end

	-- Use pre-calculated default expose data from pipeline context instead of manual calculations
	local maxMetalAmount = ctx.defaultMetalTransfer.amountSendable
	local canShareMetal = ctx.defaultMetalTransfer.canShareMetal

	-- Use pre-calculated default expose data for energy as well
	local maxEnergyAmount = ctx.defaultEnergyTransfer.amountSendable
	local canShareEnergy = ctx.defaultEnergyTransfer.canShareEnergy

	Spring.Log("[TAX POLICY]", LOG.ERROR,
		string.format("EXPOSE tax for %s transfer: metal=%d, energy=%d, taxRate=%.2f",
			transferType, maxMetalAmount, maxEnergyAmount, taxRate))

	---@type TaxResourceSharingMetalResult
	local metalExpose = {
		amountSendable = maxMetalAmount,  -- Required by DefaultMetalTransferResult
		blockReason = (maxMetalAmount <= 0) and "No metal available to send" or nil,
		amountRemainingAllowance = maxMetalAmount, -- Common concept on base type
		taxRate = taxRate -- Policy-specific extension
	}

	---@type TaxResourceSharingEnergyResult
	local energyExpose = {
		amountSendable = maxEnergyAmount,  -- Required by DefaultEnergyTransferResult
		blockReason = (maxEnergyAmount <= 0) and "No energy available to send" or nil,
		amountRemainingAllowance = maxEnergyAmount, -- Common concept on base type
		taxRate = taxRate -- Policy-specific extension
	}

	return {
		expose = {
			[TransferCategory.MetalTransfer] = metalExpose,
			[TransferCategory.EnergyTransfer] = energyExpose
		}
	}
end

GG.TeamTransfer.RegisterPolicy(TaxResourceSharing, function(policy)
	-- Tax applies to both metal and energy transfers to allies
	policy.ForAlliedMetalTransfers.Use(function(ctx)
		return UseTaxResourceCheck(ctx, "receiverTeamId", "allied metal")
	end)
	
	policy.ForAlliedEnergyTransfers.Use(function(ctx)
		return UseTaxResourceCheck(ctx, "receiverTeamId", "allied energy")
	end)
end)