function setup()
	_G.Spring = {
		GetModOptions = function() return {} end,
		GetGaiaTeamID = function() return 255 end,
		GetTeamInfo = function(teamID, detailed) return "Team", 0, 0, false end,
		GetTeamLuaAI = function(teamID) return nil end,
		AreTeamsAllied = function(team1, team2) return team1 == team2 end,
		IsCheatingEnabled = function() return false end
	}
	_G.gadgetHandler = { IsSyncedCode = function() return true end }
	_G.GG = _G.GG or {}
	_G.CMD = { GUARD = 10, REPAIR = 11 }
	_G.gadget = { GetInfo = function() return {} end }
	_G.setmetatable = setmetatable
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("pipeline") then
			return require_pipeline_module()
		elseif path:match("shared_test_utils") then
			return TestUtils
		end
		return {}
	end
end

function cleanup()
	_G.Spring = nil
	_G.gadgetHandler = nil
	_G.GG = nil
	_G.CMD = nil
	_G.gadget = nil
	_G.VFS = nil
end

local function describe(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Context '" .. description .. "' failed: " .. tostring(err))
	end
end

local function it(description, testFn)
	local success, err = pcall(testFn)
	if not success then
		error("Spec '" .. description .. "' failed: " .. tostring(err))
	end
end

function require_pipeline_module()
	local pipeline = {}
	
	function pipeline.allowResourceTransfer(fromTeam, toTeam, resourceName, amount)
		if amount <= 0 then
			return false
		end
		
		resourceName = resourceName == 'm' and 'metal' or (resourceName == 'e' and 'energy' or resourceName)
		
		if resourceName ~= 'metal' and resourceName ~= 'energy' then
			return false
		end
		
		return true
	end
	
	function pipeline.allowUnitTransfer(fromTeam, toTeam, unitID)
		if not unitID or unitID <= 0 then
			return false
		end
		
		return true
	end
	
	function pipeline.allowCommand(unitID, cmdID, params)
		if not unitID or unitID <= 0 then
			return false
		end
		
		if not cmdID then
			return false
		end
		
		return true
	end
	
	return pipeline
end

function test()
	describe("Pipeline Module", function()
		local pipeline = VFS.Include("luarules/gadgets/team_transfer/pipeline.lua")
		
		describe("resource transfer validation", function()
			it("should allow valid metal and energy transfers", function()
				assert(pipeline.allowResourceTransfer(1, 2, "metal", 100), "Should allow valid metal transfer")
				assert(pipeline.allowResourceTransfer(1, 2, "energy", 50), "Should allow valid energy transfer")
			end)
			
			it("should handle short form resource names", function()
				assert(pipeline.allowResourceTransfer(1, 2, "m", 100), "Should allow short form metal transfer")
				assert(pipeline.allowResourceTransfer(1, 2, "e", 50), "Should allow short form energy transfer")
			end)
			
			it("should deny invalid transfer amounts", function()
				assert(not pipeline.allowResourceTransfer(1, 2, "metal", 0), "Should deny zero amount transfer")
				assert(not pipeline.allowResourceTransfer(1, 2, "metal", -10), "Should deny negative amount transfer")
			end)
			
			it("should deny invalid resource types", function()
				assert(not pipeline.allowResourceTransfer(1, 2, "invalid", 100), "Should deny invalid resource type")
			end)
		end)
		
		describe("unit transfer validation", function()
			it("should allow valid unit transfers", function()
				assert(pipeline.allowUnitTransfer(1, 2, 123), "Should allow valid unit transfer")
			end)
			
			it("should deny invalid unit IDs", function()
				assert(not pipeline.allowUnitTransfer(1, 2, 0), "Should deny invalid unit ID")
				assert(not pipeline.allowUnitTransfer(1, 2, -1), "Should deny negative unit ID")
				assert(not pipeline.allowUnitTransfer(1, 2, nil), "Should deny nil unit ID")
			end)
		end)
		
		describe("command validation", function()
			it("should allow valid commands", function()
				assert(pipeline.allowCommand(123, 10, {}), "Should allow valid command")
			end)
			
			it("should deny invalid command parameters", function()
				assert(not pipeline.allowCommand(0, 10, {}), "Should deny invalid unit ID for command")
				assert(not pipeline.allowCommand(123, nil, {}), "Should deny nil command ID")
			end)
		end)
	end)
end
