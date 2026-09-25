local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

---@return StartBoxes
local function resolveWithGame()
	local StartboxLib = require("luarules/gadgets/include/startbox_utilities")
	local config, source, explicit = StartboxLib.GetConfig()
	return { byAllyTeam = config, source = source, explicit = explicit == true }
end

---@class StartApi
return {
	---@param springRepo Spring
	---@param resolveBoxes (fun(): StartBoxes)|nil the resolver; the game's when absent
	---@return { areas: StartArea[], positions: StartPosition[] }
	Current = function(springRepo, resolveBoxes)
		---@type StartContext
		local ctx = { springRepo = springRepo, resolveBoxes = resolveBoxes or resolveWithGame }
		---@type StartContract
		local Start = ModuleHandler.Contract(Modules.Start)
		local Facts = Start.Facts
		local facts = ModuleHandler.Enrich(Facts, springRepo.GetModOptions and springRepo.GetModOptions() or {}, ctx)
		return { areas = facts[Facts.Areas] or {}, positions = facts[Facts.Positions] or {} }
	end,
}
