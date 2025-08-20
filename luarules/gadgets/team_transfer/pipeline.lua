local API = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")

local Pipeline = {}

local function normalizeResourceName(resourceType)
	if resourceType == 'm' then return 'metal' end
	if resourceType == 'e' then return 'energy' end
	return resourceType
end

function Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	local handlers = API.GetPipeline().onAllowResourceTransfer
	local resourceName = normalizeResourceName(resourceType)
	for i = 1, #handlers do
		local res = handlers[i](senderTeamId, receiverTeamId, resourceName, amount)
		if res ~= nil then
			return res
		end
	end
	return true
end

function Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	local handlers = API.GetPipeline().onAllowUnitTransfer
	for i = 1, #handlers do
		local res = handlers[i](unitID, unitDefID, fromTeamID, toTeamID, capture)
		if res ~= nil then
			return res
		end
	end
	return true
end

function Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	local handlers = API.GetPipeline().onAllowCommand
	for i = 1, #handlers do
		local res = handlers[i](unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
		if res ~= nil then
			return res
		end
	end
	return true
end

return Pipeline
