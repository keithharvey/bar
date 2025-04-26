local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@type PolicyModule
local module = {
    name = SharedEnums.Policies.EnemyReclaim,
    func = function(builder)
        builder:Enemy():Reclaim():Allow()
    end,
    enabled = function(ctx)
        return true
    end
}
return module
