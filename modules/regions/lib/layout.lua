
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

---@class RegionLayout
local Layout = {}

Layout.SPACE = 200

---@class LayoutRegion a region as the layout lists it, in elmos once parsed
---@field name string unique among its type
---@field group string|nil
---@field polygon number[][] {x, z} vertices
---@field centerX number the polygon's vertex centroid
---@field centerZ number

---@param poly table
---@return number[][]|nil vertices {x, y} in layout space
local function expandPoly(poly)
	if type(poly) ~= "table" then
		return nil
	end
	local out = {} ---@type number[][]
	for i, p in ipairs(poly) do
		if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then
			return nil
		end
		out[i] = { p.x, p.y }
	end
	if #out == 2 then
		local a, b = poly[1], poly[2]
		return { { a.x, a.y }, { b.x, a.y }, { b.x, b.y }, { a.x, b.y } }
	end
	if #out < 3 then
		return nil
	end
	return out
end

---@param layout table the decoded layout
---@param mapSizeX number
---@param mapSizeZ number
---@return LayoutRegion[]|nil regions
---@return string|nil reason why not
function Layout.Parse(layout, mapSizeX, mapSizeZ)
	if type(layout) ~= "table" or type(layout.regions) ~= "table" then
		return nil, "a layout is { regions = { ... } }"
	end
	local scaleX, scaleZ = mapSizeX / Layout.SPACE, mapSizeZ / Layout.SPACE
	local regions = {} ---@type LayoutRegion[]
	local seen = {} ---@type table<string, boolean>
	for i, entry in ipairs(layout.regions) do
		if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" then
			return nil, "region " .. i .. " has no name"
		end
		if seen[entry.name] then
			return nil, "two regions are named " .. entry.name
		end
		seen[entry.name] = true
		local poly = expandPoly(entry.poly)
		if poly == nil then
			return nil, "region " .. entry.name .. " needs a poly of two {x, y} corners or three or more vertices"
		end
		local polygon = {} ---@type number[][]
		local verts = {}
		for j, p in ipairs(poly) do
			local x, z = (p[1] or 0) * scaleX, (p[2] or 0) * scaleZ
			polygon[j] = { x, z }
			verts[j] = { x = x, z = z }
		end
		local cx, cz = Geometry.Centroid(verts)
		regions[#regions + 1] = {
			name = entry.name,
			group = type(entry.group) == "string" and entry.group or nil,
			polygon = polygon,
			centerX = cx,
			centerZ = cz,
		}
	end
	if #regions == 0 then
		return nil, "the layout has no regions"
	end
	return regions, nil
end

---@param regions { name: string, group: string|nil, vertices: { x: number, z: number }[] }[]
---@param mapSizeX number
---@param mapSizeZ number
---@return table layout
function Layout.Export(regions, mapSizeX, mapSizeZ)
	local layout = { regions = {} }
	local sx, sz = Layout.SPACE / mapSizeX, Layout.SPACE / mapSizeZ
	for i, region in ipairs(regions) do
		local poly = {}
		for j, v in ipairs(region.vertices) do
			poly[j] = { x = math.floor(v.x * sx * 100 + 0.5) / 100, y = math.floor(v.z * sz * 100 + 0.5) / 100 }
		end
		local name = region.name
		if name == nil or name == "" then
			name = "region " .. i
		end
		layout.regions[#layout.regions + 1] = { name = name, group = region.group, poly = poly }
	end
	return layout
end

---@param layout table
---@return string|nil
function Layout.Encode(layout)
	local base64 = VFS.Include("common/luaUtilities/base64.lua")
	local ok, json = pcall(Json.encode, layout)
	if not ok or not json then
		return nil
	end
	local compressed = VFS.ZlibCompress(json)
	if not compressed then
		return nil
	end
	return (base64.Encode(compressed):gsub("=+$", ""))
end

---@param raw string
---@return table|nil
function Layout.Decode(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ModoptionPayload = VFS.Include("common/luaUtilities/modoption_payload.lua")
	local decoded = ModoptionPayload.Decode(raw)
	if decoded ~= nil then
		return decoded
	end
	local ok, parsed = pcall(Json.decode, raw)
	if ok and type(parsed) == "table" then
		return parsed
	end
	return nil
end

return Layout
