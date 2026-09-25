---@class StartBoxes the ally teams' start boxes as the game resolved them, one shape whether a modoption drew them or the engine's start script set rects
local Boxes = {}

---@class StartboxEntry one ally team's boxes, as luarules/gadgets/include/startbox_utilities.lua parses them
---@field boxes number[][][] rings of { x, z, strength? } in elmos
---@field startpoints number[][]|nil
---@field nameLong string|nil
---@field nameShort string|nil
---@field wholeMap boolean|nil

---@class StartboxConfig the startbox parser's result for the match
---@field byAllyTeam table<integer, StartboxEntry>|nil by ally team id, 0-based
---@field source string|nil
---@field explicit boolean true when a modoption set the boxes; false when they are the engine's rects

---@class StartBox one ally team's start box
---@field allyTeamID integer 0-based
---@field ring { x: number, z: number, strength: number|nil }[] in elmos; strength is set on curved anchors
---@field name string|nil the modoption's short name; a compass name for an engine rect
---@field source string the modoption that set it, or "engine"
---@field wholeMap boolean a box covering the map restricts nothing

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
---@return StartBox|nil nil when the entry has no ring
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
---@return StartBox|nil nil when the engine has no rect for the ally team
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
---@return StartBox[] by ally team id, gaia left out; from the modoption when one set the boxes, else the engine's rects
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
