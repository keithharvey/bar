
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")
local UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")

local UnitSharingMode = ModOptions.Options.UnitSharingMode

local allowedUnits = {}

---Evaluate if a unit should be allowed based on sharing mode
---@param unitDef table Unit definition from UnitDefs
---@param mode string The sharing mode
---@return boolean allowed True if unit should be allowed
local function evaluateUnitForSharing(unitDef, mode)
	if not unitDef then return false end
	
	-- Simple cases
	if mode == SharedEnums.UnitSharingMode.Disabled then
		return false
	end
	
	if mode == SharedEnums.UnitSharingMode.Enabled then
		return true
	end

	local unitType = UnitSharing.classifyUnitDef(unitDef)
	
	
	-- Mode-specific logic using enum
	if mode == SharedEnums.UnitSharingMode.CombatUnits then
		return unitType == SharedEnums.UnitType.Combat
	end
	
	if mode == SharedEnums.UnitSharingMode.Economic then
		return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor
	end
	
	if mode == SharedEnums.UnitSharingMode.EconomicPlusBuildings then
		return unitType == SharedEnums.UnitType.Economic or unitType == SharedEnums.UnitType.T2Constructor or unitType == SharedEnums.UnitType.Utility
	end
	
	if mode == SharedEnums.UnitSharingMode.T2Cons then
		return unitType == SharedEnums.UnitType.T2Constructor
	end
	
	if mode == SharedEnums.UnitSharingMode.CombatT2Cons then
		return unitType == SharedEnums.UnitType.Combat or unitType == SharedEnums.UnitType.T2Constructor
	end
	
	return false
end

---@param ctx RegisterInitializePolicyContext
---@param unitSharingMode string The sharing mode from mod options
local function initializeAllowedUnitsCache(ctx, unitSharingMode)
	-- Clear existing cache first
	allowedUnits = {}
	
	local unitDefs = ctx.repositories.springRepo.GetUnitDefs()
	local cachedCount = 0

	for unitDefID, unitDef in pairs(unitDefs) do
		local allowed = evaluateUnitForSharing(unitDef, unitSharingMode)

		if allowed then
			allowedUnits[unitDefID] = true
			cachedCount = cachedCount + 1
		end
	end
end

---@param builder DSL
local function BuildPolicy(builder)
	local unitSharingMode = builder.mod_options[UnitSharingMode]

	builder:RegisterInitialize(function(ctx)
		initializeAllowedUnitsCache(ctx, unitSharingMode)
	end)

	builder:UnitTransfers()
		:Use(function(ctx)
			return {
				expose = {
					canShareUnits = unitSharingMode ~= SharedEnums.UnitSharingMode.Disabled,
					sharingMode = unitSharingMode,
					blockReason = unitSharingMode == SharedEnums.UnitSharingMode.Disabled and SharedEnums.BlockReason.Disabled or nil,
				}
			}
		end)

	builder:RegisterUnitTransferValidator(function(ctx)
		local unitDefId = ctx.repositories.springRepo:GetUnitDefID(ctx.unitID)
		local valid = allowedUnits[unitDefId] ~= nil

		---@type UnitValidationResult
		local validationResult = {
			ok = valid,
			reason = SharedEnums.BlockReason.UnitSharingMode,
			unitId = ctx.unitID,
			translationTokens = {
				unitSharingMode = unitSharingMode,
			}
		}
		return validationResult
	end)
end

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.UnitSharingMode,
    func = BuildPolicy,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        return modOptions[UnitSharingMode] ~= nil
    end
}
return module
