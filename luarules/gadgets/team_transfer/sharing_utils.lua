-- Shared utilities for resource sharing calculations
-- Used by both gadget-side (pipeline) and widget-side (api_widgets) code

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local SharingUtils = {}

-- Compute maximum shareable amount for a resource type
-- Returns: maxShare, receiverCurrent
function SharingUtils.ComputeMaxShare(receiverTeamID, resourceName)
	if not receiverTeamID or not resourceName then
		return 0, 0
	end
	
	local current, storage, _, _, _, shareSlider = Spring.GetTeamResources(receiverTeamID, resourceName)
	if not current or not storage or not shareSlider then
		return 0, 0
	end
	
	local maxShare = math.max(0, (storage * shareSlider) - current)
	return maxShare, current
end

-- Get complete resource data for a team (both metal and energy)
function SharingUtils.GetTeamResourcesData(teamID)
	local sMCur, sMStor, sMPull, sMInc, sMExp, sMShare = Spring.GetTeamResources(teamID, SharedEnums.ResourceType.METAL)
	local sECur, sEStor, sEPull, sEInc, sEExp, sEShare = Spring.GetTeamResources(teamID, SharedEnums.ResourceType.ENERGY)
	
	---@type TeamResourcesData
	return {
		metal = {
			current = sMCur or 0,
			storage = sMStor or 0,
			pull = sMPull or 0,
			income = sMInc or 0,
			expense = sMExp or 0,
			shareSlider = sMShare or 0
		},
		energy = {
			current = sECur or 0,
			storage = sEStor or 0,
			pull = sEPull or 0,
			income = sEInc or 0,
			expense = sEExp or 0,
			shareSlider = sEShare or 0
		}
	}
end

-- Check if a mod option should enable a gadget/policy
function SharingUtils.shouldGadgetRun(modOptionKey)
	local modOptions = Spring.GetModOptions()
	if not modOptions then
		return false
	end
	
	local value = modOptions[modOptionKey]
	return value and value ~= "disabled" and value ~= "0" and value ~= 0
end

return SharingUtils
