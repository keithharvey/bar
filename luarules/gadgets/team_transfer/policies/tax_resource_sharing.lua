local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: Tax Resource Sharing',
		desc    = 'Implements tax system for allied resource sharing',
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

local enabled, taxRate = GG.TeamTransfer.IsSharingOption(MODOPTION_KEYS.TAX_RESOURCE_SHARING_AMOUNT)

if not enabled or (tonumber(taxRate) or 0) == 0 then
	return
end

taxRate = tonumber(taxRate) or 0

GG.TeamTransfer.RegisterPolicy(function(policy)
	
	policy.ForAlliedResourceTransfers.Use(function(ctx)
		if ctx.amountClamped <= 0 then
			return { allow = false }
		end

		local cumulative = (ctx.resource == "metal") and (ctx.cumulativeMetal or 0) or 0
		local breakdown = Tax.computeTransfer(ctx.resource, ctx.amountClamped, taxRate, 0, cumulative)

		local sent = math.min(breakdown.actualSent or 0, ctx.amount)
		local received = math.min(breakdown.actualReceived or 0, ctx.amountClamped)

		return {
			applyTransfer = {
				sent = sent,
				received = received,
				updateCumulativeMetal = (ctx.resource == "metal"),
			},
			expose = {
				taxRate = taxRate,
			}
		}
	end)

	policy.ForAlliedCommands.WhenReclaim.Deny()
	policy.ForEnemyCommands.WhenReclaim.Allow()
	
	-- Guard commands that target units with reclaim capability
	policy.ForAlliedCommands.WhenGuard.Use(function(ctx)
		if Predicates.Command.targetHasReclaim(ctx) then
			return { deny = true }
		end
		return { allow = true }
	end)
	
	policy.ForEnemyCommands.WhenGuard.Use(function(ctx)
		if Predicates.Command.targetHasReclaim(ctx) then
			return { allow = true }
		end
		return { allow = true }
	end)
end)
