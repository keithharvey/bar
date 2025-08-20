-- Unsynced helper functions for widgets to access Team Transfer functionality
-- This file includes the necessary modules directly and provides unsynced implementations

---@load-file luaui/types/team_transfer.lua

---@class TeamTransferAPI
local M = {}

-- Include the core modules directly (these are stateless utility modules)
local ResourceShareTax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
local UnitSharing = VFS.Include("luarules/gadgets/team_transfer/unit_sharing.lua")
local MODOPTION_KEYS = VFS.Include("luarules/gadgets/team_transfer/sharing_modoption_keys.lua")

-- Unsynced sharing mode check helper
local function loadSharingModes()
	local modOpts = Spring.GetModOptions()
	local sharingModes = modOpts.sharingoptions and VFS.LoadFile("gamedata/sharingoptions.json")
	return sharingModes and Spring.Utilities.json.decode(sharingModes) or {}
end

local function isSharingOption(modoptionKey)
	if not modoptionKey then return false end
	local modOpts = Spring.GetModOptions()
	local selectedMode = modOpts.selectedsharingmode
	if not selectedMode then return false end
	
	local sharingModes = loadSharingModes()
	local mode = sharingModes[selectedMode]
	return mode and mode.options and mode.options[modoptionKey] ~= nil
end

-- Resource Share Tax helpers
M.ResourceShareTax = {
	computeTransfer = function(...)
		return ResourceShareTax.computeTransfer(...)
	end
}

-- Unit Sharing helpers that work in unsynced context
M.UnitSharing = {
	getUnitSharingMode = function()
		return UnitSharing.getUnitSharingMode()
	end,
	countUnshareable = function(...)
		return UnitSharing.countUnshareable(...)
	end,
	shouldShowShareButton = function(...)
		return UnitSharing.shouldShowShareButton(...)
	end,
	blockMessage = function(...)
		return UnitSharing.blockMessage(...)
	end,
	isUnitShareAllowedByMode = function(...)
		return UnitSharing.isUnitShareAllowedByMode(...)
	end,
}

-- Direct access helpers (for backward compatibility)
M.getUnitSharingMode = M.UnitSharing.getUnitSharingMode
M.countUnshareable = M.UnitSharing.countUnshareable
M.shouldShowShareButton = M.UnitSharing.shouldShowShareButton
M.blockMessage = M.UnitSharing.blockMessage
M.isUnitShareAllowedByMode = M.UnitSharing.isUnitShareAllowedByMode
M.computeTransfer = M.ResourceShareTax.computeTransfer

---Handle share button click with full validation and unit sharing
---Performs complete workflow: validates sharing mode, checks selected units,
---shows appropriate error messages, and executes the share if allowed
---@param targetTeamID number The team ID to share units to
---@return boolean success Whether the share was executed successfully
---@see TeamTransferAPI.handleShareButtonClick @ luaui/types/team_transfer.lua:101
M.handleShareButtonClick = function(targetTeamID)
	local unitSharingMode = UnitSharing.getUnitSharingMode()
	if unitSharingMode == "disabled" then
		Spring.Echo(UnitSharing.blockMessage(nil, unitSharingMode))
		return false
	end
	
	local selected = Spring.GetSelectedUnits()
	local shareable, unshareable, total = UnitSharing.countUnshareable(selected, unitSharingMode)
	if total > 0 and shareable == 0 then
		Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
		return false
	end
	
	if unshareable and unshareable > 0 then
		Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
	end
	
	Spring.ShareResources(targetTeamID, "units")
	Spring.PlaySoundFile("beep4", 1, 'ui')
	return true
end

---Validate whether a share command should proceed based on sharing mode
---Checks current sharing mode restrictions and selected units,
---displays appropriate error messages for invalid attempts
---@return boolean valid Whether the command should be allowed to proceed
---@see TeamTransferAPI.validateShareCommand @ luaui/types/team_transfer.lua:103
M.validateShareCommand = function()
	local unitSharingMode = UnitSharing.getUnitSharingMode()
	if unitSharingMode == "disabled" then
		Spring.Echo(UnitSharing.blockMessage(nil, unitSharingMode))
		return false
	end
	
	if unitSharingMode == "t2cons" then
		local selected = Spring.GetSelectedUnits()
		local shareable, unshareable, total = UnitSharing.countUnshareable(selected, unitSharingMode)
		if total > 0 and shareable == 0 then
			Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
			return false
		end
		if unshareable > 0 then
			Spring.Echo(UnitSharing.blockMessage(unshareable, unitSharingMode))
		end
	end
	
	return true
end

-- Expose utilities
M.IsSharingOption = isSharingOption
M.MODOPTION_KEYS = MODOPTION_KEYS

---@return TeamTransferAPI
return M
