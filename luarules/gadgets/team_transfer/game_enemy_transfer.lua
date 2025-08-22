local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

TeamTransfer.RegisterPolicy(function(policy)
	policy.ResourceTransfers.Enemy:Use(function(ctx)
		if ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
			return true
		end
		return false
	end)

	policy.UnitTransfers.Enemy:Use(function(ctx)
		if ctx.capture then
			return true
		end
		if ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
			return true
		end
		return false
	end)
end)
