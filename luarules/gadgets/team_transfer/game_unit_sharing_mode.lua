function gadget:GetInfo()
	return {
		name    = "ModOptions: Unit Sharing Mode",
		desc    = "Declares mod options for unit sharing mode (enabled, t2cons, disabled)",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local units = VFS.Include("luarules/gadgets/team_transfer/units.lua")
local sharing = VFS.Include("common/unit_sharing.lua")
local sharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
local KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")

if not sharingModeUtils.shouldGadgetRun(KEYS.UNIT_SHARING_MODE) then
	return
end

local unitSharingMode = sharing.getUnitSharingMode()
if unitSharingMode == "enabled" then
	return
end

API.RegisterPolicy(function(policy)
	policy:For(API.PolicyType.UnitTransfer)
	:Use(function(ctx)
		if ctx.capture then
			return { allow = true }
		end
		if ctx.takeBypassAllowed then
			return { allow = true }
		end
		local allowed = units.AllowUnitTransferByMode(ctx.unitID, ctx.unitDefID, ctx.fromTeamID, ctx.toTeamID, ctx.capture, unitSharingMode)
		return { allow = allowed }
	end)
end)

