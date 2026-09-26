---@class StartBoxes the match's start areas, resolved: the modoption's polygons when one set them, else the engine's rects
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

---@class StartArea one ally team's start area, as the match resolved it: the modoption's polygon, or the engine's rect
---@field allyTeamID integer
---@field name string|nil
---@field anchors { x: number, z: number, strength: number|nil }[]
---@field source string

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
---@return StartArea|nil
local function fromEntry(allyTeamID, entry, source)
	local ring = entry.boxes and entry.boxes[1]
	if not ring or #ring < 3 or entry.wholeMap then
		return nil
	end
	local anchors = {}
	for i, pt in ipairs(ring) do
		anchors[i] = { x = pt[1], z = pt[2], strength = pt[3] }
	end
	return { allyTeamID = allyTeamID, name = entry.nameShort, anchors = anchors, source = source }
end

---@param springRepo Spring
---@param allyTeamID integer
---@return StartArea|nil
local function fromEngine(springRepo, allyTeamID)
	local xmin, zmin, xmax, zmax = springRepo.GetAllyTeamStartBox(allyTeamID)
	if not (xmin and xmax and zmin and zmax) or xmax <= xmin or zmax <= zmin then
		return nil
	end
	if xmin <= 0 and zmin <= 0 and xmax >= Game.mapSizeX and zmax >= Game.mapSizeZ then
		return nil
	end
	return {
		allyTeamID = allyTeamID,
		name = compassName((xmin + xmax) * 0.5, (zmin + zmax) * 0.5),
		anchors = { { x = xmin, z = zmin }, { x = xmax, z = zmin }, { x = xmax, z = zmax }, { x = xmin, z = zmax } },
		source = "engine",
	}
end

---@param springRepo Spring
---@param config StartboxConfig
---@return StartArea[] by ally team id, gaia left out
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
	local out = {} ---@type StartArea[]
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
