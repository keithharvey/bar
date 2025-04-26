local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.NoSharing,
    name = "No Sharing",
    desc = "Disable all sharing; apply a 30% tax; lock most controls.",
    allowRanked = true,
    modOptions = {
        [ModOptions.Options.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.Disabled,
            locked = true,
        },
        [ModOptions.Options.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
            bounds = { min = 0.20, max = 0.40 }
        },
        [ModOptions.Options.PlayerMetalSendThreshold] = {
            value = 0,
            locked = true,
        },
        [ModOptions.Options.AssistAlly] = {
            value = SharedEnums.AssistAllyMode.Disabled,
            locked = true,
        },
        [ModOptions.Options.AlliedReclaim] = {
            value = SharedEnums.AlliedReclaimMode.Disabled,
            locked = true,
        },
    }
}
