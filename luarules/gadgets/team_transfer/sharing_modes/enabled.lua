local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.Enabled,
    name = "Enabled",
    desc = "All sharing on with fixed defaults.",
    allowRanked = true,
    modOptions = {
        [ModOptions.Options.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Enabled,
            locked = true,
        },
        [ModOptions.Options.TaxResourceSharingAmount] = {
            value = 0.0,
            locked = true,
        },
        [ModOptions.Options.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
            ui = "hidden"
        },
        [ModOptions.Options.AlliedAssist] = {
            value = SharedEnums.AlliedAssistMode.Enabled,
            locked = true,
        },
        [ModOptions.Options.AlliedReclaim] = {
            value = SharedEnums.AlliedReclaimMode.Enabled,
            locked = true,
        },
    }
}
