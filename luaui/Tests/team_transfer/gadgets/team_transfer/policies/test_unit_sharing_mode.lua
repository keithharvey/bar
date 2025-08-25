function setup()
	_G.GG = _G.GG or {}
	_G.UnitDefs = _G.UnitDefs or {}
	
	UnitDefs[1] = {
		isFactory = false,
		buildOptions = {"unit1", "unit2"},
		customParams = { techlevel = "2" }
	}
	
	UnitDefs[2] = {
		isFactory = true,
		buildOptions = {"unit1"},
		customParams = { techlevel = "1" }
	}
	
	UnitDefs[3] = {
		isFactory = false,
		buildOptions = {},
		customParams = { unitgroup = "energy" }
	}
	
	GG.TeamTransfer = {
		UnitSharing = {
			isT2ConstructorDef = function(unitDef)
				return (not unitDef.isFactory)
					and #(unitDef.buildOptions or {}) > 0
					and unitDef.customParams and unitDef.customParams.techlevel == "2"
			end,
			isEconomicUnitDef = function(unitDef)
				if not unitDef then return false end
				if unitDef.canAssist or unitDef.isFactory then
					return true
				end
				if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
					return true
				end
				return false
			end
		},
		MODOPTION_KEYS = {
			UNIT_SHARING_MODE = "unit_sharing_mode"
		},
		IsSharingOption = function(key)
			return true, "t2cons"
		end,
		RegisterPolicy = function(fn)
			local mockPolicy = {
				ForAlliedUnitTransfers = {
					Deny = function() 
						_G.unitSharingDenied = true
					end,
					Use = function(handler)
						_G.unitSharingHandler = handler
					end
				}
			}
			fn(mockPolicy)
		end
	}
end

function cleanup()
	_G.GG = nil
	_G.UnitDefs = nil
	_G.unitSharingDenied = nil
	_G.unitSharingHandler = nil
end

function test()
	local sharing = GG.TeamTransfer.UnitSharing
	
	assert(sharing.isT2ConstructorDef(UnitDefs[1]), "Should identify T2 constructor")
	assert(not sharing.isT2ConstructorDef(UnitDefs[2]), "Should not identify factory as T2 constructor")
	assert(not sharing.isT2ConstructorDef(UnitDefs[3]), "Should not identify economic unit as T2 constructor")
	
	assert(sharing.isEconomicUnitDef(UnitDefs[2]), "Should identify factory as economic")
	assert(sharing.isEconomicUnitDef(UnitDefs[3]), "Should identify energy unit as economic")
	assert(not sharing.isEconomicUnitDef(UnitDefs[1]), "Should not identify T2 constructor as economic")
	
	GG.TeamTransfer.IsSharingOption = function(key)
		return true, "disabled"
	end
	
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForAlliedUnitTransfers.Deny()
	end)
	
	assert(_G.unitSharingDenied, "Should deny all unit transfers when disabled")
	
	_G.unitSharingDenied = nil
	_G.unitSharingHandler = nil
	
	GG.TeamTransfer.IsSharingOption = function(key)
		return true, "t2cons"
	end
	
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			if not sharing.isT2ConstructorDef(UnitDefs[ctx.unitDefID]) then
				return { deny = true }
			end
			return { allow = true }
		end)
	end)
	
	assert(_G.unitSharingHandler ~= nil, "Should register handler for t2cons mode")
	
	local t2ConsCtx = { unitDefID = 1 }
	local t2ConsResult = _G.unitSharingHandler(t2ConsCtx)
	assert(t2ConsResult.allow == true, "Should allow T2 constructor in t2cons mode")
	
	local factoryCtx = { unitDefID = 2 }
	local factoryResult = _G.unitSharingHandler(factoryCtx)
	assert(factoryResult.deny == true, "Should deny factory in t2cons mode")
	
	_G.unitSharingHandler = nil
	
	GG.TeamTransfer.IsSharingOption = function(key)
		return true, "combat"
	end
	
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			if sharing.isEconomicUnitDef(UnitDefs[ctx.unitDefID]) then
				return { deny = true }
			end
			return { allow = true }
		end)
	end)
	
	local economicCtx = { unitDefID = 2 }
	local economicResult = _G.unitSharingHandler(economicCtx)
	assert(economicResult.deny == true, "Should deny economic unit in combat mode")
	
	_G.unitSharingHandler = nil
	
	GG.TeamTransfer.IsSharingOption = function(key)
		return true, "combat_t2cons"
	end
	
	GG.TeamTransfer.RegisterPolicy(function(policy)
		policy.ForAlliedUnitTransfers.Use(function(ctx)
			local unitDef = UnitDefs[ctx.unitDefID]
			if sharing.isEconomicUnitDef(unitDef) and not sharing.isT2ConstructorDef(unitDef) then
				return { deny = true }
			end
			return { allow = true }
		end)
	end)
	
	local t2ConsInCombatCtx = { unitDefID = 1 }
	local t2ConsInCombatResult = _G.unitSharingHandler(t2ConsInCombatCtx)
	assert(t2ConsInCombatResult.allow == true, "Should allow T2 constructor in combat_t2cons mode")
	
	local factoryInCombatCtx = { unitDefID = 2 }
	local factoryInCombatResult = _G.unitSharingHandler(factoryInCombatCtx)
	assert(factoryInCombatResult.deny == true, "Should deny factory in combat_t2cons mode")
end
