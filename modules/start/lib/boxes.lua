---@class StartBoxes
local Boxes = {}

---@class StartboxEntry
---@field boxes number[][][]
---@field startpoints number[][]|nil
---@field nameLong string|nil
---@field nameShort string|nil
---@field wholeMap boolean|nil

---@class StartboxConfig
---@field byAllyTeam table<integer, StartboxEntry>|nil
---@field source string|nil
---@field explicit boolean

---@class StartBox
---@field allyTeamID integer
---@field ring { x: number, z: number, strength: number|nil }[]
---@field name string|nil
---@field source string
---@field wholeMap boolean

---@param cx number
---@param cz number
---@return string
local function compassName(cx, cz)
	local fx, fz = cx / Game.mapSizeX, cz / Game.mapSizeZ
	local ns = (fz < 0.33) and "N" or (fz > 0.66) and "S" or ""
	local ew = (fx < 0.33) and "W" or (fx > 0.66) and "E" or ""
	local short = ns .. ew
	return short ~= "" and short or "Center"
end

---@param allyTeamID integer
---@param entry StartboxEntry
---@param source string
---@return StartBox|nil
local function fromEntry(allyTeamID, entry, source)
	local ring = entry.boxes and entry.boxes[1]
	if not ring or #ring < 3 then
		return nil
	end
	local anchors = {}
	for i, pt in ipairs(ring) do
		anchors[i] = { x = pt[1], z = pt[2], strength = pt[3] }
	end
	return {
		allyTeamID = allyTeamID,
		ring = anchors,
		name = entry.nameShort,
		source = source,
		wholeMap = entry.wholeMap == true,
	}
end

---@param springRepo Spring
---@param allyTeamID integer
---@return StartBox|nil
local function fromEngine(springRepo, allyTeamID)
	local xmin, zmin, xmax, zmax = springRepo.GetAllyTeamStartBox(allyTeamID)
	if not (xmin and xmax and zmin and zmax) or xmax <= xmin or zmax <= zmin then
		return nil
	end
	return {
		allyTeamID = allyTeamID,
		ring = { { x = xmin, z = zmin }, { x = xmax, z = zmin }, { x = xmax, z = zmax }, { x = xmin, z = zmax } },
		name = compassName((xmin + xmax) * 0.5, (zmin + zmax) * 0.5),
		source = "engine",
		wholeMap = xmin <= 0 and zmin <= 0 and xmax >= Game.mapSizeX and zmax >= Game.mapSizeZ,
	}
end

---@param springRepo Spring
---@param config StartboxConfig
---@return StartBox[]
function Boxes.Resolve(springRepo, config)
	local gaia = springRepo.GetGaiaTeamID and springRepo.GetGaiaTeamID() or nil
	local gaiaAlly = gaia and springRepo.GetTeamAllyTeamID and springRepo.GetTeamAllyTeamID(gaia) or nil
	local ids = {}
	if config.explicit and config.byAllyTeam then
		for allyTeamID in pairs(config.byAllyTeam) do
			ids[#ids + 1] = allyTeamID
		end
	else
		for _, allyTeamID in ipairs(springRepo.GetAllyTeamList() or {}) do
			ids[#ids + 1] = allyTeamID
		end
	end
	table.sort(ids)
	local out = {} ---@type StartBox[]
	for _, allyTeamID in ipairs(ids) do
		if allyTeamID ~= gaiaAlly then
			local box
			if config.explicit and config.byAllyTeam then
				box = fromEntry(allyTeamID, config.byAllyTeam[allyTeamID], config.source or "modoption")
			else
				box = fromEngine(springRepo, allyTeamID)
			end
			out[#out + 1] = box
		end
	end
	return out
end

return Boxes
