local P = {}

P.Command = {}

function P.Command.isGuard(ctx)
	return ctx.cmdID == CMD.GUARD and ctx.targetID ~= nil
end

function P.Command.isRepair(ctx)
	return ctx.cmdID == CMD.REPAIR and ctx.targetID ~= nil
end

function P.Command.isReclaim(ctx)
	return ctx.cmdID == CMD.RECLAIM and ctx.targetID ~= nil and ctx.targetID < Game.maxUnits
end

function P.Command.targetAllied(ctx)
	return ctx.targetAllied == true
end

function P.Command.targetHasAssist(ctx)
	local ud = ctx.targetUnitDef
	if not ud then return false end
	local hasBuildOptions = ud.buildOptions and #ud.buildOptions > 0 or false
	return hasBuildOptions or (ud.canAssist == true)
end

function P.Command.targetHasReclaim(ctx)
	local ud = ctx.targetUnitDef
	if not ud then return false end
	return ud.canReclaim == true
end

function P.Command.targetIsIncomplete(ctx)
	return ctx.targetIsComplete == false
end


P.Resource = {
	isMetalTransfer = function(ctx) return ctx.resource == "metal" end,
	isEnergyTransfer = function(ctx) return ctx.resource == "energy" end,
	areAlliedTeams = function(ctx) return ctx.areAlliedTeams end,
	isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end,
}

P.Unit = {
	areAlliedTeams = function(ctx) return ctx.areAlliedTeams end,
	isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end,
	isCapture = function(ctx) return ctx.capture end,
	takeBypassAllowed = function(ctx) return ctx.takeBypassAllowed end,
}

return P
