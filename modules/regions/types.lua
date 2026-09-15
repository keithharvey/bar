-- The types a map's regions come in, contributed by the modules that own their meaning: any
-- module may ship a region_types.lua returning { <key> = RegionType, ... }. A type says what
-- shapes it may be drawn as, which fields a region of it carries, and which are required or
-- unique among its siblings. The Check pipeline enforces this table; the terraformer renders
-- its form from it. Two modules claiming one key is a load error naming both.
local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class RegionField
---@field key string
---@field label string
---@field kind "string"|"integer"
---@field required boolean|nil
---@field unique boolean|nil unique among regions of this type

---@class RegionType
---@field key RegionTypeKey
---@field label string
---@field geometries RegionGeometryKey[] the shapes a region of this type may be drawn as
---@field fields RegionField[]
---@field layoutKey string|nil where the game's layout lists regions of this type
---@field disjoint boolean|nil regions of this type never share ground; the Check refuses an overlap, and an editor may resolve one before it happens
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
