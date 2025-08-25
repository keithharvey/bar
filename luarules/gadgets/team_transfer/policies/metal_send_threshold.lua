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
		local remaining = math.max(0, metalThreshold - cumulative)
		
		local taxRate = Spring.GetTeamRulesParam(ctx.senderTeamId, "resource_share_tax_rate") or 0
		
		local effectiveThreshold = metalThreshold
		if taxRate > 0 then
			effectiveThreshold = metalThreshold / (1 + taxRate)
		end
		
		local effectiveRemaining = math.max(0, effectiveThreshold - cumulative)
		local allowedAmount = math.min(ctx.amountClamped, effectiveRemaining)
		
		if allowedAmount <= 0 then
			return { allow = false }
		end
		
		if allowedAmount < ctx.amountClamped then
			return { allow = false }
		end
		
		return {
			expose = {
				threshold = metalThreshold,
				effectiveThreshold = effectiveThreshold,
				remainingAllowance = effectiveRemaining,
			}
		}
	end)
end)
