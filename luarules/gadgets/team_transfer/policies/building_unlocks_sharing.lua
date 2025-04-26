local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local BuildingCategoryDefinitions = VFS.Include("luaui/Include/blueprint_substitution/definitions.lua")
local BuildingCategories = BuildingCategoryDefinitions.BUILDING_CATEGORIES
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

local function hasBuiltCategories(teamId, categories, springRepo)
    local required = {}
    for i = 1, #categories do
        required[categories[i]] = true
    end

    local seen = {}

    local teamUnits = springRepo:GetTeamUnits(teamId)

    for unitID, unitDefId in pairs(teamUnits) do
        local catName = BuildingCategoryDefinitions.getCategory(unitDefId)
        if catName and required[catName] then
            seen[catName] = true
        end
    end

    for cat, _ in pairs(required) do
        if not seen[cat] then
            return false
        end
    end
    return true
end

---@param builder DSL
local function policyFunction(builder)
    local function hasBothStorages(ctx)
        local springRepo = ctx.repositories and ctx.repositories.springRepo
        return hasBuiltCategories(ctx.senderTeamId, {
            BuildingCategories.METAL_STORAGE,
            BuildingCategories.ENERGY_STORAGE
        }, springRepo)
    end

    local function hasPinpointer(ctx)
        local springRepo = ctx.repositories and ctx.repositories.springRepo
        return hasBuiltCategories(ctx.senderTeamId, {
            BuildingCategories.PINPOINTER,
        }, springRepo)
    end

    builder:MetalTransfers():When(hasBothStorages):Allow()
    builder:EnergyTransfers():When(hasBothStorages):Allow()

    builder:UnitTransfers():When(hasPinpointer):Allow()
end

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.BuildingUnlocksSharing,
    func = policyFunction,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        local mode = modOptions[ModOptions.Options.BuildingUnlocksSharing]
        return mode == SharedEnums.BuildingUnlocksSharingMode.Enabled
    end
}
return module