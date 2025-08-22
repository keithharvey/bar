local PolicyManager = {}

local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

local policyConfigs = {}

function PolicyManager.registerConfig(name, config)
	policyConfigs[name] = config
end

function PolicyManager.applyPolicies()
	for name, config in pairs(policyConfigs) do
		if config.enabled ~= false then
			TeamTransfer.RegisterPolicy(config.registrar)
		end
	end
end

function PolicyManager.getConfig(name)
	return policyConfigs[name]
end

function PolicyManager.listConfigs()
	return policyConfigs
end

return PolicyManager
