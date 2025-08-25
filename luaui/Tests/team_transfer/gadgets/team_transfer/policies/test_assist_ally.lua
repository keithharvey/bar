function setup()
	_G.VFS = _G.VFS or {}
	_G.GG = _G.GG or {}
	_G.Spring = _G.Spring or {}
	_G.gadgetHandler = _G.gadgetHandler or {}
	
	gadgetHandler.IsSyncedCode = function() return true end
	
	Spring.GetModOptions = function()
		return { game_assist_ally = "enabled" }
	end
	
	GG.TeamTransfer = {
		MODOPTION_KEYS = {
			ALLY_ASSIST_MODE = "game_assist_ally"
		},
		IsSharingOption = function(key)
			local modOpts = Spring.GetModOptions()
			local value = modOpts[key]
			return value ~= nil, value
		end,
		RegisterPolicy = function(fn)
			local mockPolicy = {
				ForAlliedCommands = {
					WhenGuard = { Deny = function() end },
					WhenRepair = { Deny = function() end }
				}
			}
			fn(mockPolicy)
		end
	}
end

function cleanup()
	_G.VFS = nil
	_G.GG = nil
	_G.Spring = nil
	_G.gadgetHandler = nil
end

function test()
	local enabled, assistMode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
	assert(enabled, "Should detect enabled ally assist mode")
	assert(assistMode == "enabled", "Should return correct assist mode value")
	
	Spring.GetModOptions = function()
		return { game_assist_ally = "disabled" }
	end
	
	local disabledEnabled, disabledMode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
	assert(disabledEnabled, "Should detect disabled ally assist mode as present option")
	assert(disabledMode == "disabled", "Should return disabled mode value")
	
	Spring.GetModOptions = function()
		return {}
	end
	
	local notEnabled, notMode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
	assert(not notEnabled, "Should not detect missing ally assist mode")
	assert(notMode == nil, "Should return nil for missing mode")
	
	local policyRegistered = false
	GG.TeamTransfer.RegisterPolicy = function(fn)
		policyRegistered = true
		local mockPolicy = {
			ForAlliedCommands = {
				WhenGuard = { Deny = function() end },
				WhenRepair = { Deny = function() end }
			}
		}
		fn(mockPolicy)
	end
	
	Spring.GetModOptions = function()
		return { game_assist_ally = "enabled" }
	end
	
	local enabled, assistMode = GG.TeamTransfer.IsSharingOption(GG.TeamTransfer.MODOPTION_KEYS.ALLY_ASSIST_MODE)
	if enabled and assistMode ~= "disabled" then
		GG.TeamTransfer.RegisterPolicy(function(policy)	
			policy.ForAlliedCommands.WhenGuard.Deny()
			policy.ForAlliedCommands.WhenRepair.Deny()
		end)
	end
	
	assert(policyRegistered, "Should register policy when ally assist is enabled")
end
