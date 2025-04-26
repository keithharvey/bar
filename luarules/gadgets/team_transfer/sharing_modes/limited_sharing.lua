local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type SharingModeConfig
return {
    key = SharedEnums.SharingModes.LimitedSharing,
    name = "Limited Sharing",
    desc = "Allow T2 constructor trades, otherwise restrict; 30% tax; 440m threshold.",
    allowRanked = true,
    modOptions = {
        [ModOptions.Options.UnitSharingMode] = {
            value = SharedEnums.UnitSharingMode.T2Cons,
            locked = true,
        },
        [ModOptions.Options.TaxResourceSharingAmount] = {
            value = 0.30,
            locked = false,
            bounds = { min = 0, max = 0.6, step = 0.01 }
        },
        [ModOptions.Options.PlayerMetalSendThreshold] = {
            value = 440,
            locked = false,
            bounds = { min = 200, max = 1000, step = 10 }
        },
        [ModOptions.Options.PlayerEnergySendThreshold] = {
            value = 0,
            locked = true,
        },
        [ModOptions.Options.AssistAlly] = {
            value = SharedEnums.AssistAllyMode.Enabled,
            locked = true,
        },
        [ModOptions.Options.AlliedReclaim] = {
            value = SharedEnums.AlliedReclaimMode.Enabled,
            locked = true,
        },
    }
}
