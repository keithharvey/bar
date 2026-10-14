local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

-- Which client controls the host: the ranking is the policy, the player list is its context, formed once a frame.
describe("the host's controller", function()
	local Host = ModuleHandler.Contract(Modules.Host)

	---@param clients table<integer, { active: boolean?, spectator: boolean?, ping: number? }> by player id
	---@return table a stand-in engine with a frame to advance
	local function engine(clients)
		local frame = 1
		return {
			clients = clients,
			GetModOptions = function()
				return {}
			end,
			GetGameFrame = function()
				return frame
			end,
			advance = function()
				frame = frame + 1
			end,
			GetPlayerList = function()
				local ids = {}
				for id in pairs(clients) do
					ids[#ids + 1] = id
				end
				table.sort(ids)
				return ids
			end,
			GetPlayerInfo = function(id)
				local c = clients[id]
				return "p" .. id, c.active ~= false, c.spectator == true, 0, 0, c.ping
			end,
		}
	end

	it("prefers a player to a spectator, whatever their pings", function()
		local spring = engine({ [1] = { spectator = true, ping = 0 }, [2] = { ping = 5 } })
		local controller = ModuleHandler.Ask(Host.Controller, spring)
		assert.are.equal(2, controller.playerID)
		assert.is_false(controller.spectator)
		assert.is_true(controller.lagging)
	end)

	it("prefers a current client to a lagging one, then the lowest lag, then the lowest id", function()
		assert.are.equal(
			3,
			ModuleHandler.Ask(Host.Controller, engine({ [1] = { ping = 4 }, [3] = { ping = 1 } })).playerID
		)
		assert.are.equal(
			2,
			ModuleHandler.Ask(Host.Controller, engine({ [1] = { ping = 5 }, [2] = { ping = 4 } })).playerID
		)
		assert.are.equal(
			1,
			ModuleHandler.Ask(Host.Controller, engine({ [1] = { ping = 1 }, [2] = { ping = 2 } })).playerID
		)
	end)

	it("counts a client without a ping as current, and skips the inactive", function()
		local spring = engine({ [1] = { active = false, ping = 0 }, [2] = {}, [3] = { ping = 9 } })
		assert.are.equal(2, ModuleHandler.Ask(Host.Controller, spring).playerID)
	end)

	it("is false while nobody is connected", function()
		assert.is_false(ModuleHandler.Ask(Host.Controller, engine({})))
	end)

	it("is one ranking per frame: the same record until the frame moves, then ranked again", function()
		local spring = engine({ [1] = { ping = 0 }, [2] = { ping = 0 } })
		local first = ModuleHandler.Ask(Host.Controller, spring)
		assert.are.equal(1, first.playerID)
		spring.clients[1].ping = 9
		assert.are.equal(first, ModuleHandler.Ask(Host.Controller, spring))
		spring.advance()
		assert.are.equal(2, ModuleHandler.Ask(Host.Controller, spring).playerID)
	end)
end)
