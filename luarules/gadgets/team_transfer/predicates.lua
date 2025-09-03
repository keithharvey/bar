---@diagnostic disable: undefined-global
---@module "luarules/gadgets/team_transfer/predicates"

--- A factory for creating named predicate objects
---@param name string The name for the predicate (for logging)
---@param fn fun(ctx: TeamTransferPolicyContext): boolean The predicate logic
---@return Predicate
local function definePredicate(name, fn)
	return { name = name, fn = fn }
end

---@class TeamTransferPredicates
---@field Command TeamTransferPredicatesCommand
---@field Resource TeamTransferPredicatesResource
---@field Unit TeamTransferPredicatesUnit
---@field TeamEvent TeamTransferPredicatesTeamEvent
---@type TeamTransferPredicates
local P = { Command = {}, Resource = {}, Unit = {}, TeamEvent = {} }

---@class TeamTransferPredicatesCommand
---@type table<string, Predicate>
P.Command = {
	isGuard = definePredicate("isGuard", function(ctx)
		return ctx.cmdID == CMD.GUARD and ctx.targetID ~= nil
	end),
	isRepair = definePredicate("isRepair", function(ctx)
		return ctx.cmdID == CMD.REPAIR and ctx.targetID ~= nil
	end),
	isReclaim = definePredicate("isReclaim", function(ctx)
		return ctx.cmdID == CMD.RECLAIM and ctx.targetID ~= nil and ctx.targetID < Game.maxUnits
	end),
	targetAllied = definePredicate("targetAllied", function(ctx)
		return ctx.targetAllied == true
	end),
	targetEnemy = definePredicate("targetEnemy", function(ctx)
		return ctx.targetAllied == false
	end),
	targetHasAssist = definePredicate("targetHasAssist", function(ctx)
		local ud = ctx.targetUnitDef
		if not ud then return false end
		local hasBuildOptions = ud.buildOptions and #ud.buildOptions > 0 or false
		return hasBuildOptions or (ud.canAssist == true)
	end),
	targetHasReclaim = definePredicate("targetHasReclaim", function(ctx)
		local ud = ctx.targetUnitDef
		if not ud then return false end
		return ud.canReclaim == true
	end),
	targetIsIncomplete = definePredicate("targetIsIncomplete", function(ctx)
		return ctx.targetIsComplete == false
	end),
}

---@class TeamTransferPredicatesResource
---@type table<string, Predicate>
P.Resource = {
	isMetalTransfer = definePredicate("isMetalTransfer", function(ctx) return ctx.resource == SharedEnums.ResourceType.METAL end),
	isEnergyTransfer = definePredicate("isEnergyTransfer", function(ctx) return ctx.resource == SharedEnums.ResourceType.ENERGY end),
	areAlliedTeams = definePredicate("areAlliedTeams", function(ctx) return ctx.areAlliedTeams end),
	isCheatingEnabled = definePredicate("isCheatingEnabled", function(ctx) return ctx.isCheatingEnabled end),
}

---@class TeamTransferPredicatesUnit
---@type table<string, Predicate>
P.Unit = {
	areAlliedTeams = definePredicate("areAlliedTeams", function(ctx) return ctx.areAlliedTeams end),
	isCheatingEnabled = definePredicate("isCheatingEnabled", function(ctx) return ctx.isCheatingEnabled end),
	isCapture = definePredicate("isCapture", function(ctx) return ctx.capture end),
	takeBypassAllowed = definePredicate("takeBypassAllowed", function(ctx) return ctx.takeBypassAllowed end),
}

---@class TeamTransferPredicatesTeamEvent
---@type table<string, Predicate>
P.TeamEvent = {
	isPlayerAbandoned = definePredicate("isPlayerAbandoned", function(ctx)
		return ctx.eventType == "PlayerAbandoned"
	end),
	isPlayerReconnected = definePredicate("isPlayerReconnected", function(ctx)
		return ctx.eventType == "PlayerReconnected"
	end),
}

---@return TeamTransferPredicates
return P
