
-- Team Transfer Policy: Building Unlocks Sharing
-- Enables sharing features based on built structure categories

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Shared logging utility
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES

local SharingUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_utils.lua")

local TransferCategory = SharedEnums.TransferCategory

-- Respect modoption toggle
local enabled = false
do
    local ok, value = SharingUtils.IsSharingOption("building_unlocks_sharing")
    enabled = ok and (value == true or value == "1" or value == 1 or value == "true") or ok
end
if not enabled then return end

local function hasBuiltCategories(teamId, categories)
    local required = {}
    for i = 1, #categories do
        required[categories[i]] = true
    end
    local seen = {}
    local units = Spring.GetTeamUnits(teamId) or {}
    for i = 1, #units do
        local unitID = units[i]
        local unitDefID = Spring.GetUnitDefID(unitID)
        if unitDefID then
            local ud = UnitDefs[unitDefID]
            if ud and ud.name then
                local catName = BuildingCategoryDefinitions.unitCategories[ud.name:lower()]
                if catName and required[catName] then
                    seen[catName] = true
                end
            end
        end
    end
    for cat, _ in pairs(required) do
        if not seen[cat] then
            return false
        end
    end
    return true
end

LogDebug("Loading building_unlocks_sharing policy")

-- these two are not possible right now due to engine restrictions:
-- Building Energy Storage enables you to use the ENERGY transfer slider + overflow E teammates
-- policy.AfterBuildingCategories(BuildingCategories.ENERGY_STORAGE).Use(function(ctx) {
--   policy.ForAlliedCommands.WhenEnergyTransferSlider.Allow()
-- })
-- -- Building Metal Storage enables you to use the METAL transfer slider + overflow M to teammates
-- policy.AfterBuildingCategories(BuildingCategories.METAL_STORAGE).Use(function(ctx) {
--   policy.ForAlliedCommands.WhenMetalTransferSlider.Allow()
-- })
-- -- Building both Metal Storage and Energy Storage enables you to assist teammates through buildpower (which is effectively M+E sharing)

GG.TeamTransfer.RegisterPolicy("building_unlocks_sharing", function(policy)
    policy.ForAlliedCommands.WhenGuard.Use(function(ctx)
        local ok = hasBuiltCategories(ctx.senderTeamId, { BuildingCategories.METAL_STORAGE, BuildingCategories.ENERGY_STORAGE })
        ---@type DefaultCommandValidationResult
        local expose = {
            allowGuardCommands = ok,
            allowRepairCommands = ctx.defaultCommandValidation.allowRepairCommands,
            allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
            blockReason = ok and nil or "Requires Metal + Energy Storage",
        }
        return {
            allow = ok,
            expose = {
                [TransferCategory.CommandValidation] = expose,
            }
        }
    end)

    policy.ForAlliedCommands.WhenRepair.Use(function(ctx)
        local ok = hasBuiltCategories(ctx.senderTeamId, { BuildingCategories.METAL_STORAGE, BuildingCategories.ENERGY_STORAGE })
        ---@type DefaultCommandValidationResult
        local expose = {
            allowGuardCommands = ctx.defaultCommandValidation.allowGuardCommands,
            allowRepairCommands = ok,
            allowReclaimCommands = ctx.defaultCommandValidation.allowReclaimCommands,
            blockReason = ok and nil or "Requires Metal + Energy Storage",
        }
        return {
            allow = ok,
            expose = {
                [TransferCategory.CommandValidation] = expose,
            }
        }
    end)

    -- Building Pinpointer enables you to transfer buildings and units (t2 cons come to mind)
    policy.ForAlliedUnitTransfers.Use(function(ctx)
        local ok = hasBuiltCategories(ctx.senderTeamId, { BuildingCategories.PINPOINTER })
        ---@type UnitSharingModeResult
        local expose = {
            canShareUnits = ok,
            blockReason = ok and nil or "Requires Pinpointer",
            sharingMode = "enabled",
            takeBypass = ctx.defaultUnitTransfer.takeBypass,
            allowedUnits = {},
        }
        return {
            allow = ok,
            expose = {
                [TransferCategory.UnitTransfer] = expose,
            }
        }
    end)
end)


