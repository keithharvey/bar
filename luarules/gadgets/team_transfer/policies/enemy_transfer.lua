-- Team Transfer Policy: Enemy Transfer
-- Handles resource and unit transfers between enemy teams

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

Spring.Log("[ENEMY TRANSFER POLICY]", LOG.ERROR, "Loading enemy transfer policy")

local function shouldAllowResourceTransfer(ctx)
	return ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer
end

local function shouldAllowUnitTransfer(ctx)
	if ctx.capture then
		return true
	end
	return ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer
end

GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.EnemyTransfer, function(policy)
	policy.ForEnemyResourceTransfers.Use(function(ctx)
		Spring.Log("[ENEMY TRANSFER POLICY]", LOG.ERROR, "Enemy resource transfer policy called - this should only happen for enemy transfers!")
		if shouldAllowResourceTransfer(ctx) then
			return { allow = true }
		end
		return { deny = true }
	end)

	policy.ForEnemyUnitTransfers.Use(function(ctx)
		Spring.Log("[ENEMY TRANSFER POLICY]", LOG.ERROR, "Enemy unit transfer policy called - this should only happen for enemy transfers!")
		if shouldAllowUnitTransfer(ctx) then
			return { allow = true }
		end
		return { deny = true }
	end)
end)
