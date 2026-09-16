local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Contract = VFS.Include("modules/start/contract.lua") ---@type StartContract

local function resolveWithGame()
	local StartboxLib = VFS.Include("luarules/gadgets/include/startbox_utilities.lua")
	local config, source, explicit = StartboxLib.GetConfig()
	return config, source, explicit
end

---@class StartApi
return {
	---@param springRepo Spring
	---@param resolveBoxes (fun(): table|nil, string|nil, boolean|nil)|nil the resolver; the game's when absent
	---@return { areas: StartArea[], positions: StartPosition[] }
	Current = function(springRepo, resolveBoxes)
		---@type StartContext
		local ctx = { springRepo = springRepo, resolveBoxes = resolveBoxes or resolveWithGame }
		local facts =
			ModuleHandler.Enrich(Contract.Facts, springRepo.GetModOptions and springRepo.GetModOptions() or {}, ctx)
		return { areas = facts[Contract.Facts.Areas] or {}, positions = facts[Contract.Facts.Positions] or {} }
	end,
}
