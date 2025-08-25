function setup()
	_G.VFS = _G.VFS or {}
	_G.Spring = _G.Spring or {}
	
	Spring.GetTeamResources = function(teamID, resourceName)
		if resourceName == "metal" then
			return 500, 1000, 0, 0, 0, 1.0
		elseif resourceName == "energy" then
			return 800, 1200, 0, 0, 0, 0.8
		end
		return 0, 0, 0, 0, 0, 0
	end
	
	VFS.Include = function(path)
		if path:match("resources") then
			return require_resources_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
	_G.Spring = nil
end

function require_resources_module()
	local M = {}

	function M.NormalizeResourceName(resourceType)
		if resourceType == 'm' then return 'metal' end
		if resourceType == 'e' then return 'energy' end
		return resourceType
	end

	function M.ComputeMaxShare(receiverTeamId, resourceName)
		local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
		local maxShare = rStor * rShare - rCur
		if maxShare < 0 then maxShare = 0 end
		return maxShare, rCur
	end

	return M
end

function test()
	local Resources = VFS.Include("luarules/gadgets/team_transfer/resources.lua")
	
	assert(Resources.NormalizeResourceName("m") == "metal", "Should normalize 'm' to 'metal'")
	assert(Resources.NormalizeResourceName("e") == "energy", "Should normalize 'e' to 'energy'")
	assert(Resources.NormalizeResourceName("metal") == "metal", "Should keep 'metal' as 'metal'")
	assert(Resources.NormalizeResourceName("energy") == "energy", "Should keep 'energy' as 'energy'")
	assert(Resources.NormalizeResourceName("unknown") == "unknown", "Should keep unknown resource names unchanged")
	
	local metalMaxShare, metalCurrent = Resources.ComputeMaxShare(1, "metal")
	assert(metalMaxShare == 500, "Should compute correct max share for metal (1000 * 1.0 - 500)")
	assert(metalCurrent == 500, "Should return current metal amount")
	
	local energyMaxShare, energyCurrent = Resources.ComputeMaxShare(1, "energy")
	assert(energyMaxShare == 160, "Should compute correct max share for energy (1200 * 0.8 - 800)")
	assert(energyCurrent == 800, "Should return current energy amount")
	
	Spring.GetTeamResources = function(teamID, resourceName)
		if resourceName == "metal" then
			return 1200, 1000, 0, 0, 0, 1.0
		end
		return 0, 0, 0, 0, 0, 0
	end
	
	local overflowMaxShare, overflowCurrent = Resources.ComputeMaxShare(1, "metal")
	assert(overflowMaxShare == 0, "Should return 0 max share when current exceeds storage * share")
	assert(overflowCurrent == 1200, "Should return current amount even when overflowing")
	
	Spring.GetTeamResources = function(teamID, resourceName)
		return 0, 1000, 0, 0, 0, 0.5
	end
	
	local halfShareMax, halfShareCurrent = Resources.ComputeMaxShare(1, "metal")
	assert(halfShareMax == 500, "Should compute correct max share with 0.5 share factor (1000 * 0.5 - 0)")
	assert(halfShareCurrent == 0, "Should return 0 current amount")
end
