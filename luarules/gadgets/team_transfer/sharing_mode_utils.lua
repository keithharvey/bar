-- Sharing Mode Utilities
-- Provides functions for gadgets to check if they should run based on the selected sharing mode

local sharingModeUtils = {}

-- Cached sharing modes configuration
local cachedSharingModes = nil

-- Load sharing modes configuration (with caching)
local function loadSharingModes()
	if cachedSharingModes then
		return cachedSharingModes
	end
	
	if VFS.FileExists("gamedata/sharingoptions.json") then
		local jsonStr = VFS.LoadFile("gamedata/sharingoptions.json")
		if jsonStr then
			local modes = {}
			for key, optionsBlock in jsonStr:gmatch('"key"%s*:%s*"([^"]+)"%s*,%s*"options"%s*:%s*{(.-)}') do
				modes[key] = {}
				for optKey in optionsBlock:gmatch('"([^"_][^"]*)"%s*:') do
					modes[key][optKey] = true
				end
			end
			cachedSharingModes = modes
			return modes
		end
	end
	
	cachedSharingModes = {}
	return cachedSharingModes
end

-- Check if a gadget should run based on whether its modoption is whitelisted by the current mode
function sharingModeUtils.shouldGadgetRun(modoptionKey)
	local selectedMode = Spring.GetModOptions()._sharing_mode_selected or ""
	if selectedMode == "" then
		return true -- No mode selected, run normally
	end
	
	local sharingModes = loadSharingModes()
	local modeConfig = sharingModes[selectedMode]
	if not modeConfig then
		return true -- Unknown mode, run normally
	end
	
	-- Check if this specific modoption is whitelisted by the mode
	return modeConfig[modoptionKey] ~= nil
end

-- Check if an option key is enabled by the current sharing mode
function sharingModeUtils.isOptionEnabledInCurrentMode(modoptionKey)
	local selectedMode = Spring.GetModOptions()._sharing_mode_selected or ""
	if selectedMode == "" then
		return true
	end

	local sharingModes = loadSharingModes()
	local modeConfig = sharingModes[selectedMode]
	if not modeConfig then
		return true
	end

	return modeConfig[modoptionKey] ~= nil
end

return sharingModeUtils
