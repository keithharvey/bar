local MODOPTION_KEYS = GG.TeamTransfer.MODOPTION_KEYS

local enabled = GG.TeamTransfer.IsSharingOption(MODOPTION_KEYS.ALLY_ASSIST_MODE)
if not enabled then
	return
end

local modOpts = Spring.GetModOptions()
local assistMode = modOpts[MODOPTION_KEYS.ALLY_ASSIST_MODE] or "enabled"
if assistMode ~= "disabled" then
	return
end

GG.TeamTransfer.RegisterPolicy(function(policy)
	policy.Commands.Guard.Allied:Deny()
	policy.Commands.Repair.Allied:Deny()
end)
