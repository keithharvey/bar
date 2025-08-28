-- Team Transfer Policy: Allied Reclaim
-- Controls whether allied units can perform reclaim commands and assist allied reclaim operations
-- Blocks reclaim commands and guard commands to allied units with reclaim capability when disabled (default behavior)

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Check modoption to see if allied reclaim is disabled
local modOptions = Spring.GetModOptions()
local reclaimDisabled = modOptions and modOptions.allied_reclaim ~= "enabled"

Spring.Log("[ALLIED RECLAIM POLICY]", LOG.ERROR, "Allied reclaim policy loading - disabled: " .. tostring(reclaimDisabled))

-- Only register policy if disabled (when enabled, normal behavior applies)
if not reclaimDisabled then
	Spring.Log("[ALLIED RECLAIM POLICY]", LOG.ERROR, "Policy not registering - allied reclaim enabled")
	return
end

GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.AlliedReclaim, function(policy)
	-- Block reclaim commands to allied units
	policy.ForAlliedCommands.WhenReclaim.Deny()

	-- Allow reclaim commands to enemy units
	policy.ForEnemyCommands.WhenReclaim.Allow()

	-- Block guard commands that target allied units with reclaim capability
	policy.ForAlliedCommands.WhenGuard.Use(function(ctx)
		local ud = ctx.targetUnitDef
		if ud and ud.canReclaim == true then
			Spring.Log("[ALLIED RECLAIM POLICY]", LOG.ERROR, "Blocking allied guard command to unit with reclaim")
			return { deny = true }
		end
		return { allow = true }
	end)

	-- Allow guard commands that target enemy units with reclaim capability
	policy.ForEnemyCommands.WhenGuard.Use(function(ctx)
		local ud = ctx.targetUnitDef
		if ud and ud.canReclaim == true then
			return { allow = true }
		end
		return { allow = true }
	end)
end)
