-- Team Transfer Policy: Idle Players Check
-- Prevents resource and unit transfers to teams with no active players
-- Integrates with cmd_idle_players.lua gadget for player state tracking

Spring.Log("[IDLE PLAYERS POLICY]", LOG.ERROR, "Loading idle players transfer policy")

local function hasActivePlayers(teamID)
	if not teamID then return false end
	local numActive = Spring.GetTeamRulesParam(teamID, "numActivePlayers")
	return numActive and numActive ~= 0
end

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.IdlePlayersCheck, function(policy)
	policy.ForAlliedResourceTransfers.Use(function(ctx)
		-- Only block transfers to idle/abandoned teams
		-- Let other policies continue evaluating if receiver has active players
		if not ctx.isCheatingEnabled and not hasActivePlayers(ctx.receiverTeamId) then
			Spring.Log("[IDLE PLAYERS POLICY]", LOG.ERROR, "BLOCKED resource transfer to idle team " .. ctx.receiverTeamId .. " (no active players)")
			return { deny = true }
		end
		-- Continue to next policy (don't return anything)
		Spring.Log("[IDLE PLAYERS POLICY]", LOG.ERROR, "ALLOWED resource transfer to team " .. ctx.receiverTeamId .. " (has active players or cheating enabled)")
		return nil
	end)
	
	policy.ForEnemyResourceTransfers.Use(function(ctx)
		-- Same logic for enemy transfers
		if ctx.isCheatingEnabled or hasActivePlayers(ctx.receiverTeamId) then
			return { allow = true }
		end
		return { deny = true }
	end)
	
	policy.ForAlliedUnitTransfers.Use(function(ctx)
		-- Only block unit transfers to idle/abandoned teams (except captures)
		if not ctx.capture and not ctx.isCheatingEnabled and not hasActivePlayers(ctx.toTeamID) then
			Spring.Log("[IDLE PLAYERS POLICY]", LOG.ERROR, "BLOCKED unit transfer to idle team " .. ctx.toTeamID .. " (no active players)")
			return { deny = true }
		end
		-- Continue to next policy
		Spring.Log("[IDLE PLAYERS POLICY]", LOG.ERROR, "ALLOWED unit transfer to team " .. ctx.toTeamID .. " (capture=" .. tostring(ctx.capture) .. ", has active players or cheating enabled)")
		return nil
	end)
	
	policy.ForEnemyUnitTransfers.Use(function(ctx)
		-- Same logic for enemy unit transfers
		if ctx.capture or ctx.isCheatingEnabled or hasActivePlayers(ctx.toTeamID) then
			return { allow = true }
		end
		return { deny = true }
	end)
end)
