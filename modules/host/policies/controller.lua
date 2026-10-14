local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")

-- Which client sends the commands that control the host: a ranking over the connected clients, the same on every one
--
---@class HostClient one connected client as the ranking reads it
---@field playerID integer
---@field spectator boolean
---@field lag number seconds behind, when too far behind to control the host; 0 when current

---@class HostControllerContext: PolicyContext
---@field clients HostClient[] the active clients, this frame
---@field laggingSeconds number the ping at which a client is too far behind to control the host

---@class HostController the one client every client agrees on
---@field playerID integer
---@field spectator boolean
---@field lagging boolean

---@class HostLatencyFacts: PolicyFacts<HostControllerContext>
---@field LaggingSeconds "laggingSeconds" the threshold; a mode that knows its server better provides it

---@type HostLatencyFacts
local Latency = {
	LaggingSeconds = "laggingSeconds",
}
Policy.Facts(Latency)

---@class HostControllerPolicy: PolicySteps<HostControllerContext, HostController>
---@field NoClients "NoClients"
---@field Preferred "Preferred"

---@type HostControllerPolicy
local Controller = {
	NoClients = "NoClients",
	Preferred = "Preferred",
}
Policy.Single(Controller, function(t)
	---@cast t HostController
	return t.playerID, t.spectator, t.lagging
end)

-- Connected clients are behind always by a given latency plus up to 16 frames between keyframes.
Policies.For(Latency).Default(Latency.LaggingSeconds, function()
	return 3.0
end)

-- The clients, read into the same table every frame: who is active, who spectates, and how far behind each is. No
-- key: one context per engine.
---@param ctx HostControllerContext
---@param spring SpringBoth
local function clients(ctx, spring)
	---@type HostContract
	local Host = ModuleHandler.Contract(Modules.Host)
	ctx.clients = ctx.clients or {}
	ctx.springRepo = spring
	ctx.modOptions = spring.GetModOptions()
	local resolved = ModuleHandler.LoadEnrichers(Host.Latency)
	local live = ModuleHandler.LiveModulesFor(ctx.modOptions)
	for field, value in pairs(ModuleHandler.EnrichWith(resolved, live, ctx)) do
		ctx[field] = value
	end

	local list, n = ctx.clients, 0
	for _, playerID in ipairs(spring.GetPlayerList(true) or {}) do
		local _, active, spectator, _, _, ping = spring.GetPlayerInfo(playerID, false)
		if active then
			n = n + 1
			local client = list[n] or {}
			list[n] = client
			client.playerID = playerID
			client.spectator = spectator == true
			ping = ping or 0
			client.lag = ping >= ctx.laggingSeconds and ping or 0
		end
	end
	for i = #list, n + 1, -1 do
		list[i] = nil
	end
end

-- Players before spectators, current before lagging, then the lowest lag, then the lowest player id.
---@param best HostClient
---@param client HostClient
---@return boolean
local function preferred(best, client)
	if best.spectator ~= client.spectator then
		return best.spectator
	end
	if best.lag ~= client.lag then
		return client.lag < best.lag
	end
	return client.playerID < best.playerID
end

Policies.On(Controller)
	.FormContext(clients)
	.Unless(Controller.NoClients, function(ctx)
		return #ctx.clients == 0
	end)
	.Answer(Controller.Preferred, function(ctx)
		local best = ctx.clients[1]
		for i = 2, #ctx.clients do
			if preferred(best, ctx.clients[i]) then
				best = ctx.clients[i]
			end
		end
		return { playerID = best.playerID, spectator = best.spectator, lagging = best.lag > 0 }
	end)

---@class (partial) HostContract
local Contract = {}
Contract.Controller = Controller
Contract.Latency = Latency

return Contract
