

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
	-- Expose the Team Transfer Widget API as WG.TeamTransfer
	---@type TeamTransferWidgetAPI
	WG.TeamTransfer = TeamTransferWidgetAPI

	Spring.Log("Team Transfer Bridge", "info", "WG.TeamTransfer initialized with predicate-based API")
end
