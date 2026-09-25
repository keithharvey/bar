local Geometry = require("modules/regions/lib/geometry")
local Modules = require("modules/enums").Modules
local PolicyBuilder = require("modules/policy_builder")
local Problems = require("modules/regions/lib/problems")
local RegionEnums = require("modules/regions/enums")
local RegionsContract = require("modules/regions/contract")

---@class StartRegion: Region a team's start as drawn in the editor: a single position, or the area the positions lie in
---@field type "start"
---@field team integer start ordinal; start 1 is team 1
---@field name string|nil the area's label

---@class StartArea one ally team's start area, as resolved for the match
---@field allyTeam integer 1-based, in box order
---@field name string|nil the box's label; a compass name assigned by the resolver
---@field anchors { x: number, z: number, strength: number|nil }[] the ring in elmos; strength is set on curved anchors
---@field source string origin: the modoption, the host's override, or the engine

---@class StartPosition one team's start position for the match
---@field allyTeam integer 1-based
---@field teamID integer
---@field x number
---@field z number

---@class StartBoxEntry one ally team's boxes, as resolved by luarules/gadgets/include/startbox_utilities.lua
---@field boxes number[][][] rings of { x, z, strength? } in elmos
---@field startpoints number[][]|nil
---@field nameLong string|nil
---@field nameShort string|nil
---@field wholeMap boolean|nil

---@class StartBoxes the startbox resolver's result for the match
---@field byAllyTeam table<integer, StartBoxEntry>|nil by ally team id, 0-based
---@field source string|nil
---@field explicit boolean true when a modoption set the boxes; false when they are the engine's rects

---@class StartContext the engine and the game's startbox resolver
---@field springRepo Spring
---@field resolveBoxes fun(): StartBoxes injectable for specs

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas string StartArea[] by ally team, in box order; ally teams without a box are absent
---@field Positions string StartPosition[] every team's start position known to the engine, in team order

---@type StartFacts
local Facts = {
	Areas = "areas",
	Positions = "positions",
}

---@class StartRegionsSetStages start's stages on the regions module's set check, for the start type
---@field AreasDisjoint string no two start areas overlap; sharing an edge is allowed

---@type StartRegionsSetStages
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}

---@class StartRegionsNamesStages start's stages on the regions module's naming, for the start type
---@field FromTeam string an unnamed start is named after its team

---@type StartRegionsNamesStages
local RegionsNames = {
	FromTeam = "FromTeam",
}

---@class StartRegionEnv the keys start's region stages read from the caller-supplied env (see RegionSetContext.env)
---@field starts { allyTeam: integer, x: number, z: number }[]|nil the map's start positions, when the caller has them

---@class StartRegionsDescribeStages start's stages on the regions module's description, for regions of any type
---@field NearestStart string the start inside the region, or else the nearest to its centre; adds nothing when env.starts is nil

---@type StartRegionsDescribeStages
local RegionsDescribe = {
	NearestStart = "NearestStart",
}

---@class StartContract
---@field Facts StartFacts
---@field RegionsSet StartRegionsSetStages
---@field RegionsNames StartRegionsNamesStages
---@field RegionsDescribe StartRegionsDescribeStages

