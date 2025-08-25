function setup()
	_G.VFS = _G.VFS or {}
	
	VFS.Include = function(path)
		if path:match("state") then
			return require_state_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
end

function require_state_module()
	local M = {}
	local cumulativeMetalSent = {}

	function M.GetCumulativeMetalSent(teamID)
		return cumulativeMetalSent[teamID] or 0
	end

	function M.AddCumulativeMetalSent(teamID, amount)
		local cur = cumulativeMetalSent[teamID] or 0
		local newVal = cur + (amount or 0)
		cumulativeMetalSent[teamID] = newVal
		return newVal
	end

	return M
end

function test()
	local State = VFS.Include("luarules/gadgets/team_transfer/state.lua")
	
	assert(State.GetCumulativeMetalSent(1) == 0, "Should return 0 for new team")
	assert(State.GetCumulativeMetalSent(2) == 0, "Should return 0 for another new team")
	
	local newTotal1 = State.AddCumulativeMetalSent(1, 100)
	assert(newTotal1 == 100, "Should add amount to cumulative total")
	assert(State.GetCumulativeMetalSent(1) == 100, "Should persist cumulative total")
	
	local newTotal2 = State.AddCumulativeMetalSent(1, 50)
	assert(newTotal2 == 150, "Should add to existing cumulative total")
	assert(State.GetCumulativeMetalSent(1) == 150, "Should persist updated cumulative total")
	
	local newTotal3 = State.AddCumulativeMetalSent(2, 200)
	assert(newTotal3 == 200, "Should track separate cumulative totals per team")
	assert(State.GetCumulativeMetalSent(2) == 200, "Should persist separate team totals")
	assert(State.GetCumulativeMetalSent(1) == 150, "Should not affect other team totals")
	
	local newTotal4 = State.AddCumulativeMetalSent(1, nil)
	assert(newTotal4 == 150, "Should handle nil amount as 0")
	assert(State.GetCumulativeMetalSent(1) == 150, "Should not change total with nil amount")
	
	local newTotal5 = State.AddCumulativeMetalSent(1, 0)
	assert(newTotal5 == 150, "Should handle 0 amount correctly")
	assert(State.GetCumulativeMetalSent(1) == 150, "Should not change total with 0 amount")
	
	local newTotal6 = State.AddCumulativeMetalSent(3, 75)
	assert(newTotal6 == 75, "Should initialize new team with correct amount")
	assert(State.GetCumulativeMetalSent(3) == 75, "Should track new team correctly")
	
	local negativeTotal = State.AddCumulativeMetalSent(1, -25)
	assert(negativeTotal == 125, "Should handle negative amounts")
	assert(State.GetCumulativeMetalSent(1) == 125, "Should persist negative adjustment")
end
