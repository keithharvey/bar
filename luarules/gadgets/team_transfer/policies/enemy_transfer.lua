local function shouldAllowResourceTransfer(ctx)
	return ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer
end

local function shouldAllowUnitTransfer(ctx)
	if ctx.capture then
		return true
	end
	return ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer
end

GG.TeamTransfer.RegisterPolicy(function(policy)
	policy.ResourceTransfers.Enemy:Use(function(ctx)
		if shouldAllowResourceTransfer(ctx) then
			return true
		end
		return false
	end)

	policy.UnitTransfers.Enemy:Use(function(ctx)
		if shouldAllowUnitTransfer(ctx) then
			return true
		end
		return false
	end)
end)
