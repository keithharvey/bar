function setup()
	_G.VFS = _G.VFS or {}
	_G.Spring = _G.Spring or {}
	
	Spring.GetModOptions = function()
		return { _sharing_mode_selected = "test_mode" }
	end
	
	VFS.FileExists = function(path)
		return path == "gamedata/sharingoptions.json"
	end
	
	VFS.LoadFile = function(path)
		if path == "gamedata/sharingoptions.json" then
			return '"key": "test_mode", "options": {"option1": true, "option3": true}'
		end
		return nil
	end
	
	VFS.Include = function(path)
		if path:match("sharing_mode_utils") then
			return require_sharing_mode_utils_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
	_G.Spring = nil
end

function require_sharing_mode_utils_module()
	local sharingModeUtils = {}
	local cachedSharingModes = nil
	
	function sharingModeUtils.resetCache()
		cachedSharingModes = nil
	end

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

	function sharingModeUtils.shouldGadgetRun(modoptionKey)
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
end

function test()
	local sharingModeUtils = VFS.Include("luarules/gadgets/team_transfer/sharing_mode_utils.lua")
	
	assert(sharingModeUtils.shouldGadgetRun("option1"), "Should allow gadget to run for whitelisted option")
	assert(not sharingModeUtils.shouldGadgetRun("option2"), "Should not allow gadget to run for non-whitelisted option")
	assert(sharingModeUtils.shouldGadgetRun("option3"), "Should allow gadget to run for another whitelisted option")
	assert(not sharingModeUtils.shouldGadgetRun("unknown_option"), "Should not allow gadget to run for unknown option")
	
	assert(sharingModeUtils.isOptionEnabledInCurrentMode("option1"), "Should enable whitelisted option")
	assert(not sharingModeUtils.isOptionEnabledInCurrentMode("option2"), "Should not enable non-whitelisted option")
	assert(sharingModeUtils.isOptionEnabledInCurrentMode("option3"), "Should enable another whitelisted option")
	assert(not sharingModeUtils.isOptionEnabledInCurrentMode("unknown_option"), "Should not enable unknown option")
	
	Spring.GetModOptions = function()
		return {}
	end
	
	assert(sharingModeUtils.shouldGadgetRun("any_option"), "Should allow gadget to run when no mode selected")
	assert(sharingModeUtils.isOptionEnabledInCurrentMode("any_option"), "Should enable any option when no mode selected")
	
	Spring.GetModOptions = function()
		return { _sharing_mode_selected = "unknown_mode" }
	end
	
	assert(sharingModeUtils.shouldGadgetRun("any_option"), "Should allow gadget to run for unknown mode")
	assert(sharingModeUtils.isOptionEnabledInCurrentMode("any_option"), "Should enable any option for unknown mode")
	
	VFS.FileExists = function(path)
		return false
	end
	
	sharingModeUtils.resetCache() -- Reset cache
	
	Spring.GetModOptions = function()
		return { _sharing_mode_selected = "test_mode" }
	end
	
	assert(sharingModeUtils.shouldGadgetRun("any_option"), "Should allow gadget to run when config file missing")
	assert(sharingModeUtils.isOptionEnabledInCurrentMode("any_option"), "Should enable any option when config file missing")
end
