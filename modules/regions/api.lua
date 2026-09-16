local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Types = VFS.Include("modules/regions/types.lua")
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

---@class RegionsApi
---@field Overlaps fun(a: { x: number, z: number }[], b: { x: number, z: number }[]): boolean
---@field Contains fun(x: number, z: number, vertices: { x: number, z: number }[]): boolean
---@field ParseLayout fun(layout: table, mapSizeX: number, mapSizeZ: number): LayoutRegion[]|nil, string|nil
---@field ExportLayout fun(regions: { name: string, group: string|nil, vertices: { x: number, z: number }[] }[], mapSizeX: number, mapSizeZ: number): table
---@field EncodeLayout fun(layout: table): string|nil
---@field DecodeLayout fun(raw: string): table|nil
return {
	---@return RegionTypeKey[] order
	---@return table<string, RegionType> byKey
	Types = function()
		return Types.order, Types.byKey
	end,

	---@param typeKey RegionTypeKey
	---@param region Region
	---@param siblings Region[]|nil the other regions of the type
	---@param fieldsOnly boolean|nil
	---@return string[] problems
	Check = function(typeKey, region, siblings, fieldsOnly)
		local kind = Types.byKey[typeKey]
		if not kind then
			return { "unknown region type " .. tostring(typeKey) }
		end
		local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
		---@type RegionCheckContext
		local ctx = { type = kind, region = region, siblings = siblings or {}, fieldsOnly = fieldsOnly, problems = {} }
		ModuleHandler.Evaluate(pipelines.check, ctx)
		return ctx.problems
	end,

	---@param region Region
	---@param env { spots: table[]|nil, starts: table[]|nil, modOptions: table|nil }
	---@return table<string, any> facts by the contract's keys
	Facts = function(region, env)
		env = env or {}
		---@type RegionFactsContext
		local ctx = { region = region, spots = env.spots, starts = env.starts }
		return ModuleHandler.Enrich(Contract.Facts, env.modOptions or {}, ctx)
	end,

	---@param facts table<string, any>
	---@return { [1]: string, [2]: string }[]
	FactLines = function(facts)
		local lines = {}
		local area = facts[Contract.Facts.Area]
		if area and area > 0 then
			lines[#lines + 1] =
				{ "Area", string.format("%.0f x %.0f elmos equivalent", math.sqrt(area), math.sqrt(area)) }
		end
		local centre = facts[Contract.Facts.Centre]
		if centre then
			lines[#lines + 1] = { "Centre", string.format("%d, %d", centre.x, centre.z) }
		end
		local spots = facts[Contract.Facts.MetalSpots]
		if spots then
			lines[#lines + 1] = {
				"Metal spots",
				spots.count .. (spots.count > 0 and string.format(" (%.1f worth)", spots.worth) or ""),
			}
		end
		local nearest = facts[Contract.Facts.NearestStart]
		if nearest then
			lines[#lines + 1] =
				{ "Nearest start", string.format("ally team %d, %.0f elmos", nearest.allyTeam, nearest.distance) }
		end
		return lines
	end,

	Overlaps = Geometry.Overlaps,
	Contains = Geometry.Contains,

	ParseLayout = Layout.Parse,
	ExportLayout = Layout.Export,
	EncodeLayout = Layout.Encode,
	DecodeLayout = Layout.Decode,
}
