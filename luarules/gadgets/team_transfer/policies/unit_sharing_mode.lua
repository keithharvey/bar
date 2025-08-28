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

-- Register policy that exposes unit sharing mode data to UI
GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.UnitSharingMode, function(policy)
	policy.ForAlliedUnitTransfers.Use(function(ctx)
		-- Count shareable/unshareable units in current selection
		local shareableCount = 0
		local unshareableCount = 0
		local selectedUnitIDs = ctx.selectedUnitIDs or {}

		for _, unitID in ipairs(selectedUnitIDs) do
			if Spring.ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == ctx.senderTeamId then
				local unitDefID = Spring.GetUnitDefID(unitID)
				if unitDefID and allowedUnits[unitDefID] then
					shareableCount = shareableCount + 1
				else
					unshareableCount = unshareableCount + 1
				end
			end
		end

		local canShareUnits = shareableCount > 0
		local blockReason = nil

		if unitSharingMode == "disabled" then
			canShareUnits = false
			blockReason = "Unit sharing is disabled"
		elseif not canShareUnits and #selectedUnitIDs > 0 then
			blockReason = sharing.blockMessage(unshareableCount, unitSharingMode)
		end

		---@type RawUnitTransferExpose
		local unitExpose = {
			canShareUnits = canShareUnits,  -- Required by pipeline converter
			shareableUnitCount = shareableCount,
			unshareableUnitCount = unshareableCount,
			blockReason = blockReason,  -- Required by pipeline converter
			-- Policy-specific data (not used by pipeline converter)
			allowedUnits = allowedUnits,
			sharingMode = unitSharingMode,
			_policyData = {
				sharingMode = unitSharingMode
			}
		}

		return {
			expose = {
				[SharedEnums.TransferCategory.UNIT_TRANSFER] = unitExpose
			}
		}
	end)

	-- Also register validator for unit sharing mode restrictions
	policy.ForAlliedUnitTransfers.Use(function(ctx)
		-- Only validate unit transfers
		if not ctx.unitDefID then
			return { allow = true }
		end

		-- Check if unit sharing is enabled and this specific unit is allowed
		local unitAllowed = allowedUnits[ctx.unitDefID] == true

		if not unitAllowed then
			return {
				deny = true,
				blockReason = sharing.blockMessage(1, unitSharingMode)
			}
		end

		return { allow = true }
	end)
end)