return PolicyBuilder.Contract(Modules.Start, {
	Facts = PolicyBuilder.Facts(Facts),
	RegionsSet = PolicyBuilder.Contributes(RegionsContract.CheckSet, RegionsSet),
	RegionsNames = PolicyBuilder.Contributes(RegionsContract.Names, RegionsNames),
	RegionsDescribe = PolicyBuilder.Contributes(RegionsContract.Describe, RegionsDescribe),
}, function(Policies)
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

	Policies.On(Facts)
		.Default(Facts.Areas, function(ctx)
			local boxes = ctx.resolveBoxes()
			local areas = {} ---@type StartArea[]
			if boxes.explicit and boxes.byAllyTeam then
				local ids = {}
				for allyTeamID in pairs(boxes.byAllyTeam) do
					ids[#ids + 1] = allyTeamID
				end
				table.sort(ids)
				for _, allyTeamID in ipairs(ids) do
					local entry = boxes.byAllyTeam[allyTeamID]
					local ring = entry and not entry.wholeMap and entry.boxes and entry.boxes[1]
					if ring and #ring >= 3 then
						local anchors = {}
						for i, pt in ipairs(ring) do
							anchors[i] = { x = pt[1], z = pt[2], strength = pt[3] }
						end
						areas[#areas + 1] = {
							allyTeam = allyTeamID + 1 --[[@as integer]],
							name = entry.nameShort,
							anchors = anchors,
							source = boxes.source or "modoption",
						}
					end
				end
				return areas
			end
			local spring = ctx.springRepo
			local gaia = spring.GetGaiaTeamID and spring.GetGaiaTeamID() or nil
			local gaiaAlly = gaia and spring.GetTeamAllyTeamID and spring.GetTeamAllyTeamID(gaia) or nil
			local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
			for _, allyTeamID in ipairs(spring.GetAllyTeamList() or {}) do
				if allyTeamID ~= gaiaAlly then
					local xmin, zmin, xmax, zmax = spring.GetAllyTeamStartBox(allyTeamID)
					if xmin and xmax and zmin and zmax and xmax > xmin and zmax > zmin then
						local wholeMap = xmin <= 0 and zmin <= 0 and xmax >= mapX and zmax >= mapZ
						if not wholeMap then
							areas[#areas + 1] = {
								allyTeam = allyTeamID + 1 --[[@as integer]],
								name = compassName((xmin + xmax) * 0.5, (zmin + zmax) * 0.5),
								anchors = {
									{ x = xmin, z = zmin },
									{ x = xmax, z = zmin },
									{ x = xmax, z = zmax },
									{ x = xmin, z = zmax },
								},
								source = "engine",
							}
						end
					end
				end
			end
			return areas
		end)
		.Default(Facts.Positions, function(ctx)
			local spring = ctx.springRepo
			local out = {} ---@type StartPosition[]
			local gaia = spring.GetGaiaTeamID and spring.GetGaiaTeamID() or nil
			for _, teamID in ipairs(spring.GetTeamList() or {}) do
				if teamID ~= gaia then
					local x, _, z = spring.GetTeamStartPosition(teamID)
					if x and z and (x > 0 or z > 0) then
						local allyTeamID = spring.GetTeamAllyTeamID(teamID) or 0
						out[#out + 1] = { allyTeam = allyTeamID + 1, teamID = teamID, x = x, z = z }
					end
				end
			end
			return out
		end)

	Policies.On(RegionsContract.Names).Apply(RegionsNames.FromTeam, function(ctx)
		if ctx.type.key ~= RegionEnums.Types.Start then
			return
		end
		for i, region in ipairs(ctx.regions) do
			---@cast region StartRegion
			if region.team ~= nil then
				ctx.bases[i] = tostring(region.team)
			end
		end
	end)

	Policies.On(RegionsContract.CheckSet).Apply(RegionsSet.AreasDisjoint, function(ctx)
		if ctx.type.key ~= RegionEnums.Types.Start then
			return
		end
		local label = ctx.type.label:lower()
		for i, a in ipairs(ctx.regions) do
			for j, b in ipairs(ctx.regions) do
				if i ~= j and a.vertices and b.vertices and Geometry.Overlaps(a.vertices, b.vertices) then
					Problems.OfRegion(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
				end
			end
		end
	end)

	Policies.On(RegionsContract.Describe).Apply(RegionsDescribe.NearestStart, function(ctx)
		local starts = (ctx.env --[[@as StartRegionEnv]]).starts
		if not starts or #starts == 0 then
			return
		end
		local vertices = ctx.region.vertices or {}
		for _, start in ipairs(starts) do
			if Geometry.Contains(start.x, start.z, vertices) then
				ctx.lines[#ctx.lines + 1] = { "Start", string.format("ally team %d starts inside", start.allyTeam) }
				return
			end
		end
		local cx, cz = Geometry.Centroid(vertices)
		local best, bestD = starts[1], math.huge
		for _, start in ipairs(starts) do
			local d = Geometry.Distance(cx, cz, start.x, start.z)
			if d < bestD then
				best, bestD = start, d
			end
		end
		ctx.lines[#ctx.lines + 1] =
			{ "Nearest start", string.format("ally team %d, %.0f elmos from the centre", best.allyTeam, bestD) }
	end)
end)
