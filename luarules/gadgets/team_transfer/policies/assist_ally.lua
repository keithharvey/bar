local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

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
	policy.Commands.Guard.Allied:Deny()
	policy.Commands.Repair.Allied:Deny()
end)
