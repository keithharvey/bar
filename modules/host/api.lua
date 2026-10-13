local Spring = Spring --[[@as Recoil.Shared]]

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

---@class HostApi
return {
	-- The client that sends the host's commands this frame: formed and ranked on the frame's first ask on this
	-- handle, a lookup after, and the same answer on every client. False while no client is connected.
	---@return HostController|false
	Controller = function()
		---@type HostContract
		local Host = ModuleHandler.Contract(Modules.Host)
		return ModuleHandler.Ask(Host.Controller, Spring)
	end,
}
