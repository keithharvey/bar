local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Unit Sharing Control',
		desc    = 'Controls unit sharing based on modoption (All/Combat/Disabled)',
		author  = 'Rimilel, Devin AI',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local unitSharingMode = Spring.GetModOptions().unit_sharing_mode or "all"

if unitSharingMode == "all" and not Spring.GetModOptions().unit_market then
	return false
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	
	if Spring.GetModOptions().unit_market then
		return false
	end
	
	if unitSharingMode == "disabled" then
		return false
	elseif unitSharingMode == "combat" then
		local unitDef = UnitDefs[unitDefID]
		if unitDef.customparams and unitDef.customparams.iseconomicunit == "1" then
			return false
		end
		return true
	end
	
	return true
end
