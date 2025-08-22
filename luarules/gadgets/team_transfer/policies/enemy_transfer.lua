local PolicyManager = VFS.Include("luarules/gadgets/team_transfer/policy_manager.lua")

local function shouldAllowResourceTransfer(ctx)
	return ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer
end

local function shouldAllowUnitTransfer(ctx)
	if ctx.capture then
		return true
	end
	return ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer
end

PolicyManager.registerConfig("enemy_transfer", {
	enabled = true,
	description = "Handles resource and unit transfers between enemy teams",
	registrar = function(policy)
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
	end
})
