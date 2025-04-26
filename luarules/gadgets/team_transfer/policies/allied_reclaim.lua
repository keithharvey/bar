local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type PolicyModule
local module = {
	name = SharedEnums.Policies.AlliedReclaim,
    func = function(builder)
		builder:Allied():Reclaim():Allow()
    end,
    enabled = function(ctx)
        local modOptions = ctx.repositories.springRepo:GetModOptions()
        local reclaimValue = modOptions[ModOptions.Options.AlliedReclaim]
        return reclaimValue == SharedEnums.AlliedReclaimMode.Enabled
    end
}
return module
