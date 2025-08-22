local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: Enemy Transfer',
		desc    = 'Handles resource and unit transfers between enemy teams',
		author  = 'Devin',
		date    = 'Aug 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

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
