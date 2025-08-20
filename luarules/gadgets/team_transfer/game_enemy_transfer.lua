local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Definitions = VFS.Include("luarules/gadgets/team_transfer/definitions.lua")

API.RegisterPolicy(function(policy)
	policy:For(Definitions.PolicyType.ResourceTransfer)
	:When(function(ctx) return not ctx.areAlliedTeams end)
	:Use(function(ctx)
		if ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
			return true
		end
		return false
	end)

	policy:For(Definitions.PolicyType.UnitTransfer)
	:Use(function(ctx)
		if ctx.capture then
			return true
		end
		if not ctx.areAlliedTeams then
			if ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
				return true
			end
			return false
		end
		return nil
	end)
end)
