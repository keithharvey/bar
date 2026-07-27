--- Synced contract of the transfer module: the one way things change hands.
---
--- Every verb here runs a declared action from actions/ — validate, then
--- execute — so the module has exactly one effectful path per capability and
--- the framework can see it. This file holds no state and makes no decisions;
--- it is the calling convention, not the behaviour.

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")

-- Refilled per call: the engine asks this once per unit per transfer attempt.
local mayUnitScratch = {}
local mayValidationScratch = {}

---Run a declared action: refuse on its own precondition, never halfway.
---@param name string action file name under actions/
---@param request table
---@return any result
local function perform(name, request)
	local action = ModuleHandler.LoadActions("transfer").byName[name]
	assert(action, "transfer has no action named " .. tostring(name))
	if action.validate then
		local allowed, reason = action.validate(request)
		if not allowed then
			Spring.Log("transfer", LOG.WARNING, "transfer." .. name .. " refused: " .. tostring(reason))
			return nil
		end
	end
	return action.execute(request)
end

return {
	---Hand units to another team through the sharing pipeline: the active
	---mode's policy decides whether it happens at all, and what it costs.
	---A caller that wants the transfer regardless of policy wants Give.
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@param fromTeamID integer the team being asked to give them up
	---@return UnitTransferResult
	Units = function(unitIDs, toTeamID, fromTeamID)
		return perform("units", { from = fromTeamID, to = toTeamID, unitIDs = unitIDs })
	end,

	---Send metal or energy, priced by the active mode.
	---@param resource ResourceName
	---@param amount number
	---@param toTeamID integer
	---@param fromTeamID integer
	---@return ResourceTransferResult
	Resources = function(resource, amount, toTeamID, fromTeamID)
		return perform("resources", { from = fromTeamID, to = toTeamID, resource = resource, amount = amount })
	end,

	---May this one unit move between these teams? The engine asks through
	---AllowUnitTransfer; the gadget there is an adapter, and this is the
	---answer — so an engine hook and a deliberate share cannot disagree.
	---@param unitID integer
	---@param fromTeamID integer
	---@param toTeamID integer
	---@param capture boolean|nil engine-driven capture, never a policy question
	---@return boolean
	MayTransfer = function(unitID, fromTeamID, toTeamID, capture)
		if capture then
			return true
		end
		-- /take moves a whole seat under its own policy; per-unit rules do not
		-- apply to the sweep it performs.
		if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
			return true
		end
		local policyResult = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,

	---Move units with no policy question asked: the giver is the game itself,
	---not a team choosing to share. Scripted handovers use this when the mode
	---is not meant to have a say — and a mode that IS meant to have a say
	---should see a Units call instead.
	---@param unitIDs integer[]
	---@param toTeamID integer
	---@return integer transferred
	Give = function(unitIDs, toTeamID)
		assert(GG ~= nil and GG.TransferUnits ~= nil,
			"Transfer.Give called before the unit transfer controller initialized")
		return GG.TransferUnits(unitIDs, toTeamID, true)
	end,
}
