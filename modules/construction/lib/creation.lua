local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
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
	local modOptions = springRepo.GetModOptions()
	local facts = ModuleHandler.Enrich(
		ModuleHandler.Contract(Modules.Construction).CreationFacts,
		{ teamID = teamID, modOptions = modOptions },
		springRepo
	)
	local blocked = state.creationBlocked[teamID] or {}
	state.creationBlocked[teamID] = blocked
	for unitDefID, unitDef in pairs(UnitDefs) do
		---@type ConstructionCreationContext
		local ctx = {
			modOptions = modOptions,
			unitDefID = unitDefID,
			unitDef = unitDef,
			teamID = teamID,
			tier = facts[ModuleHandler.Contract(Modules.Construction).CreationFacts.Tier],
		}
		local allowed = ModuleHandler.Evaluate(ModuleHandler.Contract(Modules.Construction).Creation, ctx) == true
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
