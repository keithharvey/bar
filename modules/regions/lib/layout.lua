local Enums = require("modules/regions/enums")
local SplineLib = require("common/lib_spline")

---@class RegionLayout the one serialized form of regions: every type's regions in one table keyed by type, in the
---startbox 0..200 space, to and from Region records in elmos. It is what the map ships, what the modoption carries,
---what the editor saves, and what a gadget publishes for its widgets. An entry is the region's id, the fields its
---type declares, tags, and its shape: a point's x and y, or a poly of anchors { x, y, strength? }. Two anchors are
---an axis-aligned rect's corners; an anchor with strength bends the ring, and the outline is derived from the
---anchors on the way in, never stored
local Layout = {}

Layout.SPACE = 200

---@class RegionLayoutAnchor
---@field x number 0..200
---@field y number 0..200
---@field strength number|nil 0..1; absent or 0 is a sharp corner

---@param poly table
---@return RegionLayoutAnchor[]|nil anchors a rect expanded to its four corners; nil when malformed
---@return boolean curved any anchor carries strength
local function readPoly(poly)
	if type(poly) ~= "table" then
		return nil, false
	end
	local anchors = {} ---@type RegionLayoutAnchor[]
	local curved = false
	for i, p in ipairs(poly) do
		if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then
			return nil, false
		end
		local strength = type(p.strength) == "number" and p.strength > 0 and p.strength or nil
		curved = curved or strength ~= nil
		anchors[i] = { x = p.x, y = p.y, strength = strength }
	end
	if #anchors == 2 then
		local a, b = anchors[1], anchors[2]
		return { { x = a.x, y = a.y }, { x = b.x, y = a.y }, { x = b.x, y = b.y }, { x = a.x, y = b.y } }, false
	end
	if #anchors < 3 then
		return nil, false
	end
	return anchors, curved
end

---@param controls { x: number, z: number, strength: number|nil }[] elmos
---@return { x: number, z: number }[] outline
function Layout.Tessellate(controls)
	local ring = {}
	for i, a in ipairs(controls) do
		ring[i] = { a.x, a.z, a.strength or 0 }
	end
	local out = {}
	for i, p in ipairs(SplineLib.TessellateRing(ring)) do
		out[i] = { x = p[1], z = p[2] }
	end
	return out
end

---@param v number
---@return number to two decimals
local function round(v)
	return math.floor(v * 100 + 0.5) / 100
end

