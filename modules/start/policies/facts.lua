local Policy = require("modules/policy")

-- What the match's starts are. The api gathers the engine's answer into the context under each fact's name; a
-- mode that knows better provides it.
---@class StartContext
---@field springRepo Spring
---@field areas StartRegion[]
---@field positions StartPosition[]

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

return { Facts = Facts }
