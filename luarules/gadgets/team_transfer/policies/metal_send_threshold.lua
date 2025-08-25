local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: Metal Send Threshold',
		desc    = 'Implements metal send threshold limits for resource sharing',
		author  = 'Devin',
		date    = 'Aug 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Tax = GG.TeamTransfer.ResourceShareTax
local Predicates = GG.TeamTransfer.Predicates
local MODOPTION_KEYS = GG.TeamTransfer.MODOPTION_KEYS

local metalEnabled, metalThreshold = GG.TeamTransfer.IsSharingOption(MODOPTION_KEYS.PLAYER_METAL_SEND_THRESHOLD)

if not metalEnabled or (tonumber(metalThreshold) or 0) == 0 then
	return
end

metalThreshold = tonumber(metalThreshold) or 0

GG.TeamTransfer.RegisterPolicy(function(policy)
	
	policy.ForAlliedResourceTransfers.Use(function(ctx)
		if ctx.resource ~= "metal" or ctx.amountClamped <= 0 then
			return nil
		end

		local cumulative = ctx.cumulativeMetal or 0
		local taxRate = tonumber(Spring.GetModOptions().tax_resource_sharing_amount) or 0
		
		local breakdown = Tax.computeTransfer(ctx.resource, ctx.amountClamped, taxRate, metalThreshold, cumulative)
		
		local sent = math.min(breakdown.actualSent or 0, ctx.amount)
		local received = math.min(breakdown.actualReceived or 0, ctx.amountClamped)
		
		if sent <= 0 then
			return { allow = false }
		end
		
		return {
			applyTransfer = {
				sent = sent,
				received = received,
				updateCumulativeMetal = true,
			},
			expose = {
				threshold = metalThreshold,
				taxRate = taxRate,
			}
		}
	end)
end)
