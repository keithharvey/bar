local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("common/sharing_modoption_keys.lua")
local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION) then
	return
end

local allowAssist = not Spring.GetModOptions()[KEYS.DISABLE_ASSIST_ALLY_CONSTRUCTION]
if allowAssist then
	return
end

API.RegisterPolicy(function(policy)
	policy:For(Definitions.PolicyType.Command)
	:Use(function(ctx)
		if ctx.cmdID == CMD.GUARD and ctx.targetID then
			if ctx.targetAllied and ctx.targetUnitDef then
				if (#(ctx.targetUnitDef.buildOptions or {}) > 0) or ctx.targetUnitDef.canAssist then
					return { deny = true }
				end
			end
			return { allow = true }
		end

		if ctx.cmdID == CMD.REPAIR and ctx.targetID then
			if ctx.targetAllied and (not ctx.targetIsComplete) then
				return { deny = true }
			end
			return { allow = true }
		end

		return nil
	end)
end)
