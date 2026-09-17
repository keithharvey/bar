local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class EconomyState
---@field mexRegions MexRegion[]|nil the map's regions in elmos, once a layout has been found
---@field mexDeal MexRegionsDeal|nil who holds what, once the deal has run
---@field mexRegionsSource string|nil where the layout came from, for the log
local state = ModuleHandler.State(Modules.Economy) ---@type EconomyState

return state
