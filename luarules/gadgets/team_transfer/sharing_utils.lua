-- Shared utilities for resource sharing calculations
-- Used by both gadget-side (pipeline) and widget-side (api_widgets) code

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local SharingUtils = {}

-- Cache for loaded sharing modes
local loadedSharingModes = nil

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
	if not teamID or teamID < 0 then
		Spring.Log("TeamTransfer", LOG.ERROR, "[SHARING_UTILS] GetTeamResourcesData called with invalid teamID: " .. tostring(teamID))
		return {
			metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
			energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
		}
	end

	-- Validate SharedEnums.ResourceType exists
	if not SharedEnums or not SharedEnums.ResourceType then
		Spring.Log("TeamTransfer", LOG.ERROR, "[SHARING_UTILS] SharedEnums.ResourceType is nil!")
		return {
			metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
			energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
		}
	end

	local metalResourceType = SharedEnums.ResourceType.METAL or "metal"
	local energyResourceType = SharedEnums.ResourceType.ENERGY or "energy"



	local sMCur, sMStor, sMPull, sMInc, sMExp, sMShare
	local sECur, sEStor, sEPull, sEInc, sEExp, sEShare

	-- Safely call Spring.GetTeamResources with error handling
	local success, errorMsg = pcall(function()
		sMCur, sMStor, sMPull, sMInc, sMExp, sMShare = Spring.GetTeamResources(teamID, metalResourceType)
		sECur, sEStor, sEPull, sEInc, sEExp, sEShare = Spring.GetTeamResources(teamID, energyResourceType)
	end)

	if not success then
		Spring.Log("TeamTransfer", LOG.ERROR, "[SHARING_UTILS] Spring.GetTeamResources failed: " .. tostring(errorMsg))
		Spring.Log("TeamTransfer", LOG.ERROR, "[SHARING_UTILS] teamID: " .. tostring(teamID) .. ", metalResourceType: " .. tostring(metalResourceType))
		return {
			metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
			energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
		}
	end
	
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

-- Load sharing modes from JSON file
local function loadSharingModes()
	if loadedSharingModes then
		return loadedSharingModes
	end

	local modes = {}

	if VFS.FileExists("gamedata/sharingoptions.json") then
		local jsonStr = VFS.LoadFile("gamedata/sharingoptions.json")
		if jsonStr then
			-- Parse JSON to extract individual option keys
			for modeKey, optionsBlock in jsonStr:gmatch('"([^"]+)":%s*{([^}]*)}') do
				modes[modeKey] = {}
				for optionKey in optionsBlock:gmatch('"([^"]+)":') do
					modes[modeKey][optionKey] = true
				end
			end
		end
	end

	loadedSharingModes = modes
	return modes
end

function SharingUtils.IsSharingOption(modoptionKey)
	if not modoptionKey then
		return false, nil
	end

	local modOptions = Spring.GetModOptions()
	local sharingMode = modOptions.sharing_mode or ""

	if sharingMode == "" then
		-- No sharing mode selected, check option directly
		local value = modOptions[modoptionKey]
		local enabled = value and value ~= "disabled" and value ~= "0" and value ~= 0
		return enabled, value
	end

	-- Check if option is enabled in the current sharing mode
	local sharingModes = loadSharingModes()
	local modeConfig = sharingModes[sharingMode]

	if modeConfig and modeConfig[modoptionKey] then
		local value = modOptions[modoptionKey]
		return true, value
	end

	return false, nil
end

return SharingUtils
