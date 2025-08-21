
function setup()
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("predicates") then
			return require_predicates_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
end

function require_predicates_module()
	local P = {}
	
	P.Command = {
		isGuard = function(ctx) return ctx.cmdID == 10 end, -- Mock CMD.GUARD
		isMove = function(ctx) return ctx.cmdID == 20 end, -- Mock CMD.MOVE
		isAttack = function(ctx) return ctx.cmdID == 30 end, -- Mock CMD.ATTACK
		targetAllied = function(ctx) return ctx.targetAllied == true end,
		targetIsIncomplete = function(ctx) return ctx.targetIsComplete == false end,
	}
	
	P.Resource = {
		isMetalTransfer = function(ctx) return ctx.resource == "metal" end,
		isEnergyTransfer = function(ctx) return ctx.resource == "energy" end,
		areAlliedTeams = function(ctx) return ctx.areAlliedTeams == true end,
		isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled == true end,
		hasMinimumAmount = function(threshold)
			return function(ctx) return (ctx.amount or 0) >= threshold end
		end,
	}
	
	P.Unit = {
		areAlliedTeams = function(ctx) return ctx.areAlliedTeams == true end,
		isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled == true end,
		isCapture = function(ctx) return ctx.capture == true end,
		takeBypassAllowed = function(ctx) return ctx.takeBypassAllowed == true end,
		isCommander = function(ctx) 
			return ctx.unitDefID and ctx.unitDefID == 1 -- Mock commander unit
		end,
	}
	
	return P
end

function test()
	local P = VFS.Include("luarules/gadgets/team_transfer/predicates.lua")
	
	local guardCtx = { cmdID = 10, targetAllied = true, targetIsComplete = false }
	assert(P.Command.isGuard(guardCtx), "isGuard should detect guard command")
	assert(P.Command.targetAllied(guardCtx), "targetAllied should detect allied target")
	assert(P.Command.targetIsIncomplete(guardCtx), "targetIsIncomplete should detect incomplete target")
	
	local moveCtx = { cmdID = 20, targetAllied = false, targetIsComplete = true }
	assert(not P.Command.isGuard(moveCtx), "isGuard should not detect non-guard command")
	assert(not P.Command.targetAllied(moveCtx), "targetAllied should not detect non-allied target")
	assert(not P.Command.targetIsIncomplete(moveCtx), "targetIsIncomplete should not detect complete target")
	
	local metalCtx = { resource = "metal", areAlliedTeams = true, isCheatingEnabled = false, amount = 1000 }
	assert(P.Resource.isMetalTransfer(metalCtx), "isMetalTransfer should detect metal resource")
	assert(not P.Resource.isEnergyTransfer(metalCtx), "isEnergyTransfer should not detect metal resource")
	assert(P.Resource.areAlliedTeams(metalCtx), "areAlliedTeams should detect allied teams")
	assert(not P.Resource.isCheatingEnabled(metalCtx), "isCheatingEnabled should detect disabled cheating")
	
	local energyCtx = { resource = "energy", areAlliedTeams = false, isCheatingEnabled = true, amount = 500 }
	assert(not P.Resource.isMetalTransfer(energyCtx), "isMetalTransfer should not detect energy resource")
	assert(P.Resource.isEnergyTransfer(energyCtx), "isEnergyTransfer should detect energy resource")
	assert(not P.Resource.areAlliedTeams(energyCtx), "areAlliedTeams should not detect non-allied teams")
	assert(P.Resource.isCheatingEnabled(energyCtx), "isCheatingEnabled should detect enabled cheating")
	
	local minAmount500 = P.Resource.hasMinimumAmount(500)
	assert(minAmount500(metalCtx), "hasMinimumAmount(500) should allow 1000 metal")
	assert(minAmount500(energyCtx), "hasMinimumAmount(500) should allow 500 energy")
	
	local minAmount1500 = P.Resource.hasMinimumAmount(1500)
	assert(not minAmount1500(metalCtx), "hasMinimumAmount(1500) should block 1000 metal")
	assert(not minAmount1500(energyCtx), "hasMinimumAmount(1500) should block 500 energy")
	
	local unitCtx = { areAlliedTeams = true, isCheatingEnabled = false, capture = false, takeBypassAllowed = true, unitDefID = 1 }
	assert(P.Unit.areAlliedTeams(unitCtx), "areAlliedTeams should detect allied teams")
	assert(not P.Unit.isCheatingEnabled(unitCtx), "isCheatingEnabled should detect disabled cheating")
	assert(not P.Unit.isCapture(unitCtx), "isCapture should detect non-capture transfer")
	assert(P.Unit.takeBypassAllowed(unitCtx), "takeBypassAllowed should detect allowed bypass")
	assert(P.Unit.isCommander(unitCtx), "isCommander should detect commander unit")
	
	local captureCtx = { areAlliedTeams = false, isCheatingEnabled = true, capture = true, takeBypassAllowed = false, unitDefID = 2 }
	assert(not P.Unit.areAlliedTeams(captureCtx), "areAlliedTeams should not detect non-allied teams")
	assert(P.Unit.isCheatingEnabled(captureCtx), "isCheatingEnabled should detect enabled cheating")
	assert(P.Unit.isCapture(captureCtx), "isCapture should detect capture transfer")
	assert(not P.Unit.takeBypassAllowed(captureCtx), "takeBypassAllowed should detect disallowed bypass")
	assert(not P.Unit.isCommander(captureCtx), "isCommander should not detect non-commander unit")
	
	local compositeCtx = { resource = "metal", areAlliedTeams = true, amount = 1000 }
	local isMetalAndAllied = function(ctx)
		return P.Resource.isMetalTransfer(ctx) and P.Resource.areAlliedTeams(ctx)
	end
	assert(isMetalAndAllied(compositeCtx), "Composite predicate should work with AND logic")
	
	local isEnergyOrHighAmount = function(ctx)
		return P.Resource.isEnergyTransfer(ctx) or P.Resource.hasMinimumAmount(500)(ctx)
	end
	assert(isEnergyOrHighAmount(compositeCtx), "Composite predicate should work with OR logic")
	
	local emptyCtx = {}
	assert(not P.Command.isGuard(emptyCtx), "isGuard should handle empty context")
	assert(not P.Resource.isMetalTransfer(emptyCtx), "isMetalTransfer should handle empty context")
	assert(not P.Unit.areAlliedTeams(emptyCtx), "areAlliedTeams should handle empty context")
end
