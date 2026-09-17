
function skip()
	return Spring.GetGameFrame() <= 1 or Spring.GetModOptions().mex_splitting ~= "map_assigned"
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local myTeamID = Spring.GetLocalTeamID()
	local mexDefID = UnitDefNames.armmex.id
	local builderName = "armck"

	local spots = SyncedRun(function(locals)
		local state = gadgetHandler.GG.__moduleState.economy ---@type EconomyState
		assert(state and state.mexRegions and state.mexDeal, "economy has not dealt the regions")
		local Shared = VFS.Include("modules/economy/lib/mex_regions/shared.lua") ---@type MexRegionsShared
		local byKey = Shared.HolderBySpot(Spring, Spring.GetTeamList())
		local mine, theirs
		for _, spot in ipairs(gadgetHandler.GG.resource_spot_finder.metalSpotsList) do
			local owner = byKey[Shared.SpotKey(spot.x, spot.z)]
			if owner == locals.myTeamID and mine == nil then
				mine = { x = spot.x, z = spot.z }
			elseif owner ~= nil and owner ~= locals.myTeamID and theirs == nil then
				theirs = { x = spot.x, z = spot.z }
			end
		end
		return { mine = mine, theirs = theirs }
	end)
	assert(spots.mine, "no metal spot inside a region my team holds")
	assert(spots.theirs, "no metal spot inside a region another team holds")

	local function orderMexAt(spot)
		local x, z, builder, defID, teamID = spot.x, spot.z, builderName, mexDefID, myTeamID
		local queued = SyncedRun(function(locals)
			local y = Spring.GetGroundHeight(locals.x, locals.z)
			local builderID = Spring.CreateUnit(locals.builder, locals.x + 120, y, locals.z + 120, 0, locals.teamID)
			assert(builderID, "failed to create " .. locals.builder)
			Spring.GiveOrderToUnit(builderID, -locals.defID, { locals.x, y, locals.z, 0 }, 0)
			return Spring.GetUnitCommandCount(builderID)
		end)
		return queued
	end

	assertEqual(orderMexAt(spots.theirs), 0, "a mex order on a spot another team holds should be refused")
	assertEqual(orderMexAt(spots.mine), 1, "a mex order on a spot my team holds should queue")
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
