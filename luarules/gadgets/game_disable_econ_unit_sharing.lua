local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Economic Unit Sharing',
		desc    = 'Disable sharing any economic or builder units when modoption is enabled',
		author  = 'Devin AI',
		date    = 'August 2025',
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

if not Spring.GetModOptions().disable_economic_sharing then
	return false
end

Spring.Echo("Sharing restrictions on economic units are active")

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	
	local unitDef = UnitDefs[unitDefID]
	if unitDef.customparams and unitDef.customparams.iseconomicunit == "1" then
		return false
	end
	
	return true
end
