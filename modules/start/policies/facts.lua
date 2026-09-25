local PolicyBuilder = require("modules/policy_builder")

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

---@class StartContext the engine and the match's start boxes
---@field springRepo Spring
---@field boxes StartBox[] as the api resolved them, whatever set them

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas string StartArea[] by ally team, in box order; ally teams without a box are absent
---@field Positions string StartPosition[] every team's start position known to the engine, in team order

---@class (partial) StartContract
---@field Facts StartFacts

---@type StartFacts
local Facts = PolicyBuilder.Facts({
	Areas = "areas",
	Positions = "positions",
})

Policies.On(Facts)
	.Default(Facts.Areas, function(ctx)
		local areas = {} ---@type StartArea[]
		for _, box in ipairs(ctx.boxes) do
			if not box.wholeMap then
				areas[#areas + 1] = {
					allyTeam = box.allyTeamID + 1 --[[@as integer]],
					name = box.name,
					anchors = box.ring,
					source = box.source,
				}
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

return { Facts = Facts }
