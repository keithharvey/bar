---@meta

local M = {}

M.UnitSharing = VFS.Include("common/unit_sharing.lua")
M.SharingModeUtils = VFS.Include("common/sharing_mode_utils.lua")
M.ResourceShareTax = VFS.Include("common/luaUtilities/resource_share_tax.lua")
M.KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")

return M
