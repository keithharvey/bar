---@meta

local M = {}

M.UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
M.SharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")
M.ResourceShareTax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
M.KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")

return M
