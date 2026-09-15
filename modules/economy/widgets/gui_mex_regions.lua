local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mex Regions",
		desc = "Under Map Assigned mex income: the map's regions in their holders' colours, pregame and whenever a mex is being placed",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

local EconomyEnums = VFS.Include("modules/economy/enums.lua")
if Spring.GetModOptions()[EconomyEnums.ModOptions.MexSplitting] ~= EconomyEnums.MexSplitting.MapAssigned then
	return false
end

local Deal = VFS.Include("modules/economy/lib/mex_regions/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
local readDeal = Deal.Reader()

---Region name -> holding team, from the typed per-team records every widget can read.
---@return table<string, integer>
local function holderByRegion()
	local byRegion = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local record = Shared.Holdings.Read(Spring, teamID) ---@type MexHoldingsRecord|nil
		if record and record.regions then
			for _, name in ipairs(record.regions) do
				byRegion[name] = teamID
			end
		end
	end
	return byRegion
end

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glText = gl.Text
local GL_LINE_LOOP = GL.LINE_LOOP
local GetGroundHeight = Spring.GetGroundHeight
local WorldToScreenCoords = Spring.WorldToScreenCoords

local isMex = {} ---@type table<integer, boolean>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end

local function placingAMex()
	local _, cmdID = Spring.GetActiveCommand()
	return cmdID ~= nil and cmdID < 0 and isMex[-cmdID] == true
end

local function showing()
	return Spring.GetGameFrame() <= 0 or placingAMex()
end

local UNHELD = { 0.6, 0.6, 0.6 }

---@param teamID integer|nil
---@return number[]
local function colourOf(teamID)
	if teamID == nil then
		return UNHELD
	end
	local r, g, b = Spring.GetTeamColor(teamID)
	return { r or 1, g or 1, b or 1 }
end

-- What each region draws with is fixed for the life of a deal: worked out once when the deal
-- changes, never per frame (player lookups allocate, and there is one per region per frame
-- otherwise).
local styledFor = nil ---@type table|nil the deal these styles were built for
local styles = {} ---@type { colour: number[], label: string }[]
local function stylesFor(deal)
	if styledFor == deal then
		return styles
	end
	styledFor = deal
	styles = {}
	local holders = holderByRegion()
	for i, region in ipairs(deal.regions) do
		local holder = holders[region.name]
		local label = region.name
		if holder ~= nil then
			local players = Spring.GetPlayerList(holder)
			local name = players and players[1] and Spring.GetPlayerInfo(players[1], false) or nil
			label = label .. " · " .. (name or ("team " .. holder))
		else
			label = label .. " · open"
		end
		styles[i] = { colour = colourOf(holder), label = label }
	end
	return styles
end

function widget:DrawWorldPreUnit()
	if not showing() then
		return
	end
	local deal = readDeal(Spring)
	if not deal then
		return
	end
	local style = stylesFor(deal)
	glLineWidth(3.0)
	for i, region in ipairs(deal.regions) do
		local c = style[i].colour
		glColor(c[1], c[2], c[3], 0.9)
		glBeginEnd(GL_LINE_LOOP, function()
			local poly = region.polygon
			for i, v in ipairs(poly) do
				local vn = poly[(i % #poly) + 1] or v
				local vx, vz, nx, nz = v[1] or 0, v[2] or 0, vn[1] or 0, vn[2] or 0
				local segLen = math.sqrt((nx - vx) ^ 2 + (nz - vz) ^ 2)
				local steps = math.max(1, math.ceil(segLen / 64))
				for s = 0, steps - 1 do
					local t = s / steps
					local x, z = vx + (nx - vx) * t, vz + (nz - vz) * t
					glVertex(x, (GetGroundHeight(x, z) or 0) + 6, z)
				end
			end
		end)
	end
	glLineWidth(1.0)
	glColor(1, 1, 1, 1)
end

function widget:DrawScreenEffects()
	if not showing() then
		return
	end
	local deal = readDeal(Spring)
	if not deal then
		return
	end
	local style = stylesFor(deal)
	for i, region in ipairs(deal.regions) do
		local gy = GetGroundHeight(region.centerX, region.centerZ) or 0
		local sx, sy, sz = WorldToScreenCoords(region.centerX, gy, region.centerZ)
		if sz and sz > 0 and sz < 1 then
			local c = style[i].colour
			glColor(c[1], c[2], c[3], 1)
			glText(style[i].label, sx, sy, 14, "cdo")
		end
	end
	glColor(1, 1, 1, 1)
end
