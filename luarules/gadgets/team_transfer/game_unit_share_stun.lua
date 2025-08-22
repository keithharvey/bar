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
local stunFrames = stunSeconds * 30

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= oldTeam then
		Spring.SetUnitStunned(unitID, true)
		Spring.SetUnitRulesParam(unitID, "share_stun_end", Spring.GetGameFrame() + stunFrames)
	end
end

function gadget:GameFrame(frame)
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local stunEnd = Spring.GetUnitRulesParam(unitID, "share_stun_end")
		if stunEnd and frame >= stunEnd then
			Spring.SetUnitStunned(unitID, false)
			Spring.SetUnitRulesParam(unitID, "share_stun_end", nil)
		end
	end
end
