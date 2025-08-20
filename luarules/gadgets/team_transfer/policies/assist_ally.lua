local gadget = gadget

---@load-file luaui/types/team_transfer.lua

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: Assist Ally',
		desc    = 'Controls ally assistance commands based on mod options',
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

---@type TeamTransferAPI
local TeamTransfer = GG.TeamTransfer
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS

local enabled = TeamTransfer.IsSharingOption(MODOPTION_KEYS.ALLY_ASSIST_MODE)
if not enabled then
	return
end

local modOpts = Spring.GetModOptions()
local assistMode = modOpts[MODOPTION_KEYS.ALLY_ASSIST_MODE] or "enabled"
if assistMode ~= "disabled" then
	return
end

TeamTransfer.RegisterPolicy(function(policy)	
	policy.ForAlliedCommands.WhenGuard.Deny()
	policy.ForAlliedCommands.WhenRepair.Deny()
end)
