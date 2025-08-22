local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

local function enemyResourceTransfers(allowCondition)
	return function(policy)
		return policy:For(TeamTransfer.PolicyType.ResourceTransfer)
			:When(function(ctx) return not ctx.areAlliedTeams end)
			:Use(allowCondition)
	end
end

local function enemyUnitTransfers(allowCondition)
	return function(policy)
		return policy:For(TeamTransfer.PolicyType.UnitTransfer)
			:Use(allowCondition)
	end
end

TeamTransfer.RegisterPolicy(function(policy)
	enemyResourceTransfers(function(ctx)
		if ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
			return true
		end
		return false
	end)(policy)

	enemyUnitTransfers(function(ctx)
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
	end)(policy)
end)
