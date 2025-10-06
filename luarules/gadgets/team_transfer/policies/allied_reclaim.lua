local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")

---@type PolicyModule
local module = {
	name = SharedEnums.Policies.AlliedReclaim,
    func = function(builder)
        local reclaimValue = builder.mod_options[ModOptions.Options.AlliedReclaim]

		if reclaimValue == SharedEnums.AlliedReclaimMode.Disabled then
			builder:Reclaim():Deny(SharedEnums.BlockReason.PolicyDenied)
		else
			builder:Allied():Reclaim():Allow()
		end
    end,
    enabled = function(ctx)
        return true
    end
}
return module
