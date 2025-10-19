local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local unitPolicyScratch = {}

local Widgets = {}
Widgets.__index = Widgets

function Widgets.GetGlobals()
  return Shared.GetGlobals()
end

---Fast check for a unitDefID under allowed list (shared classifier)
---@param unitDefID number
function Widgets.IsShareableDef(unitDefID)
  return Shared.IsShareableDef(unitDefID)
end

---Decide communication case for UI messaging
---@param policy UnitTransferPolicyResult
---@return number
function Widgets.DecideCommunicationCase(policy)
  return Shared.DecideCommunicationCase(policy)
end

return Widgets

