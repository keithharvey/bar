local Policy = require("modules/policy")

---@class StartArea
---@field allyTeamID integer
---@field name string|nil
---@field anchors { x: number, z: number, strength: number|nil }[]
---@field source string

---@class StartPosition
---@field allyTeamID integer
---@field teamID integer
---@field x number
---@field z number

---@class StartContext
---@field springRepo Spring
---@field boxes StartBox[]

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas "areas"
---@field Positions "positions"

---@class (partial) StartContract
---@field Facts StartFacts

---@type StartFacts
local Facts = {
	Areas = "areas",
	Positions = "positions",
}
Policy.Facts(Facts)

Policies.On(Facts)
	.Default(Facts.Areas, function(ctx)
		local areas = {} ---@type StartArea[]
		for _, box in ipairs(ctx.boxes) do
			if not box.wholeMap then
				areas[#areas + 1] = {
					allyTeamID = box.allyTeamID,
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
					out[#out + 1] = { allyTeamID = allyTeamID, teamID = teamID, x = x, z = z }
				end
			end
		end
		return out
	end)

return { Facts = Facts }
