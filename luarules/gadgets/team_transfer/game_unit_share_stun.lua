function gadget:GetInfo()
	return {
		name    = "ModOptions: Unit Share Stun",
		desc    = "Policy implementation for unit share stun seconds modoption",
		author  = "BAR",
		date    = "Aug 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.UNIT_SHARE_STUN_SECONDS) then
	return
end

local stunSeconds = Spring.GetModOptions()[MODOPTION_KEYS.UNIT_SHARE_STUN_SECONDS] or 0
if stunSeconds <= 0 then
	return
end

----------------------------------------------------------------
----------------------------------------------------------------

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= oldTeam then
		local health, maxHealth, paralyze = Spring.GetUnitHealth(unitID)
		local paralyzeDamage = maxHealth * stunSeconds * 0.033333
		Spring.SetUnitHealth(unitID, { paralyze = paralyzeDamage })
	end
end
