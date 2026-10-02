local Comms = require("modules/transfer/resource/comms")
local ContextFactory = require("modules/transfer/context_factory")
local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Shared = require("modules/transfer/resource/shared")
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

---@class TransferResourceResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId integer
---@field receiverTeamId integer
---@field policyResult ResourceTransferTerms? absent when the transfer was denied before a policy resolved

local ResourceType = TransferEnums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local Gadgets = {
	SendTransferChatMessages = Comms.SendTransferChatMessages,
}

---@param ctx TransferResourceRequest
---@return TransferResourceResult
function Gadgets.ResourceTransfer(ctx)
	local policyResult = ctx.policyResult
	local desiredAmount = ctx.desiredAmount
	if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
		---@type TransferResourceResult
		return {
			success = false,
			sent = 0,
			received = 0,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			policyResult = policyResult,
		}
	end

	local received, sent = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)

	local springRepo = ctx.springRepo
	local resourceType = policyResult.resourceType
	local senderCurrent = springRepo.GetTeamResources(ctx.senderTeamId, resourceType) or 0
	springRepo.SetTeamResource(ctx.senderTeamId, resourceType, math.max(0, senderCurrent - sent))
	springRepo.AddTeamResource(ctx.receiverTeamId, resourceType, received)

	---@type TransferResourceResult
	local result = {
		success = true,
		sent = sent,
		received = received,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		policyResult = policyResult,
	}

	return result
end

---@param ctx TransferContext
---@return number
local function resolveEffectiveRate(ctx)
	local taxRate = (ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)) --[[@as number]]
	return math.min(taxRate, 1)
end

---@param ctx TransferContext the pairing
---@param resourceType ResourceName the resource asked about
---@return ResourceTransferTerms
function Gadgets.CalcResourcePolicy(ctx, resourceType)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	local ask = setmetatable({ resourceType = resourceType, taxRate = resolveEffectiveRate(ctx) }, { __index = ctx }) --[[@as TransferResourceContext]]
	return ModuleHandler.Evaluate(Transfer.ResourceTransfer, ask)
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---@param springRepo Spring
---@param teamId integer
---@param resourceType ResourceName
---@param ctx TransferContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
	local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
	local effectiveRate = resolveEffectiveRate(ctx)
	local isNonPlayer = Shared.IsNonPlayerTeam(springRepo, teamId)
	local active = teamActive(springRepo, teamId)
	local factor = {
		taxedSendable = math.max(0, data.current) * (1 - effectiveRate),
		taxRate = effectiveRate,
		capacity = data.storage - data.current,
		isNonPlayer = isNonPlayer,
		active = active,
	}
	Shared.ResourceFactor(resourceType).Write(springRepo, teamId, factor, { "taxRate", "active", "isNonPlayer" })
end

---@param springRepo Spring
---@param frame number
---@param lastUpdate number
---@param updateRate number
---@param contextFactory table
---@return number lastUpdate New last update frame
function Gadgets.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
	if frame < lastUpdate + updateRate then
		return lastUpdate
	end

	contextFactory.clearResourceCache()

	local allTeams = springRepo.GetTeamList()
	for _, teamId in ipairs(allTeams) do
		local ctx = contextFactory.policy(teamId, teamId)
		Gadgets.CacheTeamFactor(springRepo, teamId, METAL, ctx)
		Gadgets.CacheTeamFactor(springRepo, teamId, ENERGY, ctx)
	end

	return frame
end

---@param reason string
---@return nil
local function refused(reason)
	Spring.Log("transfer", LOG.WARNING, "transfer.resources refused: " .. reason)
	return nil
end

-- A resource shared under the policy: the pair's terms for that resource tax and cap it, the ledger records what
-- moved, and both teams are told.
---@param resource ResourceName
---@param amount number
---@param toTeamID integer
---@param fromTeamID integer
---@return TransferResourceResult|nil result nil when the share is refused outright
function Gadgets.Share(resource, amount, toTeamID, fromTeamID)
	if fromTeamID == toTeamID then
		return refused("a team cannot send resources to itself")
	end
	if resource ~= METAL and resource ~= ENERGY then
		return refused("a resource is metal or energy")
	end
	if amount <= 0 then
		return refused("nothing to send")
	end
	local terms = Shared.GetCachedTerms(fromTeamID, toTeamID, resource, Spring)
	if terms == nil then
		return refused("no terms are cached for these teams yet")
	end
	local ctx = ContextFactory.create(Spring).resourceTransfer(fromTeamID, toTeamID, resource, amount, terms)
	local result = Gadgets.ResourceTransfer(ctx)
	local applied = result.policyResult
	if result.success and applied then
		ManualShareLedger.Record(fromTeamID, toTeamID, applied.resourceType, result.sent, result.received)
		Comms.SendTransferChatMessages(result, applied)
	end
	return result
end

---@param teamID integer
---@param resource ResourceName
---@param delta number
local function adjust(teamID, resource, delta)
	local current = Spring.GetTeamResources(teamID, resource) or 0
	Spring.SetTeamResource(teamID, resource, current + delta)
end

-- A resource handed over by fiat: the whole amount, both sides, untaxed, no policy asked.
---@param resource ResourceName
---@param amount number
---@param toTeamID integer
---@param fromTeamID integer
---@return number moved
function Gadgets.Give(resource, amount, toTeamID, fromTeamID)
	if fromTeamID == toTeamID or amount <= 0 then
		return 0
	end
	adjust(fromTeamID, resource, -amount)
	adjust(toTeamID, resource, amount)
	return amount
end

return Gadgets
