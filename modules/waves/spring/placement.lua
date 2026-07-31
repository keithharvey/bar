--- Burrow and boss placement: a PORT, not a rewrite.
---
--- This is the cascade of "try somewhere good, then somewhere adequate, then
--- anywhere" that decides where a burrow appears, plus the spawn box that
--- grows out of the director team's start box as anger climbs. The logic is
--- the monolith's, kept deliberately close so a playtester recognises the
--- placements; what changed is the plumbing — every one of the file-level
--- globals it used to read (lsx1..lsz2, the start box, the retry counters)
--- now arrives as `state`, which is what makes it saveable and re-entrant per
--- director.
---
--- Spring lives here. Nothing above spring/ may include this file.

local Placement = {}

local MAX_TRIES = 30
local FLAT_TOLERANCE = 30
local MIN_BOX_SIDE = 512

---@param deps { positionChecks: table, enemyLib: table, mapSizeX: number, mapSizeZ: number }
---@return table
function Placement.New(deps)
	local checks = deps.positionChecks
	local enemyLib = deps.enemyLib
	local MAPSIZEX = deps.mapSizeX
	local MAPSIZEZ = deps.mapSizeZ
	local mRandom = math.random

	local placement = {}

	---Seed the start box the whole cascade is measured against. A director
	---team with no box at all (or one covering the map) falls back to "avoid
	---players", because "spawn in your box" and "the box is the map" would put
	---burrows on top of the people playing.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	placement.InitialBox = function(spec, state)
		local x1, z1, x2, z2 = enemyLib.GetAdjustedStartBox(spec.allyTeamID, spec.burrows.size * 1.5)
		state.startBox = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }

		local mode = state.params.placement
		if mode == "initialbox" or mode == "alwaysbox" or mode == "initialbox_post" then
			local noBox = not x1 or not z1 or not x2 or not z2
			local wholeMap = not noBox and x1 == 0 and z1 == 0 and x2 == MAPSIZEX and z2 == MAPSIZEX
			if noBox or wholeMap then
				state.params.placement = "avoid"
				state.noStartBox = true
			end
		end

		state.spawnBox = {
			x1 = x1 or 0,
			z1 = z1 or 0,
			x2 = x2 or MAPSIZEX,
			z2 = z2 or MAPSIZEZ,
		}
	end

	---The growing box: one percent of the map per point of anger, out of the
	---start box in every direction. It is the pacing device that keeps early
	---burrows close to home and late ones anywhere.
	---@param state WaveDirectorState
	---@param techAnger number
	placement.UpdateBox = function(state, techAnger)
		local mode = state.params.placement
		if mode ~= "initialbox_post" and mode ~= "initialbox" then
			return
		end
		local start = state.startBox
		if start == nil or start.x1 == nil then
			return
		end
		local reach = techAnger + 15
		local box = {
			x1 = math.max(start.x1 - ((MAPSIZEX * 0.01) * reach), 0),
			z1 = math.max(start.z1 - ((MAPSIZEZ * 0.01) * reach), 0),
			x2 = math.min(start.x2 + ((MAPSIZEX * 0.01) * reach), MAPSIZEX),
			z2 = math.min(start.z2 + ((MAPSIZEZ * 0.01) * reach), MAPSIZEZ),
		}
		-- A degenerate box places nothing at all; widen it around its centre.
		if box.x2 - box.x1 < MIN_BOX_SIDE then
			box.x1 = math.max(0, math.floor((box.x1 + box.x2) / 2) - MIN_BOX_SIDE / 2)
			box.x2 = box.x1 + MIN_BOX_SIDE
		end
		if box.z2 - box.z1 < MIN_BOX_SIDE then
			box.z1 = math.max(0, math.floor((box.z1 + box.z2) / 2) - MIN_BOX_SIDE / 2)
			box.z2 = box.z1 + MIN_BOX_SIDE
		end
		state.spawnBox = box
	end

	---@param x number
	---@param y number
	---@param z number
	---@param spread number
	---@param allyTeamID integer
	---@param wantScum boolean
	---@return boolean
	local function goodGround(x, y, z, spread, allyTeamID, wantScum)
		if not checks.FlatAreaCheck(x, y, z, spread, FLAT_TOLERANCE, true) then
			return false
		end
		if not checks.OccupancyCheck(x, y, z, spread) then
			return false
		end
		if wantScum and GG.IsPosInRaptorScum and not GG.IsPosInRaptorScum(x, y, z) then
			return false
		end
		return true
	end

	---Probe a box for somewhere a burrow fits.
	---@return boolean found, number|nil x, number|nil y, number|nil z
	local function probe(box, spread, attempts, allyTeamID, wantScum, visibility)
		if box == nil or box.x1 + spread >= box.x2 - spread or box.z1 + spread >= box.z2 - spread then
			return false
		end
		for _ = 1, attempts do
			local x = mRandom(box.x1 + spread, box.x2 - spread)
			local z = mRandom(box.z1 + spread, box.z2 - spread)
			local y = Spring.GetGroundHeight(x, z)
			if goodGround(x, y, z, spread, allyTeamID, wantScum) and visibility(x, y, z, spread) then
				return true, x, y, z
			end
		end
		return false
	end

	---Find a burrow position. Three cascades, picked by placement mode:
	---inside creep, inside the growing box, forced into the start box; or, in
	---"avoid" mode, three progressively laxer sensor tests.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number game seconds
	---@return boolean found, number|nil x, number|nil y, number|nil z
	local function findBurrowSpot(spec, state, t)
		local spread = spec.burrows.size * 1.5
		local allyTeamID = spec.allyTeamID
		local found, x, y, z

		if state.params.placement ~= "avoid" then
			-- Attempt 1: inside existing creep, once grace is over. Skipped
			-- entirely when the flavor has no creep to speak of.
			if spec.burrows.useScum and GG.IsPosInRaptorScum and t >= state.params.gracePeriod then
				found, x, y, z = probe(
					{ x1 = 0, z1 = 0, x2 = MAPSIZEX, z2 = MAPSIZEZ },
					spread, 1000, allyTeamID, true,
					function(px, py, pz, s)
						return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
					end
				)
			end

			-- Attempt 2: the growing spawn box, out of every player's sight.
			if not found then
				found, x, y, z = probe(state.spawnBox, spread, 1000, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
						and checks.VisibilityCheck(px, py, pz, s, allyTeamID, true, false, false)
				end)
			end

			-- Attempt 3: forced into the start box, sight be damned. On a map
			-- with no box for this team, keep the enemy-sensor test — that is
			-- the only thing stopping a burrow landing on someone's factory.
			if not found then
				local noBox = state.noStartBox
				found, x, y, z = probe(state.startBox, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return (not noBox) or checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
				end)
			end
		else
			-- Avoid mode: anywhere the players cannot see. Each attempt drops
			-- one sensor class, so a heavily radared map still gets burrows.
			local box = state.spawnBox
			found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
				return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
			end)
			if not found then
				found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, false)
				end)
			end
			if not found then
				found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, false, false)
				end)
			end
		end

		if not found then
			return false
		end

		-- Ground that is neither land nor sea drowns half a burrow's spawns.
		local surface = checks.LandOrSeaCheck(x, y, z, spec.burrows.size)
		if surface == "mixed" or surface == "death" then
			return false
		end

		-- During grace, burrows must SPREAD: refusing existing creep is what
		-- makes the opening map-wide instead of one fat nest.
		if t < state.params.gracePeriod * 0.9 and GG.IsPosInRaptorScum and GG.IsPosInRaptorScum(x, y, z) then
			return false
		end

		return true, x, y, z
	end

	---Place one burrow. Which def appears is the first in-bracket candidate
	---whose coin lands, so a hot map fields the higher-tier beacon.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number
	---@param techAnger number
	---@return integer|nil burrowID, number|nil x, number|nil y, number|nil z
	placement.SpawnBurrow = function(spec, state, t, techAnger)
		local found, x, y, z = findBurrowSpot(spec, state, t)
		if not found then
			state.timeOfLastBurrow = t
			return nil
		end

		local anger = math.max(1, techAnger)
		local names = {}
		for name in pairs(spec.burrows.defs) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local data = spec.burrows.defs[name]
			if mRandom() <= state.params.spawnChance and data.minAnger < anger and data.maxAnger > anger then
				local burrowID = Spring.CreateUnit(name, x, y, z, mRandom(0, 3), spec.teamID)
				if burrowID then
					return burrowID, x, y, z
				end
			end
		end
		return nil
	end

	---One burrow attempt, with the widening that keeps a cramped start box
	---from starving the director: every failed round pushes the box out by
	---another burrow width.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number
	---@param techAnger number
	---@return integer|nil burrowID, number|nil x, number|nil y, number|nil z
	placement.TrySpawnBurrow = function(spec, state, t, techAnger)
		local maxRetries = math.floor((state.params.gracePeriod - t) / 20)
		local burrowID, x, y, z = placement.SpawnBurrow(spec, state, t, techAnger)
		state.timeOfLastBurrow = t

		if not state.fullySpawned then
			local count = 0
			for _ in pairs(state.burrows) do
				count = count + 1
			end
			if count > 1 then
				state.fullySpawned = true
			elseif state.spawnRetries >= maxRetries or state.firstSpawn then
				state.spawnAreaMultiplier = state.spawnAreaMultiplier + 1
				local x1, z1, x2, z2 = enemyLib.GetAdjustedStartBox(
					spec.allyTeamID, spec.burrows.size * 1.5 * state.spawnAreaMultiplier)
				state.startBox = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
				placement.InitialBox(spec, state)
				state.spawnRetries = 0
			else
				state.spawnRetries = state.spawnRetries + 1
			end
		end

		if state.firstSpawn and burrowID then
			-- The first burrow sets the wave clock, so the opening wave lands
			-- ten seconds after grace and not one cadence later.
			state.timeOfLastWave = (state.params.gracePeriod + 10) - state.params.spawnRate
			state.firstSpawn = false
		end
		return burrowID, x, y, z
	end

	---Where the boss lands. A live burrow is the preferred door; failing
	---that, unseen ground in the start box; failing that, anywhere in the box
	---that is flat, empty and off the map edge.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@return number|nil x, number|nil y, number|nil z
	placement.BossPosition = function(spec, state)
		local best, bx, by, bz = 0, nil, nil, nil
		for burrowID in pairs(state.burrows) do
			local x, y, z = Spring.GetUnitPosition(burrowID)
			if x and y and z and not state.boss.ids[burrowID] then
				local score = mRandom(1, 1000)
				if score > best then
					best, bx, by, bz = score, x, y, z
				end
			end
		end
		if bx then
			return bx, by, bz
		end

		local box = state.startBox
		if box == nil or box.x1 == nil then
			return nil
		end

		local tries = 0
		repeat
			tries = tries + 1
			local x = mRandom(box.x1, box.x2)
			local z = mRandom(box.z1, box.z2)
			local y = Spring.GetGroundHeight(x, z)
			local ok = checks.FlatAreaCheck(x, y, z, 128, FLAT_TOLERANCE, true)
			if ok then
				-- Past a third of the budget, stop demanding radar silence.
				local strict = tries < MAX_TRIES * 3
				ok = checks.VisibilityCheckEnemy(x, y, z, spec.burrows.size, spec.allyTeamID, true, true, strict)
			end
			if ok then
				ok = checks.OccupancyCheck(x, y, z, spec.burrows.size * 0.25)
			end
			if ok then
				ok = checks.MapEdgeCheck(x, y, z, 256)
			end
			if ok then
				return x, y, z
			end
		until tries >= MAX_TRIES * 6

		for _ = 1, 100 do
			local x = mRandom(box.x1, box.x2)
			local z = mRandom(box.z1, box.z2)
			local y = Spring.GetGroundHeight(x, z)
			if checks.StartboxCheck(x, y, z, spec.allyTeamID)
				and checks.FlatAreaCheck(x, y, z, 128, FLAT_TOLERANCE, true)
				and checks.MapEdgeCheck(x, y, z, 128)
				and checks.OccupancyCheck(x, y, z, 128)
			then
				return x, y, z
			end
		end
		return nil
	end

	---The nearest burrow to a point — what a minion or a re-target asks for.
	---@param state WaveDirectorState
	---@return integer|nil burrowID, number distance
	placement.NearestBurrow = function(state, tx, ty, tz)
		local nearest, nearestDistance = nil, 999999
		for burrowID in pairs(state.burrows) do
			local bx, by, bz = Spring.GetUnitPosition(burrowID)
			if bx and by and bz then
				local distance = math.ceil((math.abs(tx - bx) + math.abs(ty - by) + math.abs(tz - bz)) * 0.5)
				if distance < nearestDistance then
					nearest, nearestDistance = burrowID, distance
				end
			end
		end
		return nearest, nearestDistance
	end

	return placement
end

return Placement