---@param regions Region[] of any types; one the registry does not know is left out
---@param byKey table<string, RegionType|nil> the registry
---@param mapSizeX number
---@param mapSizeZ number
---@return table layout { regions = { [typeKey] = entry[] } }
function Layout.Export(regions, byKey, mapSizeX, mapSizeZ)
	local layout = { regions = {} }
	local sx, sz = Layout.SPACE / mapSizeX, Layout.SPACE / mapSizeZ
	for _, region in ipairs(regions) do
		local kind = byKey[region.type]
		if kind then
			local entry = { id = region.id } ---@type table<string, any>
			for _, field in ipairs(kind.fields) do
				local value = region[field.key]
				if field.kind == "points" then
					if type(value) == "table" and #value > 0 then
						local points = {}
						for j, p in ipairs(value) do
							points[j] = { x = round(p.x * sx), y = round(p.z * sz) }
						end
						entry[field.key] = points
					end
				elseif value ~= nil and value ~= "" then
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
			-- the anchors, never the outline: a curve cannot be recovered from its outline
			local anchors = region.kind == "spline" and region.controls or region.vertices or {}
			local only = anchors[1]
			if #anchors == 1 and only then
				entry.x, entry.y = round(only.x * sx), round(only.z * sz)
			elseif region.kind == "box" and #anchors >= 3 then
				local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
				for _, a in ipairs(anchors) do
					minX, maxX = math.min(minX, a.x), math.max(maxX, a.x)
					minZ, maxZ = math.min(minZ, a.z), math.max(maxZ, a.z)
				end
				entry.poly = {
					{ x = round(minX * sx), y = round(minZ * sz) },
					{ x = round(maxX * sx), y = round(maxZ * sz) },
				}
			elseif #anchors > 0 then
				local poly = {}
				for j, a in ipairs(anchors) do
					local anchor = { x = round(a.x * sx), y = round(a.z * sz) }
					-- snapped to 0.025 as maps-metadata does; a strength that rounds to nothing is a sharp corner
					local strength = a.strength and (math.floor(a.strength * 40 + 0.5) / 40)
					if strength and strength > 0 then
						anchor.strength = strength
					end
					poly[j] = anchor
				end
				entry.poly = poly
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
---@return Region[]|nil regions typed and shaped, with kind ("point", "box", "polygon", "spline") and, for a spline, its controls in elmos; whether they keep the type's rules is the Check's to say
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
		local region = {
			type = kind.key,
			id = type(entry.id) == "string" and entry.id or nil,
			tags = type(entry.tags) == "table" and entry.tags or nil,
			vertices = {},
		}
		for _, field in ipairs(kind.fields) do
			local value = entry[field.key]
			if field.kind == "integer" and type(value) == "string" then
				value = tonumber(value) or value
			elseif field.kind == "string" and value ~= nil and type(value) ~= "string" then
				value = tostring(value)
			elseif field.kind == "points" then
				local points = nil
				if type(value) == "table" then
					points = {}
					for j, p in ipairs(value) do
						if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then
							return nil, who .. " has a " .. field.key .. " entry that is not an {x, y}"
						end
						points[j] = { x = p.x * scaleX, z = p.y * scaleZ }
					end
				end
				value = points
			end
			region[field.key] = value
		end
		if entry.poly ~= nil then
			local anchors, curved = readPoly(entry.poly)
			if anchors == nil then
				return nil, who .. " needs a poly of two {x, y} corners or three or more anchors"
			end
			local scaled = {} ---@type { x: number, z: number, strength: number|nil }[]
			for j, a in ipairs(anchors) do
				scaled[j] = { x = a.x * scaleX, z = a.y * scaleZ, strength = a.strength }
			end
			if curved then
				region.kind = "spline"
				region.controls = scaled
				region.vertices = Layout.Tessellate(scaled)
			else
				region.kind = #entry.poly == 2 and "box" or "polygon"
				for _, a in ipairs(scaled) do
					a.strength = nil
				end
				region.vertices = scaled
			end
		elseif type(entry.x) == "number" and type(entry.y) == "number" then
			region.kind = "point"
			region.vertices = { { x = entry.x * scaleX, z = entry.y * scaleZ } }
		else
			return nil, who .. " has no shape: a poly, or x and y"
		end
		regions[#regions + 1] = region
	end
	return regions, nil
end

---@param value any
---@return string
local function literal(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

---@param layout table
---@param order RegionTypeKey[] the types, in the order to write them
---@param byKey table<string, RegionType|nil>
---@param header string|nil a first comment line
---@return string lua source that returns the layout: one entry per line block, fields in declared order, for readable diffs
function Layout.Serialize(layout, order, byKey, header)
	local lines = { header and ("-- " .. header) or "-- Regions layout", "return {", "  regions = {" }
	for _, typeKey in ipairs(order) do
		local entries = layout.regions[typeKey]
		if entries and #entries > 0 then
			lines[#lines + 1] = "    " .. typeKey .. " = {"
			for _, entry in ipairs(entries) do
				lines[#lines + 1] = "      {"
				lines[#lines + 1] = "        id = " .. literal(entry.id) .. ","
				for _, field in ipairs((byKey[typeKey] or {}).fields or {}) do
					local value = entry[field.key]
					if field.kind == "points" and type(value) == "table" then
						local points = {}
						for j, p in ipairs(value) do
							points[j] = string.format("{ x = %s, y = %s }", p.x, p.y)
						end
						lines[#lines + 1] = "        " .. field.key .. " = { " .. table.concat(points, ", ") .. " },"
					elseif value ~= nil then
						lines[#lines + 1] = "        " .. field.key .. " = " .. literal(value) .. ","
					end
				end
				if entry.tags then
					local quoted = {}
					for i, tag in ipairs(entry.tags) do
						quoted[i] = literal(tag)
					end
					lines[#lines + 1] = "        tags = { " .. table.concat(quoted, ", ") .. " },"
				end
				if entry.poly then
					lines[#lines + 1] = "        poly = {"
					for _, a in ipairs(entry.poly) do
						lines[#lines + 1] = a.strength
								and string.format("          { x = %s, y = %s, strength = %s },", a.x, a.y, a.strength)
							or string.format("          { x = %s, y = %s },", a.x, a.y)
					end
					lines[#lines + 1] = "        },"
				else
					lines[#lines + 1] = string.format("        x = %s,", entry.x)
					lines[#lines + 1] = string.format("        y = %s,", entry.y)
				end
				lines[#lines + 1] = "      },"
			end
			lines[#lines + 1] = "    },"
		end
	end
	lines[#lines + 1] = "  },"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

---@param layout table
---@return string|nil
function Layout.Encode(layout)
	local base64 = require("common/luaUtilities/base64")
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
	local ModoptionPayload = require("common/luaUtilities/modoption_payload")
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

-- =====================================================================================================================
-- SHIM: the old startbox mod option format, translated into a region layout.
--
-- The lobby and SPADS already carry start boxes in `mapmetadata_startbox_override` (one arrangement) and
-- `mapmetadata_startboxes_set` (one arrangement per team count), decoded by the same ModoptionPayload as our layouts.
-- An arrangement is maps-metadata's `startboxesInfo`: { startboxes = { { poly = { { x, y, strength? }, ... } }, ... } },
-- in the same 0..200 space, box i belonging to start i. This turns ONE arrangement into
-- { regions = { start = { { team = i, poly = ... } } } }, so Layout.Parse reads it like any other layout and regions
-- does not wait on a new mod option key being accepted anywhere.
--
-- It translates the format and nothing else. Which arrangement applies to a match (the override, else the set's entry
-- for the team count, else the nearest) is luarules/gadgets/include/startbox_utilities.lua's to decide; hand this the
-- one it picked. Anchor strength comes through: a curved box parses as a spline, like any other.
--
-- Delete this once start boxes are published as a region layout in their own right.
-- =====================================================================================================================
---@param arrangement table|nil one decoded startbox arrangement
---@return table|nil layout nil when it is not an arrangement
function Layout.FromStartboxArrangement(arrangement)
	if type(arrangement) ~= "table" or type(arrangement.startboxes) ~= "table" then
		return nil
	end
	local starts = {}
	for i, box in ipairs(arrangement.startboxes) do
		local poly = {}
		for j, p in ipairs(type(box) == "table" and type(box.poly) == "table" and box.poly or {}) do
			poly[j] = { x = p.x, y = p.y, strength = p.strength }
		end
		starts[i] = { team = i, poly = poly }
	end
	return { regions = { [Enums.Types.Start] = starts } }
end

return Layout
