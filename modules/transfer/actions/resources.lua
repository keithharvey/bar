local Comms = require("modules/transfer/resource/comms")
local ContextFactory = require("modules/transfer/context_factory")
local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local ResourceTransfer = require("modules/transfer/resource/synced")

---@class TransferResourcesRequest
---@field from integer giving team
---@field to integer receiving team
---@field resource "metal"|"energy"
---@field amount number
---@field grant TransferResourcePolicyResult the pair's policy result for this resource, as the api resolved it

---@param request table unvalidated; validate is what makes it a TransferResourcesRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.resources expects a request table"
	end
	if type(request.from) ~= "number" or type(request.to) ~= "number" then
		return false, "transfer.resources needs from and to team ids"
	end
	if request.from == request.to then
		return false, "a team cannot send resources to itself"
	end
	if request.resource ~= "metal" and request.resource ~= "energy" then
		return false, 'transfer.resources needs resource = "metal" or "energy"'
	end
	if type(request.amount) ~= "number" or request.amount <= 0 then
		return false, "transfer.resources needs a positive amount"
	end
	if type(request.grant) ~= "table" then
		return false, "transfer.resources needs the grant the api resolves"
	end
	return true
end)

---@param request TransferResourcesRequest
---@return TransferResourceResult
Actions.RegisterExecute(function(request)
	local from, to, resource, amount = request.from, request.to, request.resource, request.amount
	local springRepo = Spring
	local policyResult = request.grant
	local ctx = ContextFactory.create(springRepo).resourceTransfer(from, to, resource, amount, policyResult)
	local result = ResourceTransfer.ResourceTransfer(ctx)

	local applied = result.policyResult
	if result.success and applied then
		ManualShareLedger.Record(from, to, applied.resourceType, result.sent, result.received)
		Comms.SendTransferChatMessages(result, applied)
	end

	return result
end)
