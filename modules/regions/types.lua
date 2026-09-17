local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class RegionField
---@field key string
---@field label string
---@field kind "string"|"integer"
---@field required boolean|nil
---@field unique boolean|string|nil true: unique among regions of this type; a field key: unique among those sharing that field's value
---@field picks "start"|nil what an editor offers as the values: the map's starts, by ordinal
---@field suggest boolean|nil an editor offers the values its siblings already carry

---@class RegionType
---@field key RegionTypeKey
---@field label string
---@field geometries RegionGeometryKey[] the shapes a region of this type may be drawn as
---@field fields RegionField[]
---@field disjoint boolean|nil regions of this type never share ground; the Check refuses an overlap, and an editor may resolve one before it happens
---@field nameFrom string|nil the field a region's derived name is taken from when it carries none; the type's label otherwise
---@field order integer|nil where the type sits in a list of types; lower first
---@field module string|nil the module that contributed it, filled in here

local FRAGMENT = "region_types.lua"

local byKey = {} ---@type table<string, RegionType>
local claimedBy = {} ---@type table<string, string>
local manifests = ModuleHandler.Discover()
local names = {}
for name in pairs(manifests) do
	names[#names + 1] = name
end
table.sort(names)
for _, name in ipairs(names) do
	local path = manifests[name].dir .. FRAGMENT
	if VFS.FileExists(path) then
		local fragment = VFS.Include(path)
		if type(fragment) ~= "table" then
			error(path .. ": region_types.lua must return { <key> = RegionType, ... }")
		end
		for key, kind in pairs(fragment) do
			if claimedBy[key] then
				error(path .. ": region type " .. key .. " is already contributed by " .. claimedBy[key])
			end
			if
				type(kind) ~= "table"
				or kind.key ~= key
				or type(kind.label) ~= "string"
				or type(kind.geometries) ~= "table"
			then
				error(path .. ": region type " .. tostring(key) .. " needs key, label and geometries")
			end
			kind.fields = kind.fields or {}
			if kind.nameFrom ~= nil then
				local declared = false
				for _, field in ipairs(kind.fields) do
					declared = declared or field.key == kind.nameFrom
				end
				if not declared then
					error(
						path
							.. ": region type "
							.. key
							.. " derives names from "
							.. kind.nameFrom
							.. ", a field it does not declare"
					)
				end
			end
			kind.module = name
			claimedBy[key] = name
			byKey[key] = kind
		end
	end
end

local order = {} ---@type string[]
for key in pairs(byKey) do
	order[#order + 1] = key
end
table.sort(order, function(a, b)
	local oa, ob = byKey[a].order or 100, byKey[b].order or 100
	if oa ~= ob then
		return oa < ob
	end
	return a < b
end)

return {
	order = order,
	byKey = byKey,
}
