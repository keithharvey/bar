local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.AssistAlly,
    func = function(builder)
		builder:Allied():Guard():Allow()
		builder:Allied():Repair():Allow()
    end,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        local assistValue = modOptions[ModOptions.Options.AssistAlly]
        return assistValue == SharedEnums.AssistAllyMode.Enabled
    end
}
return module
