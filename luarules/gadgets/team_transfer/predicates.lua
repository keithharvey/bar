---@diagnostic disable: undefined-global
---@module "luarules/gadgets/team_transfer/predicates"

---@class TeamTransferPredicates
---@field Command TeamTransferPredicatesCommand
---@field Resource TeamTransferPredicatesResource
---@field Unit TeamTransferPredicatesUnit
---@type TeamTransferPredicates
local P = { Command = {}, Resource = {}, Unit = {} }

---@class TeamTransferPredicatesCommand
---@field isGuard fun(ctx: TeamTransferPolicyContext): boolean
---@field isRepair fun(ctx: TeamTransferPolicyContext): boolean
---@field isReclaim fun(ctx: TeamTransferPolicyContext): boolean
---@field targetAllied fun(ctx: TeamTransferPolicyContext): boolean
---@field targetHasAssist fun(ctx: TeamTransferPolicyContext): boolean
---@field targetHasReclaim fun(ctx: TeamTransferPolicyContext): boolean
---@field targetIsIncomplete fun(ctx: TeamTransferPolicyContext): boolean
---@type TeamTransferPredicatesCommand
-- fields populated below
P.Command = P.Command

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


---@class TeamTransferPredicatesResource
---@field isMetalTransfer fun(ctx: TeamTransferPolicyContext): boolean
---@field isEnergyTransfer fun(ctx: TeamTransferPolicyContext): boolean
---@field areAlliedTeams fun(ctx: TeamTransferPolicyContext): boolean
---@field isCheatingEnabled fun(ctx: TeamTransferPolicyContext): boolean
---@type TeamTransferPredicatesResource
-- fields populated below
P.Resource = P.Resource
P.Resource.isMetalTransfer = function(ctx) return ctx.resource == "metal" end
P.Resource.isEnergyTransfer = function(ctx) return ctx.resource == "energy" end
P.Resource.areAlliedTeams = function(ctx) return ctx.areAlliedTeams end
P.Resource.isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end

---@class TeamTransferPredicatesUnit
---@field areAlliedTeams fun(ctx: TeamTransferPolicyContext): boolean
---@field isCheatingEnabled fun(ctx: TeamTransferPolicyContext): boolean
---@field isCapture fun(ctx: TeamTransferPolicyContext): boolean
---@field takeBypassAllowed fun(ctx: TeamTransferPolicyContext): boolean
---@type TeamTransferPredicatesUnit
-- fields populated below
P.Unit = P.Unit
P.Unit.areAlliedTeams = function(ctx) return ctx.areAlliedTeams end
P.Unit.isCheatingEnabled = function(ctx) return ctx.isCheatingEnabled end
P.Unit.isCapture = function(ctx) return ctx.capture end
P.Unit.takeBypassAllowed = function(ctx) return ctx.takeBypassAllowed end

---@return TeamTransferPredicates
return P
