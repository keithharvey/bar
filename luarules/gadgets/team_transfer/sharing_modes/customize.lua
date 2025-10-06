local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.Customize,
    name = "Customize",
    desc = "Choose your own settings.",
    allowRanked = false,
    modOptions = {
        [ModOptions.Options.UnitSharingMode] = {
            locked = false,
        },
        [ModOptions.Options.TaxResourceSharingAmount] = {
            locked = false
        },
        [ModOptions.Options.PlayerMetalSendThreshold] = {
            value = 0,
            locked = false
        },
        [ModOptions.Options.AlliedAssist] = {
            locked = false
        },
        [ModOptions.Options.AlliedReclaim] = {
            locked = false
        },
    }
}
