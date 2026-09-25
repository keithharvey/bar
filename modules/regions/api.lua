local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Enums = require("modules/regions/enums")
local Geometry = require("modules/regions/lib/geometry")
local Layout = require("modules/regions/lib/layout")
local Names = require("modules/regions/lib/names")
local Problems = require("modules/regions/lib/problems")
local Store = require("modules/regions/lib/store")
local Types = require("modules/regions/types")

---@class RegionsApi
---@field Overlaps fun(a: { x: number, z: number }[], b: { x: number, z: number }[]): boolean
---@field Contains fun(x: number, z: number, vertices: { x: number, z: number }[]): boolean
---@field ProblemLine fun(problem: RegionProblem): string
---@field ProblemLines fun(typeKey: RegionTypeKey, regions: Region[], map: RegionMap|nil): string[]
---@field ProblemWith fun(ctx: RegionSetContext, index: integer, message: string)
---@field ProblemAt fun(ctx: RegionSetContext, message: string, at: { x: number, z: number }|nil)
---@field Enums RegionEnums
---@field Geometry RegionGeometry
---@field GeometryOf fun(vertices: { x: number, z: number }[]): RegionGeometryKey|nil
---@field EncodeLayout fun(layout: table): string|nil
---@field DecodeLayout fun(raw: string): table|nil
---@field LayoutFromStartboxArrangement fun(arrangement: table|nil): table|nil
local Api = {}

---@param kind RegionType
---@param regions Region[]
---@return { name: string, derived: boolean }[]
local function namesOf(kind, regions)
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	---@type RegionNamesContext
	local ctx = { type = kind, regions = regions, bases = {} }
	ModuleHandler.Evaluate(pipelines.names, ctx)
	return Names.Of(regions, ctx.bases)
end

---@return RegionTypeKey[] order
---@return table<string, RegionType> byKey
function Api.Types()
	return Types.order, Types.byKey
end

---@return string
local function mintId()
	return string.format("%06x%06x", math.random(0, 0xffffff), math.random(0, 0xffffff))
end

---@param typeKey RegionTypeKey
---@param fields table|nil
---@return StoredRegion
function Api.Create(typeKey, fields)
	local region = fields or {} ---@type Region
	region.type = typeKey
	region.id = region.id or mintId()
	region.vertices = region.vertices or {}
	return region --[[@as StoredRegion]]
end

