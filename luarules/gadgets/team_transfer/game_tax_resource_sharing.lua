---@diagnostic disable: undefined-global
function gadget:GetInfo()
	return {
		name    = "ModOptions: Tax Resource Sharing",
		desc    = "Policy implementation for resource sharing tax and reclaim restrictions",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

---@type TeamTransferAPI
local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Tax = TeamTransfer.ResourceShareTax
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
---@type TeamTransferPredicates
local Predicates = TeamTransfer.Predicates

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.TAX_RESOURCE_SHARING_AMOUNT) then
	return
end

local modOpts = Spring.GetModOptions()
local taxRate = modOpts[MODOPTION_KEYS.TAX_RESOURCE_SHARING_AMOUNT] or 0
if taxRate == 0 then
	return
end
local metalThreshold = modOpts[MODOPTION_KEYS.PLAYER_METAL_SEND_THRESHOLD] or 0

----------------------------------------------------------------
----------------------------------------------------------------

TeamTransfer.RegisterPolicy(function(policy)
	policy:For(TeamTransfer.PolicyType.ResourceTransfer)
	:When(function(ctx) return ctx.areAlliedTeams end)
	:Use(function(ctx)
		if ctx.amountClamped <= 0 then
			return { allow = false }
		end

		local cumulative = (ctx.resource == "metal") and (ctx.cumulativeMetal or 0) or 0
		local breakdown = Tax.computeTransfer(ctx.resource, ctx.amountClamped, taxRate, metalThreshold, cumulative)

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
				threshold = metalThreshold,
			}
		}
	end)

	local function reclaimCommands(targetAllied, result)
		return function(policy)
			local builder = policy:For(TeamTransfer.PolicyType.Command)
				:When(Predicates.Command.isReclaim)
			
			if targetAllied then
				builder = builder:When(Predicates.Command.targetAllied)
			end
			
			return builder:Use(function(ctx)
				return result
			end)
		end
	end

	local function guardReclaimCommands(targetAllied, result)
		return function(policy)
			local builder = policy:For(TeamTransfer.PolicyType.Command)
				:When(Predicates.Command.isGuard)
			
			if targetAllied then
				builder = builder:When(Predicates.Command.targetAllied)
					:When(Predicates.Command.targetHasReclaim)
			end
			
			return builder:Use(function(ctx)
				return result
			end)
		end
	end

	reclaimCommands(true, { deny = true })(policy)
	reclaimCommands(false, { allow = true })(policy)
	guardReclaimCommands(true, { deny = true })(policy)
	guardReclaimCommands(false, { allow = true })(policy)
end)
