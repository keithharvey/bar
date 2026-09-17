---@class RegionLayout the layout codec: every type's regions in one table keyed by type, drawn in the startbox 0..200 space, to and from Region records in elmos. Besides its shape an entry carries the fields its type declares, and nothing else
local Layout = {}

Layout.SPACE = 200

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

---@param v number
---@return number to two decimals
local function round(v)
	return math.floor(v * 100 + 0.5) / 100
end

---@param regions Region[] of any types; one the registry does not know is left out
---@param byKey table<string, RegionType> the registry
---@param mapSizeX number
---@param mapSizeZ number
---@return table layout { regions = { [typeKey] = entry[] } }
function Layout.Export(regions, byKey, mapSizeX, mapSizeZ)
	local layout = { regions = {} }
	local sx, sz = Layout.SPACE / mapSizeX, Layout.SPACE / mapSizeZ
	for _, region in ipairs(regions) do
		local kind = byKey[region.type]
		if kind then
			local entry = {} ---@type table<string, any>
			for _, field in ipairs(kind.fields) do
				local value = region[field.key]
				if value ~= nil and value ~= "" then
					entry[field.key] = value
				end
			end
			if region.tags ~= nil and #region.tags > 0 then
				local tags = {}
				for j, tag in ipairs(region.tags) do
					tags[j] = tag
				end
				entry.tags = tags
			end
			if region.vertices then
				local poly = {}
				for j, v in ipairs(region.vertices) do
					poly[j] = { x = round(v.x * sx), y = round(v.z * sz) }
				end
				entry.poly = poly
			elseif region.x and region.z then
				entry.x, entry.y = round(region.x * sx), round(region.z * sz)
			end
			local slot = layout.regions[kind.key] or {}
			layout.regions[kind.key] = slot
			slot[#slot + 1] = entry
		end
	end
	return layout
end

---@param layout table the decoded layout
---@param kind RegionType the type whose regions to read
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions typed and shaped; whether they keep the type's rules is the Check's to say
---@return string|nil reason why not
function Layout.Parse(layout, kind, mapSizeX, mapSizeZ)
	if type(layout) ~= "table" or type(layout.regions) ~= "table" then
		return nil, "a layout is { regions = { <type> = { ... } } }"
	end
	local label = kind.label:lower()
	local entries = layout.regions[kind.key]
	if type(entries) ~= "table" or #entries == 0 then
		return nil, "the layout lists no " .. label
	end
	local scaleX, scaleZ = mapSizeX / Layout.SPACE, mapSizeZ / Layout.SPACE
	local regions = {} ---@type Region[]
	for i, entry in ipairs(entries) do
		if type(entry) ~= "table" then
			return nil, label .. " " .. i .. " is not a table"
		end
		local who = type(entry.name) == "string" and entry.name or (label .. " " .. i)
		---@type Region
		local region = { type = kind.key, tags = type(entry.tags) == "table" and entry.tags or nil }
		for _, field in ipairs(kind.fields) do
			local value = entry[field.key]
			if field.kind == "integer" and type(value) == "string" then
				value = tonumber(value) or value
			elseif field.kind == "string" and value ~= nil and type(value) ~= "string" then
				value = tostring(value)
			end
			region[field.key] = value
		end
		if entry.poly ~= nil then
			local poly = expandPoly(entry.poly)
			if poly == nil then
				return nil, who .. " needs a poly of two {x, y} corners or three or more vertices"
			end
			local vertices = {} ---@type { x: number, z: number }[]
			for j, p in ipairs(poly) do
				vertices[j] = { x = (p[1] or 0) * scaleX, z = (p[2] or 0) * scaleZ }
			end
			region.vertices = vertices
		elseif type(entry.x) == "number" and type(entry.y) == "number" then
			region.x, region.z = entry.x * scaleX, entry.y * scaleZ
		else
			return nil, who .. " has no shape: a poly, or x and y"
		end
		regions[#regions + 1] = region
	end
	return regions, nil
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
