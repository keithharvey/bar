local TeamTransfer = VFS.Include("luarules/gadgets/team_transfer/api_gadgets.lua")
local Resources = VFS.Include("luarules/gadgets/team_transfer/resources.lua")
local State = VFS.Include("luarules/gadgets/team_transfer/state.lua")

local PolicyType = TeamTransfer.PolicyType

local Pipeline = {}

local function isNonPlayerTeam(teamID)
	if teamID == Spring.GetGaiaTeamID() then
		return true
	end
	local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID, false)
	if isAiTeam then
		return true
	end
	if Spring.GetTeamLuaAI(teamID) ~= nil then
		return true
	end
	return false
end

local function evaluatePolicies(policyType, ctx)
	local entries = TeamTransfer.GetPolicies()[policyType]
	for i = 1, #entries do
		local entry = entries[i]
		local preds = entry.predicates
		local ok = true
		for j = 1, #preds do
			if not preds[j](ctx) then
				ok = false
				break
			end
		end
		if ok then
			local res = entry.handler(ctx)
			if res ~= nil then
				return res
			end
		end
	end

	local legacy = TeamTransfer.GetPipeline()
	if policyType == PolicyType.ResourceTransfer then
		local hs = legacy.onAllowResourceTransfer
		for i = 1, #hs do
			local r = hs[i](ctx.senderTeamId, ctx.receiverTeamId, ctx.resource, ctx.amount)
			if r ~= nil then return r end
		end
		return true
	elseif policyType == PolicyType.UnitTransfer then
		local hs = legacy.onAllowUnitTransfer
		for i = 1, #hs do
			local r = hs[i](ctx.unitID, ctx.unitDefID, ctx.fromTeamID, ctx.toTeamID, ctx.capture)
			if r ~= nil then return r end
		end
		return true
	elseif policyType == PolicyType.Command then
		local hs = legacy.onAllowCommand
		for i = 1, #hs do
			local r = hs[i](ctx.unitID, ctx.unitDefID, ctx.unitTeam, ctx.cmdID, ctx.cmdParams, ctx.cmdOptions, ctx.cmdTag, ctx.synced)
			if r ~= nil then return r end
		end
		return true
	end
end

function Pipeline.RunAllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	local resourceName = Resources.NormalizeResourceName(resourceType)
	local maxShare = 0
	local receiverCur = 0
	if resourceName == 'metal' or resourceName == 'energy' then
		maxShare, receiverCur = Resources.ComputeMaxShare(receiverTeamId, resourceName)
	end
	local clampedAmount = math.min(math.max(amount, 0), maxShare)
	local ctx = {
		type = PolicyType.ResourceTransfer,
		senderTeamId = senderTeamId,
		receiverTeamId = receiverTeamId,
		resource = resourceName,
		amount = amount,
		amountClamped = clampedAmount,
		maxShare = maxShare,
		receiverCur = receiverCur,
		cumulativeMetal = State.GetCumulativeMetalSent(senderTeamId),
		areAlliedTeams = Spring.AreTeamsAllied(senderTeamId, receiverTeamId),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		senderIsNonPlayer = isNonPlayerTeam(senderTeamId),
		receiverIsNonPlayer = isNonPlayerTeam(receiverTeamId),
	}

	local res = evaluatePolicies(PolicyType.ResourceTransfer, ctx)
	if type(res) == "table" then
		if res.applyTransfer then
			local sent = res.applyTransfer.sent or 0
			local received = res.applyTransfer.received or 0
			Spring.SetTeamResource(receiverTeamId, resourceName, receiverCur + received)
			local sCur = select(1, Spring.GetTeamResources(senderTeamId, resourceName))
			Spring.SetTeamResource(senderTeamId, resourceName, sCur - sent)
			if resourceName == 'metal' and res.applyTransfer.updateCumulativeMetal then
				local newCum = State.AddCumulativeMetalSent(senderTeamId, sent)
				Spring.SetTeamRulesParam(senderTeamId, "metal_share_cumulative_sent", newCum)
			end
			if res.expose then
				if res.expose.threshold ~= nil then
					Spring.SetTeamRulesParam(senderTeamId, "metal_share_threshold", res.expose.threshold)
				end
				if res.expose.taxRate ~= nil then
					Spring.SetTeamRulesParam(senderTeamId, "resource_share_tax_rate", res.expose.taxRate)
				end
			end
			return false
		end
		if res.allow ~= nil then
			return res.allow
		end
		if res.deny ~= nil then
			return not res.deny
		end
	elseif type(res) == "boolean" then
		return res
	end

	return true
end

local function computeTakeBypass(fromTeamID, toTeamID)
	if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID)
			if active and not spectator and teamID == fromTeamID then
				return false
			end
		end
		return true
	end
	return false
end

function Pipeline.RunAllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if capture then
		return true
	end
	local ctx = {
		type = PolicyType.UnitTransfer,
		unitID = unitID,
		unitDefID = unitDefID,
		fromTeamID = fromTeamID,
		toTeamID = toTeamID,
		capture = capture,
		takeBypassAllowed = computeTakeBypass(fromTeamID, toTeamID),
		areAlliedTeams = Spring.AreTeamsAllied(fromTeamID, toTeamID),
		isCheatingEnabled = Spring.IsCheatingEnabled(),
		fromIsNonPlayer = isNonPlayerTeam(fromTeamID),
		toIsNonPlayer = isNonPlayerTeam(toTeamID),
	}

	local res = evaluatePolicies(PolicyType.UnitTransfer, ctx)
	if type(res) == "table" then
		if res.allow ~= nil then return res.allow end
		if res.deny ~= nil then return not res.deny end
	elseif type(res) == "boolean" then
		return res
	end
	return true
end

local function isComplete(u)
	local _,_,_,_,buildProgress=Spring.GetUnitHealth(u)
	return (buildProgress and buildProgress>=1) or false
end

function Pipeline.RunAllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	local targetID = cmdParams and cmdParams[1] or nil
	local targetTeam = targetID and Spring.GetUnitTeam(targetID) or nil
	local targetUnitDefID = targetID and Spring.GetUnitDefID(targetID) or nil
	local targetUnitDef = targetUnitDefID and UnitDefs[targetUnitDefID] or nil
	local targetAllied = (targetTeam ~= nil) and Spring.AreTeamsAllied(unitTeam, targetTeam) and (unitTeam ~= targetTeam) or false

	local ctx = {
		type = PolicyType.Command,
		unitID = unitID,
		unitDefID = unitDefID,
		unitTeam = unitTeam,
		cmdID = cmdID,
		cmdParams = cmdParams,
		cmdOptions = cmdOptions,
		cmdTag = cmdTag,
		synced = synced,
		targetID = targetID,
		targetTeam = targetTeam,
		targetUnitDef = targetUnitDef,
		targetAllied = targetAllied,
		targetIsComplete = targetID and isComplete(targetID) or true,
	}

	local res = evaluatePolicies(PolicyType.Command, ctx)
	if type(res) == "table" then
		if res.allow ~= nil then return res.allow end
		if res.deny ~= nil then return not res.deny end
	elseif type(res) == "boolean" then
		return res
	end
	return true
end

return Pipeline
