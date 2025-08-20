local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

API.RegisterPolicy(function(policy)
	policy:For(Definitions.PolicyType.ResourceTransfer)
	:When(function(ctx) return not ctx.areAlliedTeams end)
	:Use(function(ctx)
		return false
	end)

	policy:For(Definitions.PolicyType.UnitTransfer)
	:Use(function(ctx)
		if ctx.capture then
			return true
		end
		if not ctx.areAlliedTeams then
			return false
		end
		return nil
	end)
end)
