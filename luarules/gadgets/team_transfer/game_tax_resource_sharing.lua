local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")
local Tax = VFS.Include('common/luaUtilities/resource_share_tax.lua')
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("common/sharing_modoption_keys.lua")

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
	policy:For(Definitions.PolicyType.ResourceTransfer)
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

	policy:For(Definitions.PolicyType.Command)
	:Use(function(ctx)
		if ctx.cmdID == CMD.RECLAIM and ctx.targetID and ctx.targetID < Game.maxUnits then
			if ctx.targetAllied then
				return { deny = true }
			end
			return { allow = true }
		end

		if ctx.cmdID == CMD.GUARD and ctx.targetID then
			if ctx.targetAllied and ctx.targetUnitDef and ctx.targetUnitDef.canReclaim then
				return { deny = true }
			end
			return { allow = true }
		end

		return nil
	end)
end)
