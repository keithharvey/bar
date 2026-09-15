local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local UnitCategories = VFS.Include("modules/construction/lib/unit_categories.lua")

local extractorKind ---@type table<integer, "mex"|"geo">|nil built on first use: api.lua is included where UnitDefs is not

---@return table<integer, "mex"|"geo">
local function extractorKinds()
	if extractorKind == nil then
		extractorKind = {}
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.extractsMetal > 0 then
				extractorKind[unitDefID] = "mex"
			elseif unitDef.customParams.geothermal then
				extractorKind[unitDefID] = "geo"
			end
		end
	end
	return extractorKind
end

---@param kind "mex"|"geo"
---@param myTeam integer
---@param springRepo Spring
---@return boolean
local function otherTeamsExtractorNearby(kind, myTeam, x, z, springRepo)
	local kinds = extractorKinds()
	local units = springRepo.GetUnitsInCylinder(x, z, Game.extractorRadius)
	for _, unitID in ipairs(units) do
		if kinds[springRepo.GetUnitDefID(unitID)] == kind and springRepo.GetUnitTeam(unitID) ~= myTeam then
			return true
		end
	end
	return false
end

local utilitySharing ---@type boolean|nil the sharing mode lets utility buildings change hands; read once, modoptions are constant

local Placement = {}

---The one placement ask: the gadget's AllowUnitCreation and any command-time check share it.
---@param unitDefID integer
---@param builderTeam integer
---@param x number
---@param y number
---@param z number
---@param springRepo Spring
---@return boolean
function Placement.Decide(unitDefID, builderTeam, x, y, z, springRepo)
	local opts = springRepo.GetModOptions()
	if utilitySharing == nil then
		utilitySharing =
			table.contains(UnitCategories.TypesFor(opts.unit_sharing_mode), ConstructionEnums.UnitType.Utility)
	end
	local kind = extractorKinds()[unitDefID]
	-- A mex is judged by the spot it mines, not by where its footprint centre lands: the same
	-- placement is valid over a range of positions around the spot, and a region holds spots.
	local spotX, spotZ
	if kind == "mex" then
		local finder = GG and GG.resource_spot_finder
		local spot = finder and finder.GetClosestMexSpot and finder.GetClosestMexSpot(x, z)
		if spot then
			spotX, spotZ = spot.x, spot.z
		end
	end
	---@type ConstructionPlacementContext
	local ctx = {
		unitDefID = unitDefID,
		builderTeam = builderTeam,
		x = x,
		y = y,
		z = z,
		extractor = kind,
		alliedExtractorNearby = kind ~= nil and otherTeamsExtractorNearby(kind, builderTeam, x, z, springRepo),
		utilitySharing = utilitySharing,
		spotX = spotX,
		spotZ = spotZ,
		spotHolder = builderTeam, -- the identity until the facts answer
	}
	local facts = ModuleHandler.Enrich(Contract.PlacementFacts, opts, ctx, springRepo)
	ctx.spotHolder = facts[Contract.PlacementFacts.SpotHolder]
	local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines
	return ModuleHandler.Evaluate(pipelines.placement, ctx) == true
end

---@param unitDefID integer
---@return boolean
function Placement.IsExtractor(unitDefID)
	return extractorKinds()[unitDefID] ~= nil
end

return Placement
