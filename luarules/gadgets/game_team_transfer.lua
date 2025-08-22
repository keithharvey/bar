local gadget = gadget

function gadget:GetInfo()
	return {
		name    = 'Team Transfer Framework (Loader)',
		desc    = 'Loads TeamTransfer API and policies, exposes via GG.TeamTransfer',
		author  = 'Devin',
		layer   = -1001,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

function gadget:Initialize()
	---@type TeamTransferAPI
	GG.TeamTransfer = {
		RegisterPolicy = TeamTransfer.RegisterPolicy,
		PolicyType = TeamTransfer.PolicyType,
		UnitSharing = TeamTransfer.UnitSharing,
		ResourceShareTax = TeamTransfer.ResourceShareTax,
		Predicates = TeamTransfer.Predicates,
		MODOPTION_KEYS = TeamTransfer.MODOPTION_KEYS,
		IsSharingOption = TeamTransfer.IsSharingOption,
		Units = TeamTransfer.Units,
		getUnitSharingMode = TeamTransfer.UnitSharing.getUnitSharingMode,
		isT2ConstructorDef = TeamTransfer.UnitSharing.isT2ConstructorDef,
		countUnshareable = TeamTransfer.UnitSharing.countUnshareable,
		shouldShowShareButton = TeamTransfer.UnitSharing.shouldShowShareButton,
		blockMessage = TeamTransfer.UnitSharing.blockMessage,
		computeTransfer = TeamTransfer.ResourceShareTax.computeTransfer,
	}
	
	local policyFiles = VFS.DirList("luarules/gadgets/team_transfer/policies/", "*.lua")
	for _, policyFile in ipairs(policyFiles) do
		VFS.Include(policyFile)
	end
end
