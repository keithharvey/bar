local Comms = require("modules/transfer/resource/comms")
local Contract = require("modules/transfer/contract")
local ModuleHandler = require("modules/module_handler")
local Shared = require("modules/transfer/resource/shared")
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

---@class TransferResourceResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId integer
---@field receiverTeamId integer
---@field policyResult TransferResourcePolicyResult? absent when the transfer was denied before a policy resolved

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

local policyResultPool = {} ---@type table<ResourceName, TransferResourcePolicyResult>

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return number
local function resolveEffectiveRate(ctx, resourceType)
	local perResource = ctx.taxRates and ctx.taxRates[resourceType]
	local taxRate = (perResource or ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)) --[[@as number]]
	return math.min(taxRate, 1)
end

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return TransferResourcePolicyResult
function Gadgets.CalcResourcePolicy(ctx, resourceType)
	local result = policyResultPool[resourceType]
	if not result then
		result = {} --[[@as TransferResourcePolicyResult]]
		policyResultPool[resourceType] = result
	end
	local policy = Contract.ResourceTransfer
	return ModuleHandler.Evaluate(policy, ctx, resourceType, resolveEffectiveRate(ctx, resourceType), result)
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
---@param ctx TransferPolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
	local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
	local effectiveRate = resolveEffectiveRate(ctx, resourceType)
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

return Gadgets
