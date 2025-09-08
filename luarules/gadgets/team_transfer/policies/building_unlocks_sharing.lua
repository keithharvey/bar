local FluentPolicy = VFS.Include("luarules/gadgets/team_transfer/fluent_policy.lua")
local UnitRepository = VFS.Include("luarules/gadgets/team_transfer/unit_repository.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES

-- there is a few weak points to this system. Mostly because we have to cache EVERY team unit, but I guess that's probably a reasonable expectation for other features so I'm leaving it for now.
-- alternate design: we could simply track building categories in Repository and various variants of that. Allowing the Repository to abstract UnitCreated into a policy hook, or allow api_gadgets to do that
    local function hasBuiltCategories(teamId, categories)
    local required = {}
    for i = 1, #categories do
        required[categories[i]] = true
    end

    local seen = {}

    local teamUnits = UnitRepository.getTeamUnits(teamId)
    for unitID, unitDefID in pairs(teamUnits) do
        local unitName
        if type(unitDefID) == "string" then
            unitName = unitDefID
        else
            local ud = UnitDefs[unitDefID]
            unitName = ud and ud.name or nil
        end
        if unitName then
            local catName = BuildingCategoryDefinitions.unitCategories[unitName:lower()]
            if catName and required[catName] then
                seen[catName] = true
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

FluentPolicy.RegisterPolicy(SharedEnums.Policies.BuildingUnlocksSharing, function(policy)
    local modOptions = Spring.GetModOptions()
    local buildingUnlocksSharing = modOptions and modOptions[SharedEnums.Policies.BuildingUnlocksSharing]
    if not buildingUnlocksSharing then
        return
    end

    -- TODO: Engine restrictions prevent this from working
    -- Building Energy Storage enables you to use the ENERGY transfer slider + overflow E teammates
    -- TODO: Engine restrictions prevent this from working
    -- -- Building Metal Storage enables you to use the METAL transfer slider + overflow M to teammates

    -- -- Building both Metal Storage and Energy Storage enables you to assist teammates through buildpower (which is effectively M+E sharing)
    local bothStorages = function(ctx)
        return hasBuiltCategories(ctx.senderTeamId, {
            BuildingCategories.METAL_STORAGE,
            BuildingCategories.ENERGY_STORAGE
        })
    end
    -- Commands policy - allow when both storages exist
    policy:Allied():Guard():When(bothStorages):Allow()
    policy:Allied():Repair():When(bothStorages):Allow()
    policy:Allied():Reclaim():When(bothStorages):Allow()
    policy:Allied():MetalTransfers():When(bothStorages):Allow()
    policy:Allied():EnergyTransfers():When(bothStorages):Allow()

    -- Unit transfer policy - allow when pinpointer built
    policy:Allied():UnitTransfers():When(function(ctx)
        return hasBuiltCategories(ctx.senderTeamId, {
            BuildingCategories.PINPOINTER
        })
    end):Allow()
end)