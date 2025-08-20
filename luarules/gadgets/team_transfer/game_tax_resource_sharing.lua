function gadget:GetInfo()
	return {
		name    = "ModOptions: Tax Resource Sharing",
		desc    = "Declares mod options for resource sharing tax + metal threshold",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Tax = VFS.Include('common/luaUtilities/resource_share_tax.lua')
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")
local Predicates = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.TAX_RESOURCE_SHARING_AMOUNT) then
	return
end

local modOpts = Spring.GetModOptions()
local taxRate = modOpts[KEYS.TAX_RESOURCE_SHARING_AMOUNT] or 0
if taxRate == 0 then
	return
end
local metalThreshold = modOpts[KEYS.PLAYER_METAL_SEND_THRESHOLD] or 0

API.RegisterPolicy(function(policy)
	policy:For(API.PolicyType.ResourceTransfer)
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

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isReclaim)
	:When(Predicates.Command.targetAllied)
	:Use(function(ctx)
		return { deny = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isReclaim)
	:Use(function(ctx)
		return { allow = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:When(Predicates.Command.targetAllied)
	:When(Predicates.Command.targetHasReclaim)
	:Use(function(ctx)
		return { deny = true }
	end)

	policy:For(API.PolicyType.Command)
	:When(Predicates.Command.isGuard)
	:Use(function(ctx)
		return { allow = true }
	end)
end)
