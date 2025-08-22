function gadget:GetInfo()
	return {
		name = "Disable Ally Extractor Upgrade",
		desc = "Prevents upgrading ally metal extractors when economic sharing is disabled",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS

if not TeamTransfer.IsSharingOption(MODOPTION_KEYS.DISABLE_ECONOMIC_SHARING) then
	return
end

local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spAreTeamsAllied = Spring.AreTeamsAllied

function gadget:Initialize()
	if globalScope['resource_spot_builder'] and globalScope['resource_spot_builder'].SetAllowExtractorCanBeUpgraded then
		globalScope['resource_spot_builder'].SetAllowExtractorCanBeUpgraded(false)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.UPGRADE then
		local targetID = cmdParams[1]
		if targetID then
			local targetTeam = spGetUnitTeam(targetID)
			if targetTeam and targetTeam ~= teamID and spAreTeamsAllied(teamID, targetTeam) then
				local targetDefID = spGetUnitDefID(targetID)
				if targetDefID then
					local targetDef = UnitDefs[targetDefID]
					if targetDef and targetDef.customParams and targetDef.customParams.unitgroup == "metal" then
						return false
					end
				end
			end
		end
	end
	return true
end
