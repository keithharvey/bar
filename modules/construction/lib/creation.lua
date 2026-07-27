local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Contract = require("modules/construction/contract")
local state = require("modules/construction/state")

local REASON = "construction_creation"

local Creation = {}

---@param teamID integer
---@param springRepo Spring
function Creation.Refresh(teamID, springRepo)
	local blocking = GG and GG.BuildBlocking
	if not blocking then
		return
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines
	local facts =
		ModuleHandler.Enrich(Contract.CreationFacts, springRepo.GetModOptions(), { teamID = teamID }, springRepo)
	local blocked = state.creationBlocked[teamID] or {}
	state.creationBlocked[teamID] = blocked
	for unitDefID, unitDef in pairs(UnitDefs) do
		---@type ConstructionCreationContext
		local ctx =
			{ unitDefID = unitDefID, unitDef = unitDef, teamID = teamID, tier = facts[Contract.CreationFacts.Tier] }
		local allowed = ModuleHandler.Evaluate(pipelines.creation, ctx) == true
		if not allowed and not blocked[unitDefID] then
			blocking.AddBlockedUnit(unitDefID, teamID, REASON)
			blocked[unitDefID] = true
		elseif allowed and blocked[unitDefID] then
			blocking.RemoveBlockedUnit(unitDefID, teamID, REASON)
			blocked[unitDefID] = nil
		end
	end
end

return Creation
