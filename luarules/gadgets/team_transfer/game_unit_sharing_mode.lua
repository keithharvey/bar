local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local units = VFS.Include("luarules/gadgets/team_transfer/units.lua")
local sharing = VFS.Include("common/unit_sharing.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("common/sharing_modoption_keys.lua")
local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.UNIT_SHARING_MODE) then
	return
end

local unitSharingMode = sharing.getUnitSharingMode()
if unitSharingMode == "enabled" then
	return
end

API.RegisterPolicy(function(policy)
	policy:For(Definitions.PolicyType.UnitTransfer)
	:Use(function(ctx)
		if ctx.capture then
			return { allow = true }
		end
		if ctx.takeBypassAllowed then
			return { allow = true }
		end
		local allowed = units.AllowUnitTransferByMode(ctx.unitID, ctx.unitDefID, ctx.fromTeamID, ctx.toTeamID, ctx.capture)
		return { allow = allowed }
	end)
end)