---@param typeKey RegionTypeKey
---@param region Region
---@param siblings Region[]|nil
---@param fieldsOnly boolean|nil
---@return string[]
function Api.Check(typeKey, region, siblings, fieldsOnly)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { "unknown region type " .. tostring(typeKey) }
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	local all = { region }
	for _, other in ipairs(siblings or {}) do
		if other ~= region then
			all[#all + 1] = other
		end
	end
	local names = {} ---@type table<Region, string>
	for i, named in ipairs(namesOf(kind, all)) do
		names[all[i]] = named.name
	end
	---@type RegionCheckContext
	local ctx = {
		type = kind,
		region = region,
		siblings = siblings or {},
		names = names,
		fieldsOnly = fieldsOnly,
		problems = {},
	}
	ModuleHandler.Evaluate(pipelines.check, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[]
---@param map RegionMap|nil
---@return RegionProblem[]
function Api.CheckSet(typeKey, regions, map)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { { message = "unknown region type " .. tostring(typeKey) } }
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	local names = {} ---@type string[]
	for i, named in ipairs(namesOf(kind, regions)) do
		names[i] = named.name
	end
	---@type RegionSetContext
	local ctx = { type = kind, regions = regions, names = names, map = map or {}, problems = {} }
	ModuleHandler.Evaluate(pipelines.check_set, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[]
---@return { name: string, derived: boolean }[]
function Api.Names(typeKey, regions)
	local kind = Types.byKey[typeKey]
	if not kind then
		return {}
	end
	return namesOf(kind, regions)
end

---@param regions Region[]
---@param mapSizeX number
---@param mapSizeZ number
---@return table
function Api.ExportLayout(regions, mapSizeX, mapSizeZ)
	return Layout.Export(regions, Types.byKey, mapSizeX, mapSizeZ)
end

---@param layout table
---@param typeKey RegionTypeKey
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string|nil reason
function Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ)
	local kind = Types.byKey[typeKey]
	if not kind then
		return nil, "unknown region type " .. tostring(typeKey)
	end
	local regions, reason = Layout.Parse(layout, kind, mapSizeX, mapSizeZ)
	for _, region in ipairs(regions or {}) do
		Api.Create(typeKey, region) -- every region the api hands out has an id; a layout without them (the startbox shim's) gets them here
	end
	return regions, reason
end

-- The store: the regions of this Lua state, in one insertion-ordered list keyed by id.
-- The editor puts, edits and removes; the game loads a layout into it and reads.

---@return RegionStore
local function store()
	local state = ModuleHandler.State(Modules.Regions)
	state.store = state.store or Store.New()
	return state.store
end

---@param region Region
---@param beforeId string|nil
---@return StoredRegion
function Api.Put(region, beforeId)
	return Store.Put(store(), Api.Create(region.type, region), beforeId)
end

---@param id string
---@return StoredRegion|nil
function Api.Remove(id)
	return Store.Remove(store(), id)
end

---@param id string
---@return StoredRegion|nil
function Api.Get(id)
	return store().byId[id]
end

---@param typeKey RegionTypeKey|nil
---@return StoredRegion[]
function Api.All(typeKey)
	return Store.All(store(), typeKey)
end

---@param typeKey RegionTypeKey|nil
---@return StoredRegion[]
function Api.Clear(typeKey)
	return Store.Clear(store(), typeKey)
end

---@return integer
function Api.Revision()
	return store().revision
end

---@param id string
---@param key string
---@param value any
---@return boolean ok
---@return string|nil reason
function Api.Set(id, key, value)
	local region = store().byId[id]
	local kind = region and Types.byKey[region.type]
	if not region or not kind then
		return false, "no such region"
	end
	local declared = nil
	for _, field in ipairs(kind.fields) do
		if field.key == key then
			declared = field
		end
	end
	if not declared then
		return false, "a " .. kind.label:lower() .. " has no " .. tostring(key)
	end
	if value == "" then
		value = nil
	end
	if value ~= nil and declared.kind == "integer" then
		value = tonumber(value)
		if value == nil then
			return false, declared.label .. " must be a number"
		end
	end
	region[key] = value
	store().revision = store().revision + 1
	return true, nil
end

---@param typeKey RegionTypeKey
---@param map RegionMap|nil
---@return RegionProblem[]
function Api.Problems(typeKey, map)
	return Api.CheckSet(typeKey, Api.All(typeKey), map)
end

---@param typeKey RegionTypeKey
---@return table<string, string>
function Api.NamesById(typeKey)
	local regions = Api.All(typeKey)
	local out = {}
	for i, named in ipairs(Api.Names(typeKey, regions)) do
		local region = regions[i]
		if region and region.id then
			out[region.id] = named.name
		end
	end
	return out
end

---@param typeKey RegionTypeKey
---@return table<string, any[]>
function Api.Suggestions(typeKey)
	local kind = Types.byKey[typeKey]
	local out = {}
	for _, field in ipairs(kind and kind.fields or {}) do
		if field.suggest then
			local seen, values = {}, {}
			for _, region in ipairs(Api.All(typeKey)) do
				local value = region[field.key]
				if value ~= nil and not seen[value] then
					seen[value] = true
					values[#values + 1] = value
				end
			end
			table.sort(values)
			out[field.key] = values
		end
	end
	return out
end

-- The layout is the one serialized form; a file holding one is `return <layout>` as Lua.

---@param layout table
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]
function Api.ParseAllLayout(layout, mapSizeX, mapSizeZ)
	local out = {}
	for _, typeKey in ipairs(Types.order) do
		if type(layout) == "table" and type(layout.regions) == "table" and layout.regions[typeKey] then
			for _, region in ipairs(Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ) or {}) do
				out[#out + 1] = region
			end
		end
	end
	return out
end

---@param regions Region[]
---@param mapSizeX number
---@param mapSizeZ number
---@param header string|nil
---@return string
function Api.SerializeLayout(regions, mapSizeX, mapSizeZ, header)
	return Layout.Serialize(Api.ExportLayout(regions, mapSizeX, mapSizeZ), Types.order, Types.byKey, header)
end

---@param path string
---@param mapSizeX number
---@param mapSizeZ number
---@param header string|nil
---@return boolean ok
---@return string|nil reason
function Api.SaveLayoutFile(path, mapSizeX, mapSizeZ, header)
	local file = io.open(path, "w")
	if not file then
		return false, "could not write " .. path
	end
	file:write(Api.SerializeLayout(Api.All(), mapSizeX, mapSizeZ, header))
	file:close()
	return true, nil
end

---@param path string
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string|nil reason
function Api.LoadLayoutFile(path, mapSizeX, mapSizeZ)
	if not VFS.FileExists(path, VFS.RAW_FIRST) then
		return nil, "no file at " .. path
	end
	local ok, layout = pcall(VFS.Include, path, nil, VFS.RAW_FIRST)
	if not ok then
		return nil, tostring(layout)
	end
	if type(layout) ~= "table" or type(layout.regions) ~= "table" then
		return nil, path .. " does not return a layout: { regions = { <type> = { ... } } }"
	end
	local regions = Api.ParseAllLayout(layout, mapSizeX, mapSizeZ)
	Api.Clear()
	for _, region in ipairs(regions) do
		Api.Put(region)
	end
	return regions, nil
end

Api.Tessellate = Layout.Tessellate

---@param region Region
---@param map RegionMap|nil
---@return RegionDescription
function Api.Describe(region, map)
	local vertices = region.vertices or {}
	local x, z = Geometry.Centroid(vertices)
	---@type RegionDescription
	local shape = { area = Geometry.Area(vertices), centre = { x = x, z = z } }
	local kind = Types.byKey[region.type]
	if not kind then
		return shape
	end
	---@type RegionsPipelines
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions)
	---@type RegionDescribeContext
	local ctx = { type = kind, region = region, shape = shape, map = map or {} }
	return ModuleHandler.Evaluate(pipelines.describe, ctx) or shape
end

Api.Enums = Enums
Api.Geometry = Geometry
Api.Overlaps = Geometry.Overlaps
Api.Contains = Geometry.Contains
Api.GeometryOf = Geometry.Of
Api.ProblemLine = Problems.Line

---@param typeKey RegionTypeKey
---@param regions Region[]
---@param map RegionMap|nil
---@return string[]
function Api.ProblemLines(typeKey, regions, map)
	local lines = {} ---@type string[]
	for i, problem in ipairs(Api.CheckSet(typeKey, regions, map)) do
		lines[i] = Problems.Line(problem)
	end
	return lines
end
Api.ProblemWith = Problems.OfRegion
Api.ProblemAt = Problems.OfSet

Api.EncodeLayout = Layout.Encode
Api.DecodeLayout = Layout.Decode
Api.LayoutFromStartboxArrangement = Layout.FromStartboxArrangement -- SHIM, see lib/layout.lua

return Api
