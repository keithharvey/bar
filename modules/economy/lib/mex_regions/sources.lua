-- Where a map's layout comes from, first found wins:
--   1. the mex_regions_layout modoption: json, plain or as the startbox payload base64url(zlib(json)),
--      the way the lobby carries startboxes from maps-metadata
--   2. a file the map ships, luarules/configs/mex_regions.lua
--   3. the terraformer's own save for this map in the write directory, so a local game plays
--      what was just drawn without a lobby round trip; anchors in elmos, converted here

local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local EconomyEnums = VFS.Include("modules/economy/enums.lua")

---@class MexRegionSources
local Sources = {}

local MAP_FILE = "luarules/configs/mex_regions.lua"
local EDITOR_DIR = "Terraform Brush/Regions/"

---The editor's file holds regions as anchors in elmos, curved or not; the layout wants rings
---in the 0..200 space, so it is tessellated and exported the way the editor's COPY does.
---@param entries table
---@param mapSizeX number
---@param mapSizeZ number
---@return table layout
local function layoutFromEditor(entries, mapSizeX, mapSizeZ)
	local SplineLib = VFS.Include("common/lib_spline.lua")
	local regions = {}
	for _, entry in ipairs(entries) do
		local anchors = entry.anchors or entry.vertices
		if type(entry) == "table" and type(anchors) == "table" and #anchors >= 3 then
			local vertices
			if entry.kind == "box" then
				vertices = {}
				for i, a in ipairs(anchors) do
					vertices[i] = { x = a.x, z = a.z }
				end
			else
				local ring = {}
				for i, a in ipairs(anchors) do
					ring[i] = { a.x, a.z, a.strength }
				end
				vertices = {}
				for i, p in ipairs(SplineLib.TessellateRing(ring)) do
					vertices[i] = { x = p[1], z = p[2] }
				end
			end
			regions[#regions + 1] = { name = entry.name, group = entry.group, vertices = vertices }
		end
	end
	return Regions.ExportLayout(regions, mapSizeX, mapSizeZ)
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return table|nil layout
---@return string source where it came from, or what was looked for
local function find(modOptions, mapName, mapSizeX, mapSizeZ)
	local raw = modOptions[EconomyEnums.ModOptions.MexRegionsLayout]
	if type(raw) == "string" and raw ~= "" then
		return Regions.DecodeLayout(raw), "modoption " .. EconomyEnums.ModOptions.MexRegionsLayout
	end
	if VFS.FileExists(MAP_FILE) then
		return VFS.Include(MAP_FILE), MAP_FILE .. " (from the map)"
	end
	local editorFile = EDITOR_DIR .. mapName .. ".lua"
	if VFS.FileExists(editorFile, VFS.RAW) then
		local ok, entries = pcall(VFS.Include, editorFile, nil, VFS.RAW)
		if ok and type(entries) == "table" then
			return layoutFromEditor(entries, mapSizeX, mapSizeZ), editorFile .. " (the terraformer's save)"
		end
	end
	return nil, "no layout: not the modoption, the map's " .. MAP_FILE .. ", nor " .. editorFile
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string source
---@return string|nil reason why there are none
function Sources.Load(modOptions, mapName, mapSizeX, mapSizeZ)
	local layout, source = find(modOptions, mapName, mapSizeX, mapSizeZ)
	if layout == nil then
		return nil, source, nil
	end
	local regions, reason = Regions.ParseLayout(layout, mapSizeX, mapSizeZ)
	return regions, source, reason
end

return Sources
