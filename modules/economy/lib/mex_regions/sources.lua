-- Where a map's layout comes from, first found wins:
--   1. the mex_regions_layout modoption: json, plain or as the startbox payload base64url(zlib(json)),
--      the way the lobby carries startboxes from maps-metadata
--   2. a file the map ships, luarules/configs/mex_regions.lua

local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local EconomyEnums = VFS.Include("modules/economy/enums.lua")

---@class MexRegionSources
local Sources = {}

local MAP_FILE = "luarules/configs/mex_regions.lua"

---@param modOptions table<string, any>
---@param mapName string
---@return table|nil layout
---@return string source where it came from, or what was looked for
local function find(modOptions, mapName)
	local raw = modOptions[EconomyEnums.ModOptions.MexRegionsLayout]
	if type(raw) == "string" and raw ~= "" then
		return Regions.DecodeLayout(raw), "modoption " .. EconomyEnums.ModOptions.MexRegionsLayout
	end
	if VFS.FileExists(MAP_FILE) then
		return VFS.Include(MAP_FILE), MAP_FILE .. " (from the map)"
	end
	return nil, "no layout: neither the modoption nor the map's " .. MAP_FILE
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string source
---@return string|nil reason why there are none
function Sources.Load(modOptions, mapName, mapSizeX, mapSizeZ)
	local layout, source = find(modOptions, mapName)
	if layout == nil then
		return nil, source, nil
	end
	local regions, reason = Regions.ParseLayout(layout, mapSizeX, mapSizeZ)
	return regions, source, reason
end

return Sources
