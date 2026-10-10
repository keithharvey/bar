local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local TechEnums = require("modules/tech/enums")

---@type TransferContract
local Transfer = Policies.Contract(Modules.Transfer)

-- Under tech blocking a team still at tier one takes no units from allies: it has not earned them yet
--
---@class TechUnitTransferSteps: PolicySteps<TransferContext, UnitTransferTerms>
---@field ReceiverAtTierOne "ReceiverAtTierOne"

---@type TechUnitTransferSteps
local UnitTransfer = {
	ReceiverAtTierOne = "ReceiverAtTierOne",
}
Policy.Contributes(Transfer.UnitTransfer, UnitTransfer)

-- The guard says when. What a refused transfer looks like is transfer's to say, and it says it once, in its Refusal:
-- this file never sees the shape, and the tooltip reads the same fields off a refusal tech caused as off transfer's own.
Policies.On(UnitTransfer).Unless(UnitTransfer.ReceiverAtTierOne, function(ctx)
	if not ctx.modOptions[TechEnums.ModOptions.TechBlocking] then
		return false
	end
	local level = tonumber(ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "tech_level")) or 1
	return level < 2
end)

---@class (partial) TechContract
local Contract = {}
Contract.UnitTransfer = UnitTransfer

return Contract
