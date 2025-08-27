-- Team Transfer Policy: Tax Resource Sharing (Hook-based)
-- Self-contained policy that mirrors the original game_tax_resource_sharing.lua structure
-- Uses pipeline hooks for complete encapsulation of state and logic

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local TransferCategory = SharedEnums.TransferCategory

Spring.Log("[TAX POLICY INIT]", LOG.ERROR, "Running INSIDE TAX POLICY (HOOKED VERSION)")

-- Policy enum shortcuts for cleaner code
-- Policies use SharedEnums directly, not the external GG.TeamTransfer interface
local TaxResourceSharing = SharedEnums.Policies.TaxResourceSharing
local ResourceTransfer = SharedEnums.PolicyType.ResourceTransfer

-- Include internal modules directly (policies are part of the internal system)
local Tax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
local Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")
local PolicyHooks = VFS.Include("luarules/gadgets/team_transfer/policy_hooks.lua")

-- Include sharing utilities for modoption checking
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")

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

Spring.Log("[TAX POLICY]", LOG.ERROR, "Tax rate: " .. taxRate .. ", Metal threshold: " .. metalThreshold)

GG.TeamTransfer.RegisterPolicy(TaxResourceSharing, function(policy)
	policy.ForAlliedResourceTransfers.Use(function(ctx)
		Spring.Log("[TAX POLICY DEBUG]", LOG.ERROR, "inside tax policy")

		local senderAvailable = ctx.senderResources.metal.current
		local receiverCapacity = math.max(0, ctx.receiverResources.metal.storage - ctx.receiverResources.metal.current)
		local maxMetalAmount = math.min(senderAvailable, receiverCapacity)
		
		local senderEnergyAvailable = ctx.senderResources.energy.current
		local receiverEnergyCapacity = math.max(0, ctx.receiverResources.energy.storage - ctx.receiverResources.energy.current)
		local maxEnergyAmount = math.min(senderEnergyAvailable, receiverEnergyCapacity)
		
		local finalMetalAmount = maxMetalAmount
		
		---@type TaxResourceSharingResult
		return {
			expose = {
				[TransferCategory.METAL_TRANSFER] = {
					maxShareAmount = finalMetalAmount,
					_policyData = {
						taxRate = taxRate,
					}
				},
				[TransferCategory.ENERGY_TRANSFER] = {
					maxShareAmount = maxEnergyAmount,
					_policyData = {
						taxRate = taxRate,
					}
				}
			}
		}
	end)
end)