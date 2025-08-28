

-- Team Transfer Bridge Widget
-- Exposes the Team Transfer API as WG.TeamTransfer for other widgets to use

---@class TeamTransferBridgeWidget : Widget
local widget = widget

---@type TeamTransferWidgetAPI
local TeamTransferWidgetAPI = VFS.Include("luarules/gadgets/team_transfer/api_widgets.lua")

function widget:GetInfo()
	return {
		name = "Team Transfer Bridge",
		desc = "Exposes Team Transfer API as WG.TeamTransfer for widgets",
		author = "Team Transfer Framework",
		date = "2025",
		license = "GPL v2 or later",
		layer = -1000, -- Load very early so other widgets can use WG.TeamTransfer
		enabled = true,
	}
end

-- No longer need cache management - predicate-based system handles caching internally

function widget:Initialize()
	Spring.Log("TEAM TRANSFER INIT", LOG.ERROR, "[BRIDGE_WIDGET] Starting team_transfer_bridge.lua initialization")

	-- Expose the Team Transfer Widget API as WG.TeamTransfer
	---@type TeamTransferWidgetAPI
	WG.TeamTransfer = TeamTransferWidgetAPI

	Spring.Log("TEAM TRANSFER INIT", LOG.ERROR, "[BRIDGE_WIDGET] WG.TeamTransfer assigned successfully")
	Spring.Log("TEAM TRANSFER INIT", LOG.ERROR, "[BRIDGE_WIDGET] team_transfer_bridge.lua initialization completed")

	-- Verify the API is available
	if WG.TeamTransfer then
		Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "[BRIDGE_WIDGET] WG.TeamTransfer API verification:")
		local apiFunctions = {"CanShareMetal", "CanShareEnergy", "CanShareUnits", "GetResourceTransferData", "GetUnitTransferData"}
		for _, funcName in ipairs(apiFunctions) do
			if WG.TeamTransfer[funcName] then
				Spring.Log("TEAM TRANSFER DEBUG", LOG.ERROR, "[BRIDGE_WIDGET]   ✓ " .. funcName .. " available")
			else
				Spring.Log("TEAM TRANSFER WARN", LOG.ERROR, "[BRIDGE_WIDGET]   ✗ " .. funcName .. " missing")
			end
		end
	else
		Spring.Log("TEAM TRANSFER ERROR", LOG.ERROR, "[BRIDGE_WIDGET] WG.TeamTransfer assignment failed!")
	end
end
