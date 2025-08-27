local gadget = gadget ---@type Gadget

local sharing = GG.TeamTransfer.UnitSharing
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local modoption = SharedEnums.Policies.UnitSharingMode

local enabled, unitSharingMode = GG.TeamTransfer.IsSharingOption(modoption)
if not enabled or unitSharingMode == "enabled" then
	return
end

-- Policy enum shortcuts for cleaner code
local UnitSharingMode = GG.TeamTransfer.Policies.UNIT_SHARING_MODE
local TransferCategory = GG.TeamTransfer.SharedEnums.TransferCategory

-- Cached unit sets for efficient lookup
local allowedUnits = {} -- Set of unitDefIDs that are allowed in current mode
local unitSharingEnabled = unitSharingMode ~= "disabled"

local function initializeAllowedUnits()
	allowedUnits = {}
	
	if unitSharingMode == "disabled" then
		-- No units allowed
		return
	end
	
	-- Iterate through all unit definitions and cache allowed ones
	for unitDefID, unitDef in pairs(UnitDefs) do
		local allowed = false
		
		if unitSharingMode == "t2cons" then
			allowed = sharing.isT2ConstructorDef(unitDef)
		elseif unitSharingMode == "combat" then
			allowed = not sharing.isEconomicUnitDef(unitDef)
		elseif unitSharingMode == "combat_t2cons" then
			allowed = not (sharing.isEconomicUnitDef(unitDef) and
								not sharing.isT2ConstructorDef(unitDef))
		else
			allowed = true
		end
		
		if allowed then
			allowedUnits[unitDefID] = true
		end
	end
	
	local count = 0
	for _ in pairs(allowedUnits) do count = count + 1 end
	Spring.Log("[UNIT SHARING MODE]", LOG.INFO, "Cached " .. count .. " allowed units for mode: " .. unitSharingMode)
end

initializeAllowedUnits()

-- Register validator for unit sharing mode restrictions
GG.TeamTransfer.RegisterValidator({
	dependsOn = { SharedEnums.TransferCategory.UNIT_TRANSFER }
}, function(ctx)
	-- Only validate unit transfers
	if not ctx.unitDefID then
		return true
	end
	
	-- Check if unit sharing is enabled and this specific unit is allowed
	local unitAllowed = allowedUnits[ctx.unitDefID] == true
	
	if not unitAllowed then
		-- Provides mode-specific explanations: "Unit sharing is disabled", "Share mode is T2 constructors only", etc.
		local reason = sharing.blockMessage(1, unitSharingMode)
		return false, reason
	end
	
	return true
end)
