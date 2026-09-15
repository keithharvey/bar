local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class StartArea one ally team's area, as the match resolved it
---@field allyTeam integer 1-based, the order the boxes come in
---@field name string|nil the box's label, the compass name the resolver gives it
---@field anchors { x: number, z: number, strength: number|nil }[] the ring, in elmos; strength marks a curved anchor
---@field source string where it came from: the modoption set, the host's override, or the engine

---@class StartPosition one team's start position, as the match has it
---@field allyTeam integer 1-based
---@field teamID integer
---@field x number
---@field z number

---@class StartContext what the match knows: the engine, and the game's startbox resolver
---@field springRepo Spring
---@field resolveBoxes fun(): table|nil, string|nil, boolean|nil the startbox resolver's config by allyTeam id, its source, and whether a modoption set it; when it did not, the engine's rects are the boxes; injectable for specs

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas string StartArea[] by ally team, in box order; unboxed ally teams absent
---@field Positions string StartPosition[] every team's start position the engine has, in team order

---@type StartFacts
local Facts = {
	Areas = "areas",
	Positions = "positions",
}

---@class StartContract
---@field Facts StartFacts

return PolicyBuilder.Contract(Modules.Start, {
	Facts = PolicyBuilder.Facts(Facts),
})
