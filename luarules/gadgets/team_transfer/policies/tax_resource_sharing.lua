local PolicyManager = VFS.Include("luarules/gadgets/team_transfer/policy_manager.lua")
local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

local Tax = TeamTransfer.ResourceShareTax
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
local Predicates = TeamTransfer.Predicates

local enabled = TeamTransfer.IsSharingOption(MODOPTION_KEYS.TAX_RESOURCE_SHARING_AMOUNT)
if not enabled then
	return
end

local modOpts = Spring.GetModOptions()
local taxRate = modOpts[MODOPTION_KEYS.TAX_RESOURCE_SHARING_AMOUNT] or 0
if taxRate == 0 then
	return
end
local metalThreshold = modOpts[MODOPTION_KEYS.PLAYER_METAL_SEND_THRESHOLD] or 0

PolicyManager.registerConfig("tax_resource_sharing", {
	enabled = true,
	description = "Implements tax on resource sharing between allied teams",
	taxRate = taxRate,
	metalThreshold = metalThreshold,
	registrar = function(policy)
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

		policy.Commands.Reclaim.Allied:Deny()
		policy.Commands.Reclaim.Enemy:Allow()
		
		policy.Commands.Guard.Allied:When(Predicates.Command.targetHasReclaim):Deny()
		policy.Commands.Guard.Enemy:When(Predicates.Command.targetHasReclaim):Allow()
	end
})
