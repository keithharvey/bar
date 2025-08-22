function gadget:GetInfo()
	return {
		name    = "ModOptions: Disable Ally Extractor Upgrade",
		desc    = "Policy implementation for disabled ally extractor upgrade modoption",
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

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.DISABLE_ALLY_EXTRACTOR_UPGRADE) then
	return
end

local disableAllyExtractorUpgrade = Spring.GetModOptions()[MODOPTION_KEYS.DISABLE_ALLY_EXTRACTOR_UPGRADE]
if not disableAllyExtractorUpgrade then
	return
end

----------------------------------------------------------------
----------------------------------------------------------------
local extractorRadius = Game.extractorRadius
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

local isMex = {}
local isGeo = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
	if unitDef.customParams and unitDef.customParams.geothermal then
		isGeo[unitDefID] = true
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function mexBlocked(myTeam, x, y, z)
	local units = spGetUnitsInCylinder(x, z, extractorRadius)
	for _, unitID in ipairs(units) do
		if isMex[spGetUnitDefID(unitID)] then
			if spGetUnitTeam(unitID) ~= myTeam then
				return true
			end
		end
	end
	return false
end

local function geoBlocked(myTeam, x, y, z)
	local units = spGetUnitsInCylinder(x, z, extractorRadius)
	for _, unitID in ipairs(units) do
		if isGeo[spGetUnitDefID(unitID)] then
			if spGetUnitTeam(unitID) ~= myTeam then
				return true
			end
		end
	end
	return false
end

----------------------------------------------------------------
----------------------------------------------------------------
function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	if isMex[unitDefID] and mexBlocked(builderTeam, x, y, z) then
		return false
	end
	if isGeo[unitDefID] and geoBlocked(builderTeam, x, y, z) then
		return false
	end
	return true
end
