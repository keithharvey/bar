local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

return {
    key = SharedEnums.SharingModes.BuildingUnlocks,
    name = "Building Unlocks",
    desc = "Unlock sharing via buildings; per-unit limits via Unit Sharing Mode.",
    allowRanked = true,
    modOptions = {
        [ModOptions.Options.BuildingUnlocksSharing] = {
            value = SharedEnums.BuildingUnlocksSharingMode.Enabled,
            locked = true,
        },
        [ModOptions.Options.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Enabled,
            locked = false,
        },
    }
}
