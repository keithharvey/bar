function setup()
	_G.GG = _G.GG or {}
	
	GG.TeamTransfer = {
		RegisterPolicy = function(fn)
			local mockPolicy = {
				ForEnemyResourceTransfers = {
					Use = function(handler) 
						_G.enemyResourceHandler = handler
					end
				},
				ForEnemyUnitTransfers = {
					Use = function(handler)
						_G.enemyUnitHandler = handler
					end
				}
			}
			fn(mockPolicy)
		end
	}
end

function cleanup()
	_G.GG = nil
	_G.enemyResourceHandler = nil
	_G.enemyUnitHandler = nil
end

function test()
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForEnemyResourceTransfers.Use(function(ctx)
			if ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer then
				return { allow = true }
			end
			return { deny = true }
		end)

		policy.ForEnemyUnitTransfers.Use(function(ctx)
			if ctx.capture then
				return true
			end
			if ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer then
				return { allow = true }
			end
			return { deny = true }
		end)
	end)
	
	assert(_G.enemyResourceHandler ~= nil, "Should register enemy resource transfer handler")
	assert(_G.enemyUnitHandler ~= nil, "Should register enemy unit transfer handler")
	
	local resourceCtx = {
		isCheatingEnabled = false,
		senderIsNonPlayer = false,
		receiverIsNonPlayer = false
	}
	local resourceResult = _G.enemyResourceHandler(resourceCtx)
	assert(resourceResult.deny == true, "Should deny resource transfer between enemy players")
	
	resourceCtx.isCheatingEnabled = true
	resourceResult = _G.enemyResourceHandler(resourceCtx)
	assert(resourceResult.allow == true, "Should allow resource transfer when cheating enabled")
	
	resourceCtx.isCheatingEnabled = false
	resourceCtx.senderIsNonPlayer = true
	resourceResult = _G.enemyResourceHandler(resourceCtx)
	assert(resourceResult.allow == true, "Should allow resource transfer from non-player")
	
	resourceCtx.senderIsNonPlayer = false
	resourceCtx.receiverIsNonPlayer = true
	resourceResult = _G.enemyResourceHandler(resourceCtx)
	assert(resourceResult.allow == true, "Should allow resource transfer to non-player")
	
	local unitCtx = {
		capture = false,
		isCheatingEnabled = false,
		fromIsNonPlayer = false,
		toIsNonPlayer = false
	}
	local unitResult = _G.enemyUnitHandler(unitCtx)
	assert(unitResult.deny == true, "Should deny unit transfer between enemy players")
	
	unitCtx.capture = true
	unitResult = _G.enemyUnitHandler(unitCtx)
	assert(unitResult == true, "Should allow capture transfers")
	
	unitCtx.capture = false
	unitCtx.isCheatingEnabled = true
	unitResult = _G.enemyUnitHandler(unitCtx)
	assert(unitResult.allow == true, "Should allow unit transfer when cheating enabled")
	
	unitCtx.isCheatingEnabled = false
	unitCtx.fromIsNonPlayer = true
	unitResult = _G.enemyUnitHandler(unitCtx)
	assert(unitResult.allow == true, "Should allow unit transfer from non-player")
	
	unitCtx.fromIsNonPlayer = false
	unitCtx.toIsNonPlayer = true
	unitResult = _G.enemyUnitHandler(unitCtx)
	assert(unitResult.allow == true, "Should allow unit transfer to non-player")
end
