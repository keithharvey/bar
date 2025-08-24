local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Policy: System Cleanup',
		desc    = 'Handles standard cleanup operations during transfers and team events (clear load orders, self-destruct, etc.)',
		author  = 'quantum, Bluestone, Devin',
		date    = 'July 13, 2008 - Aug 2025',
		license = 'GNU GPL, v2 or later',
		layer   = -99999, -- Run early to clean up before other policies
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local function cleanup(ctx)
	return { 
		applyCommands = { 
			ClearLoad = { ctx.unitID },    -- Prevent load order exploits
			ClearSelfD = { ctx.unitID }    -- Prevent self-destruct on transfer
		} 
	}
end

-- This system policy handles standard cleanup operations that should
-- almost always happen during transfers and team events to prevent exploits
-- and maintain game integrity.
-- This is a great list of things to fix in the engine.
GG.TeamTransfer.RegisterPolicy(function(policy)
	policy.ForAlliedUnitTransfers.Use(cleanup)
	policy.ForEnemyUnitTransfers.Use(cleanup)
	
	policy.TeamEvents.PlayerAbandoned.Use(function(ctx)
		return { 
			applyCommands = { 
				ClearTeamSelfD = { ctx.teamID }
			} 
		}
	end)
end)
