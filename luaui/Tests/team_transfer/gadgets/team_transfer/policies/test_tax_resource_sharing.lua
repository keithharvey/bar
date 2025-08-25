function setup()
	_G.GG = _G.GG or {}
	_G.Spring = _G.Spring or {}
	
	GG.TeamTransfer = {
		ResourceShareTax = {
			computeTransfer = function(resource, amount, taxRate, threshold, cumulative)
				local actualSent = amount
				local actualReceived = amount * (1 - taxRate)
				return {
					actualSent = actualSent,
					actualReceived = actualReceived
				}
			end
		},
		Predicates = {
			Command = {
				targetHasReclaim = function(ctx)
					return ctx.targetHasReclaim == true
				end
			}
		},
		MODOPTION_KEYS = {
			TAX_RESOURCE_SHARING_AMOUNT = "tax_resource_sharing_amount",
			PLAYER_METAL_SEND_THRESHOLD = "player_metal_send_threshold"
		},
		IsSharingOption = function(key)
			if key == "tax_resource_sharing_amount" then
				return true, "0.1"
			elseif key == "player_metal_send_threshold" then
				return true, "500"
			end
			return false, nil
		end,
		RegisterPolicy = function(fn)
			local mockPolicy = {
				ForAlliedResourceTransfers = {
					Use = function(handler)
						_G.resourceTransferHandler = handler
					end
				},
				ForAlliedCommands = {
					WhenReclaim = { Deny = function() _G.alliedReclaimDenied = true end },
					WhenGuard = {
						Use = function(handler)
							_G.alliedGuardHandler = handler
						end
					}
				},
				ForEnemyCommands = {
					WhenReclaim = { Allow = function() _G.enemyReclaimAllowed = true end },
					WhenGuard = {
						Use = function(handler)
							_G.enemyGuardHandler = handler
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
	_G.Spring = nil
	_G.resourceTransferHandler = nil
	_G.alliedReclaimDenied = nil
	_G.enemyReclaimAllowed = nil
	_G.alliedGuardHandler = nil
	_G.enemyGuardHandler = nil
end

function test()
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForAlliedResourceTransfers.Use(function(ctx)
			if ctx.amountClamped <= 0 then
				return { allow = false }
			end

			local cumulative = (ctx.resource == "metal") and (ctx.cumulativeMetal or 0) or 0
			local breakdown = GG.TeamTransfer.ResourceShareTax.computeTransfer(ctx.resource, ctx.amountClamped, "0.1", "500", cumulative)

			local sent = math.min(breakdown.actualSent or 0, ctx.amount)
			local received = math.min(breakdown.actualReceived or 0, ctx.amountClamped)

			return {
				applyTransfer = {
					sent = sent,
					received = received,
					updateCumulativeMetal = (ctx.resource == "metal"),
				},
				expose = {
					taxRate = "0.1",
					threshold = "500",
				}
			}
		end)

		policy.ForAlliedCommands.WhenReclaim.Deny()
		policy.ForEnemyCommands.WhenReclaim.Allow()
		
		policy.ForAlliedCommands.WhenGuard.Use(function(ctx)
			if GG.TeamTransfer.Predicates.Command.targetHasReclaim(ctx) then
				return { deny = true }
			end
			return { allow = true }
		end)
		
		policy.ForEnemyCommands.WhenGuard.Use(function(ctx)
			if GG.TeamTransfer.Predicates.Command.targetHasReclaim(ctx) then
				return { allow = true }
			end
			return { allow = true }
		end)
	end)
	
	assert(_G.resourceTransferHandler ~= nil, "Should register resource transfer handler")
	assert(_G.alliedReclaimDenied, "Should deny allied reclaim commands")
	assert(_G.enemyReclaimAllowed, "Should allow enemy reclaim commands")
	assert(_G.alliedGuardHandler ~= nil, "Should register allied guard handler")
	assert(_G.enemyGuardHandler ~= nil, "Should register enemy guard handler")
	
	local resourceCtx = {
		resource = "metal",
		amount = 1000,
		amountClamped = 1000,
		cumulativeMetal = 0
	}
	local resourceResult = _G.resourceTransferHandler(resourceCtx)
	assert(resourceResult.applyTransfer ~= nil, "Should apply transfer for valid resource transfer")
	assert(resourceResult.applyTransfer.sent == 1000, "Should send full amount")
	assert(resourceResult.applyTransfer.received == 900, "Should receive amount minus tax")
	assert(resourceResult.applyTransfer.updateCumulativeMetal == true, "Should update cumulative metal")
	assert(resourceResult.expose.taxRate == "0.1", "Should expose tax rate")
	assert(resourceResult.expose.threshold == "500", "Should expose threshold")
	
	local zeroCtx = {
		resource = "metal",
		amount = 0,
		amountClamped = 0,
		cumulativeMetal = 0
	}
	local zeroResult = _G.resourceTransferHandler(zeroCtx)
	assert(zeroResult.allow == false, "Should not allow zero amount transfers")
	
	local guardCtx = { targetHasReclaim = true }
	local alliedGuardResult = _G.alliedGuardHandler(guardCtx)
	assert(alliedGuardResult.deny == true, "Should deny allied guard on reclaim target")
	
	local enemyGuardResult = _G.enemyGuardHandler(guardCtx)
	assert(enemyGuardResult.allow == true, "Should allow enemy guard on reclaim target")
	
	local nonReclaimGuardCtx = { targetHasReclaim = false }
	local alliedNonReclaimResult = _G.alliedGuardHandler(nonReclaimGuardCtx)
	assert(alliedNonReclaimResult.allow == true, "Should allow allied guard on non-reclaim target")
end
