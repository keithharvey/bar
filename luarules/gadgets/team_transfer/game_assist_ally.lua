function gadget:GetInfo()
	return {
		name    = "ModOptions: Game Assist Ally",
		desc    = "Declares mod options for controlling allied assist/repair capabilities",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS
local Predicates = TeamTransfer.Predicates

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.GAME_ASSIST_ALLY) then
	return
end

local assistAllyMode = Spring.GetModOptions()[MODOPTION_KEYS.GAME_ASSIST_ALLY] or "enabled"
if assistAllyMode == "enabled" then
	return
end

TeamTransfer.RegisterPolicy(function(policy)
	policy.Commands.Guard.Allied:Deny()
	policy.Commands.Repair.Allied:Deny()
end)
