local widget = widget ---@type Widget

---@load-file luaui/types/team_transfer.lua

function widget:GetInfo()
	return {
		name = "Team Transfer API Bridge",
		desc = "Exposes Team Transfer API to widgets via WG",
		author = "Team Transfer Framework",
		date = "2024",
		license = "GPL",
		layer = -1, -- Load before other widgets that depend on it
		enabled = true,
		handler = true,
		api = true,
	}
end

local TeamTransferAPI = VFS.Include("luarules/gadgets/team_transfer/api_widgets.lua")

function widget:Initialize()
	---@type TeamTransferAPI
	WG['TeamTransfer'] = TeamTransferAPI
end

function widget:Shutdown()
	WG['TeamTransfer'] = nil
end
