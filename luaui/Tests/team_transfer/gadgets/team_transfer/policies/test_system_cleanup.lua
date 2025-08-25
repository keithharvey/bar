function setup()
	_G.GG = _G.GG or {}
	
	GG.TeamTransfer = {
		RegisterPolicy = function(fn)
			local mockPolicy = {
				ForAlliedUnitTransfers = {
					Use = function(handler)
						_G.alliedUnitHandler = handler
					end
				},
				ForEnemyUnitTransfers = {
					Use = function(handler)
						_G.enemyUnitHandler = handler
					end
				},
				TeamEvents = {
					PlayerAbandoned = {
						Use = function(handler)
							_G.playerAbandonedHandler = handler
						end
					}
				}
			}
			fn(mockPolicy)
		end
	}
end

function cleanup()
	_G.GG = nil
	_G.alliedUnitHandler = nil
	_G.enemyUnitHandler = nil
	_G.playerAbandonedHandler = nil
end

function test()
	GG.TeamTransfer.RegisterPolicy(function(policy)
		local function cleanup(ctx)
			return { 
				applyCommands = { 
					ClearLoad = { ctx.unitID },
					ClearSelfD = { ctx.unitID }
				} 
			}
		end

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
	
	assert(_G.alliedUnitHandler ~= nil, "Should register allied unit transfer handler")
	assert(_G.enemyUnitHandler ~= nil, "Should register enemy unit transfer handler")
	assert(_G.playerAbandonedHandler ~= nil, "Should register player abandoned handler")
	
	local unitCtx = { unitID = 123 }
	local alliedResult = _G.alliedUnitHandler(unitCtx)
	assert(alliedResult.applyCommands ~= nil, "Should apply cleanup commands for allied transfers")
	assert(alliedResult.applyCommands.ClearLoad ~= nil, "Should clear load orders")
	assert(alliedResult.applyCommands.ClearLoad[1] == 123, "Should clear load for correct unit")
	assert(alliedResult.applyCommands.ClearSelfD ~= nil, "Should clear self-destruct orders")
	assert(alliedResult.applyCommands.ClearSelfD[1] == 123, "Should clear self-destruct for correct unit")
	
	local enemyResult = _G.enemyUnitHandler(unitCtx)
	assert(enemyResult.applyCommands ~= nil, "Should apply cleanup commands for enemy transfers")
	assert(enemyResult.applyCommands.ClearLoad ~= nil, "Should clear load orders for enemy transfers")
	assert(enemyResult.applyCommands.ClearSelfD ~= nil, "Should clear self-destruct orders for enemy transfers")
	
	local teamCtx = { teamID = 456 }
	local abandonedResult = _G.playerAbandonedHandler(teamCtx)
	assert(abandonedResult.applyCommands ~= nil, "Should apply cleanup commands for abandoned player")
	assert(abandonedResult.applyCommands.ClearTeamSelfD ~= nil, "Should clear team self-destruct orders")
	assert(abandonedResult.applyCommands.ClearTeamSelfD[1] == 456, "Should clear self-destruct for correct team")
end
