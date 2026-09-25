local Construction = require("modules/construction/api")
local Shared = require("modules/transfer/unit/shared")
local TransferEnums = require("modules/transfer/enums")
local UnitSharingCategories = require("modules/transfer/unit/categories")

---@param unitID integer
---@param unitDefID integer
---@param policyResult TransferUnitPolicyResult
local function applyStun(unitID, unitDefID, policyResult)
	local buildDelaySeconds = tonumber(policyResult.buildDelaySeconds) or 0
	if buildDelaySeconds > 0 and UnitSharingCategories.isMobileBuilderDef(UnitDefs[unitDefID]) then
		Construction.DelayBuilder(unitID, buildDelaySeconds)
		return
	end

	local stunSeconds = tonumber(policyResult.stunSeconds) or 0
	if stunSeconds <= 0 then
		return
	end

	local stunCategory = policyResult.stunCategory
	if not stunCategory or not Shared.IsShareableDef(unitDefID, stunCategory, UnitDefs) then
		return
	end
	local _, maxHealth = Spring.GetUnitHealth(unitID)
	Spring.AddUnitDamage(unitID, maxHealth * 5, stunSeconds)
end

---@class TransferUnitResult
---@field success boolean
---@field outcome string TransferEnums.UnitValidationOutcome
---@field senderTeamId integer
---@field receiverTeamId integer
---@field validationResult TransferUnitValidation
---@field policyResult TransferUnitPolicyResult

---@class TransferUnitsRequest
---@field from integer giving team
---@field to integer receiving team
---@field unitIDs integer[]
---@field grant TransferUnitPolicyResult the pair's policy result, as the api resolved it
---@field validation TransferUnitValidation the grant applied to each unit

---@param request table unvalidated; validate is what makes it a TransferUnitsRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.units expects a request table"
	end
	if type(request.from) ~= "number" or type(request.to) ~= "number" then
		return false, "transfer.units needs from and to team ids"
	end
	if request.from == request.to then
		return false, "a team cannot share with itself"
	end
	if type(request.unitIDs) ~= "table" or #request.unitIDs == 0 then
		return false, "transfer.units needs a non-empty unitIDs list"
	end
	if type(request.grant) ~= "table" or type(request.validation) ~= "table" then
		return false, "transfer.units needs the grant and validation the api resolves"
	end
	if not request.grant.canShare then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	if request.validation.status == TransferEnums.UnitValidationOutcome.Failure then
		return false, "none of the units may pass under the active mode"
	end
	return true
end)

---@param request TransferUnitsRequest
---@return TransferUnitResult
Actions.RegisterExecute(function(request)
	local from, to = request.from, request.to
	local policyResult, validation = request.grant, request.validation

	for _, unitID in ipairs(validation.validUnitIds) do
		Spring.TransferUnit(unitID, to, true)
		local unitDefID = Spring.GetUnitDefID(unitID) --[[@as integer?]]
		if unitDefID then
			applyStun(unitID, unitDefID, policyResult)
		end
	end
	Spring.SendLuaUIMsg("unit_transfer:success:" .. from, "")

	---@type TransferUnitResult
	return {
		success = true,
		outcome = validation.status,
		senderTeamId = from,
		receiverTeamId = to,
		validationResult = validation,
		policyResult = policyResult,
	}
end)
