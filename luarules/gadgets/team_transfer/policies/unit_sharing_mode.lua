-- Team Transfer Policy: Unit Sharing Mode
-- Exposes unit sharing restrictions based on configured sharing mode
--
-- AST Tree: Declarative Policy Language with Optimized Caching
-- ┌─────────────────────────────────────────────────────────────┐
-- │ UnitSharingMode Policy                                     │
-- │ └─► Initialize Cache: UnitDef lookups once at load time    │
-- │    └─► Expose sharing mode data as strongly typed         │
-- │       └─► Widget layer uses cached data for validation    │
-- └─────────────────────────────────────────────────────────────┘
--
-- PERFORMANCE OPTIMIZATION:
-- - UnitDef iterations happen once during gadget initialization
-- - Leverages existing UnitSharing cache to avoid duplication
-- - Runtime policy evaluation uses cached results only
-- - No expensive Spring.GetUnitDefID calls during expose phase

local gadget = gadget ---@type Gadget

-- Shared logging utility
-- Removed shared_logging dependency
-- Removed Logger dependencies - using Spring.Log directly

local sharing = GG.TeamTransfer.UnitSharing
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")
local modoption = SharedEnums.Policies.UnitSharingMode

local enabled, unitSharingMode = SharingUtils.IsSharingOption(modoption)
if not enabled or unitSharingMode == "enabled" then
	return
end

-- Policy enum shortcuts for cleaner code
local UnitSharingMode = GG.TeamTransfer.Policies.UNIT_SHARING_MODE
local TransferCategory = GG.TeamTransfer.SharedEnums.TransferCategory

-- Cached unit sets for efficient lookup - populated during RegisterInitialize
local allowedUnits = {} -- Set of unitDefIDs that are allowed in current mode
local unitSharingEnabled = unitSharingMode ~= "disabled"

--- Initialize allowed units cache using existing UnitSharing caching
--- This leverages the existing lazy cache in unit_sharing.lua to avoid
--- redundant UnitDef iterations and expensive unit definition lookups
local function initializeAllowedUnitsCache()
	allowedUnits = {}

	if unitSharingMode == "disabled" then
		-- No units allowed
		return
	end

	-- Leverage existing UnitSharing caching mechanism
	-- This ensures we only iterate through UnitDefs once per mode
	local cachedCount = 0

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
			cachedCount = cachedCount + 1
		end
	end

	-- Also initialize the UnitSharing cache for this mode to avoid future lookups
	if unitSharingMode ~= "enabled" then
		sharing.isCacheInitialized(unitSharingMode)
	end

	Spring.Log("[UNIT_SHARING_MODE]", "info","Initialized cache with " .. cachedCount .. " allowed units for mode: " .. unitSharingMode)
end

-- Initialize the cache once during policy loading
-- This happens when the gadget loads, before any runtime policy evaluation
Spring.Log("[UNIT_SHARING_MODE]", "info","Initializing cache during policy load for mode: " .. unitSharingMode)
initializeAllowedUnitsCache()

GG.TeamTransfer.RegisterPolicy(UnitSharingMode, function(policy)
	-- Core functional policy: determine if unit sharing is globally allowed
	policy.ForAlliedUnitTransfers.Use(function(ctx)
		-- Check if unit sharing is enabled at all for this mode
		local canShareUnits = (unitSharingMode ~= "disabled")
		local blockReason = nil
		
		if not canShareUnits then
			blockReason = "Unit sharing is disabled"
		end
		
		Spring.Log("[UNIT_SHARING_MODE]", "debug",string.format("[UNIT_SHARING_MODE] POLICY mode=%s, canShare=%s", 
			unitSharingMode, tostring(canShareUnits)))
		
		return {
			allow = canShareUnits,
			expose = {
				[SharedEnums.TransferCategory.UnitTransfer] = {
					canShareUnits = canShareUnits,
					blockReason = blockReason,
					-- Additional policy-specific data for validators/UI
					sharingMode = unitSharingMode,
					allowedUnits = allowedUnits -- Cache for validator use
				}
			}
		}
	end)
end)

-- Register validator for unit transfer decisions (handles per-unit selection validation)
GG.TeamTransfer.RegisterUnitTransferValidator(function(ctx, unitResults)
	Spring.Log("[UNIT_SHARING_MODE]", "debug","[UNIT_SHARING_MODE] Validator called for unit transfer")
	
	-- Cast to unit sharing mode specific result data to access policy-specific fields
	---@type UnitSharingModeResult
	local unitSharingData = unitResults
	
	---@type UnitTransferValidationResult
	local validationResult = {
		canShare = unitSharingData.canShareUnits,
		shareableCount = 0,
		unshareableCount = 0,
		blockReason = unitSharingData.blockReason
	}
	-- If the policy already blocked sharing globally, respect that
	if not unitSharingData.canShareUnits then
		return validationResult
	end
	
	local selectedUnits = ctx.selectedUnitIDs or {}
	
	-- If no units selected, validation passes (state query)
	if #selectedUnits == 0 then
		return validationResult
	end
	
	-- Check each selected unit against the sharing mode restrictions
	for _, unitID in ipairs(selectedUnits) do
		if Spring.ValidUnitID(unitID) then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID then
				if unitSharingData.allowedUnits[unitDefID] then
					validationResult.shareableCount = validationResult.shareableCount + 1
				else
					validationResult.unshareableCount = validationResult.unshareableCount + 1
				end
			end
		end
	end
	
	Spring.Log("[UNIT_SHARING_MODE]", "debug",string.format("[UNIT_SHARING_MODE] VALIDATOR mode=%s, selected=%d, shareable=%d, result=ALLOW",
		unitSharingData.sharingMode, #validationResult.selectedUnits, #validationResult.shareableCount))
	
	return validationResult
end)