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

-- The step has to return the refusal itself. transfer's refused terms are `terms(ctx, false)`, a local in
-- modules/transfer/policies/unit_transfer.lua: stun seconds, stun category, sharing modes, build delay. Nothing on the
-- contract can carry a function, so from here the choice is to copy transfer's shape into tech, or to return the only
-- refusal a stranger can: false. This file returns false. The spec shows what the tooltip then reads.
Policies.On(UnitTransfer).Step(UnitTransfer.ReceiverAtTierOne, function(ctx)
	if not ctx.modOptions[TechEnums.ModOptions.TechBlocking] then
		return
	end
	local level = tonumber(ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "tech_level")) or 1
	if level < 2 then
		return false
	end
end)

---@class (partial) TechContract
local Contract = {}
Contract.UnitTransfer = UnitTransfer

return Contract
