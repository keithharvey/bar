#!/usr/bin/env lua5.1

--
--   lua5.1 test_runner.lua                           # Run all unit tests
--   lua5.1 test_runner.lua unit/                     # Run all unit tests


local function loadTestingUtilities()
    local VFS = {
        Include = function(path)
            local fsPath = path:gsub("^luarules/gadgets/", ""):gsub("^luaui/", ""):gsub("^common/", "")
            
            if path:match("common/testing/") then
                local filename = path:match("([^/]+)%.lua$")
                if filename == "assertions" then
                    return dofile("common/testing/assertions.lua")
                elseif filename == "mock" then
                    return dofile("common/testing/mock.lua")
                elseif filename == "util" then
                    return dofile("common/testing/util.lua")
                elseif filename == "results" then
                    return dofile("common/testing/results.lua")
                end
            elseif path == "luarules/gadgets/team_transfer/unit_sharing.lua" then
                return dofile("luarules/gadgets/team_transfer/unit_sharing.lua")
            end
            
            return {}
        end,
        FileExists = function(path)
            local file = io.open(path, "r")
            if file then
                file:close()
                return true
            end
            return false
        end,
        LoadFile = function(path)
            local file = io.open(path, "r")
            if file then
                local content = file:read("*all")
                file:close()
                return content
            end
            return nil
        end,
        RAW_FIRST = 1
    }
    
    return VFS
end

local function createTestEnvironment()
    local VFS = loadTestingUtilities()
    local Assertions = VFS.Include("common/testing/assertions.lua")
    local Mock = VFS.Include("common/testing/mock.lua")
    local Util = VFS.Include("common/testing/util.lua")
    local TestResults = VFS.Include("common/testing/results.lua")
    
    _G.Spring = {
        GetModOptions = function() return {} end,
        GetGameFrame = function() return 1 end,
        GetTimer = function() return 0 end,
        GetGameSeconds = function() return 1 end,
        GetTeamList = function() return {0, 1} end,
        AreTeamsAllied = function(team1, team2) return team1 == team2 end,
        GetTeamResources = function(teamID, resource) 
            return 1000, 1000, 0, 1000, 1000, 0, 0, 0
        end,
        GetUnitDefID = function(unitID) return 1 end,
        GetUnitTeam = function(unitID) return 0 end,
        ValidUnitID = function(unitID) return true end,
        Echo = function(...) print(...) end,
        Log = function(tag, level, msg)
            print(string.format("[%s][%s] %s", tostring(level or "INFO"), tostring(tag or "Log"), tostring(msg)))
        end,
        GetMyTeamID = function() return 0 end,
        GetMyAllyTeamID = function() return 0 end,
        GetTeamInfo = function(teamID) return 0, 0, 0, false, false, 0, false, false end,
        GetAllyTeamInfo = function(allyTeamID) return 1, 1 end,
        GetAllyTeamList = function() return {0} end,
        CreateUnit = function(unitDefName, x, y, z, facing, teamID) return math.random(1000, 9999) end,
        GetGroundHeight = function(x, z) return 0 end,
        ShareResources = function(teamID, resource, amount) end,
        TransferUnit = function(unitID, teamID, given) end,
    }
    
    _G.CMD = { 
        GUARD = 10, 
        MOVE = 20, 
        ATTACK = 30,
        STOP = 0,
        WAIT = 5,
        MOVE_STATE = 50,
        FIRE_STATE = 45,
        REPEAT = 115,
        CLOAK = 37,
        ONOFF = 35,
    }
    
    _G.UnitDefs = {
        [1] = {
            name = "armcom",
            customParams = { iscommander = "1" },
            canMove = true,
            canAttack = true,
        },
        [2] = {
            name = "armlab", 
            customParams = { techlevel = "1" },
            canMove = false,
            canAttack = false,
            isFactory = true,
        },
        [3] = {
            name = "armpw",
            customParams = { techlevel = "1" },
            canMove = true,
            canAttack = true,
        },
        [4] = {
            name = "armadvcv",
            customParams = { techlevel = "2" },
            canMove = true,
            canAssist = true,
            buildOptions = { "armcom", "armpw" },
        },
        [5] = {
            name = "armvp",
            customParams = { techlevel = "1" },
            canMove = false,
            canAttack = false,
            isFactory = true,
            buildOptions = { "armpw" },
        },
        [6] = {
            name = "armsolar",
            customParams = { unitgroup = "energy" },
            canMove = false,
            canAttack = false,
        },
        [7] = {
            name = "armmex",
            customParams = { unitgroup = "metal" },
            canMove = false,
            canAttack = false,
        }
    }
    
    _G.UnitDefNames = {
        armcom = { id = 1 },
        armlab = { id = 2 },
        armpw = { id = 3 },
        armadvcv = { id = 4 },
        armvp = { id = 5 },
        armsolar = { id = 6 },
        armmex = { id = 7 },
    }
    
    _G.GG = {
        TeamTransfer = nil
    }
    
    _G.LOG = { INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR", DEBUG = "DEBUG" }
    
    local Test = {
        mock = Mock.mock,
        spy = Mock.spy,
        clearMap = function() end, -- No-op for unit tests
        waitFrames = function(frames) end, -- No-op for unit tests
        waitUntilCallin = function(callinName) end, -- No-op for unit tests
        expectCallin = function(callinName) end, -- No-op for unit tests
    }
    
    local env = {
        Test = Test,
        VFS = VFS,
        SyncedRun = function(func, locals) return func(locals or {}) end,
        Game = { mapSizeX = 1000, mapSizeZ = 1000 },
        
        assert = assert,
        error = error,
        print = print,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        unpack = unpack,
        select = select,
        pcall = pcall,
        xpcall = xpcall,
        
        table = table,
        string = string,
        math = math,
        io = io,
        os = os,
        
        Spring = {
            GetModOptions = function() return {} end,
            GetGameFrame = function() return 1 end,
            GetTimer = function() return 0 end,
            GetGameSeconds = function() return 1 end,
            GetTeamList = function() return {0, 1} end,
            AreTeamsAllied = function(team1, team2) return team1 == team2 end,
            GetTeamResources = function(teamID, resource) 
                return 1000, 1000, 0, 1000, 1000, 0, 0, 0 -- current, storage, pull, income, expense, share, sent, received
            end,
            GetUnitDefID = function(unitID) return 1 end,
            GetUnitTeam = function(unitID) return 0 end,
            ValidUnitID = function(unitID) return true end,
            Echo = function(...) print(...) end,
            Log = function(tag, level, msg)
                print(string.format("[%s][%s] %s", tostring(level or "INFO"), tostring(tag or "Log"), tostring(msg)))
            end,
            GetMyTeamID = function() return 0 end,
            GetMyAllyTeamID = function() return 0 end,
            GetTeamInfo = function(teamID) return 0, 0, 0, false, false, 0, false, false end,
            GetAllyTeamInfo = function(allyTeamID) return 1, 1 end,
            GetAllyTeamList = function() return {0} end,
            CreateUnit = function(unitDefName, x, y, z, facing, teamID) return math.random(1000, 9999) end,
            GetGroundHeight = function(x, z) return 0 end,
            ShareResources = function(teamID, resource, amount) end,
            TransferUnit = function(unitID, teamID, given) end,
        },
        CMD = { 
            GUARD = 10, 
            MOVE = 20, 
            ATTACK = 30,
            STOP = 0,
            WAIT = 5,
            MOVE_STATE = 50,
            FIRE_STATE = 45,
            REPEAT = 115,
            CLOAK = 37,
            ONOFF = 35,
        },
        GG = {
            TeamTransfer = nil
        },
        debug = debug,
        
        UnitDefs = {
            [1] = {
                name = "armcom",
                customParams = { iscommander = "1" },
                canMove = true,
                canAttack = true,
            },
            [2] = {
                name = "armlab", 
                customParams = { techlevel = "1" },
                canMove = false,
                canAttack = false,
                isFactory = true,
            },
            [3] = {
                name = "armpw",
                customParams = { techlevel = "1" },
                canMove = true,
                canAttack = true,
            },
            [4] = {
                name = "armadvcv",
                customParams = { techlevel = "2" },
                canMove = true,
                canAssist = true,
                buildOptions = { "armcom", "armpw" },
            },
            [5] = {
                name = "armvp",
                customParams = { techlevel = "1" },
                canMove = false,
                canAttack = false,
                isFactory = true,
                buildOptions = { "armpw" },
            },
            [6] = {
                name = "armsolar",
                customParams = { unitgroup = "energy" },
                canMove = false,
                canAttack = false,
            },
            [7] = {
                name = "armmex",
                customParams = { unitgroup = "metal" },
                canMove = false,
                canAttack = false,
            }
        },
        
        UnitDefNames = {
            armcom = { id = 1 },
            armlab = { id = 2 },
            armpw = { id = 3 },
            armadvcv = { id = 4 },
            armvp = { id = 5 },
            armsolar = { id = 6 },
            armmex = { id = 7 },
        },
        
    }

    -- Provide LOG level constants for modules using Spring.Log(tag, LOG.X, msg)
    env.LOG = { INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR", DEBUG = "DEBUG" }
    
    for k, v in pairs(Assertions) do
        env[k] = v
    end
    
    env._G = env
    
    return env, TestResults
end

local function findTestFiles(pattern)
    local testFiles = {}
    
    local knownTests = {
        "luaui/Tests/team_transfer/unit/test_policy_builder.lua",
        "luaui/Tests/team_transfer/unit/test_predicates.lua", 
        "luaui/Tests/team_transfer/unit/test_resource_tax_calculations.lua",
        "luaui/Tests/team_transfer/unit/test_unit_sharing_logic.lua",
        "luaui/Tests/team_transfer/test_ally_assist.lua",
        "luaui/Tests/team_transfer/test_unit_sharing.lua",
        "luaui/Tests/team_transfer/test_policies.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/policies/test_assist_ally.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/policies/test_enemy_transfer.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/policies/test_unit_sharing_mode.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/policies/test_tax_resource_sharing.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/policies/test_system_cleanup.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_pipeline.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_resource_share_tax.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_unit_sharing.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_predicates.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_resources.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_state.lua",
        "luaui/Tests/team_transfer/gadgets/team_transfer/test_sharing_mode_utils.lua"
    }
    
    for _, file in ipairs(knownTests) do
        if not pattern or file:match(pattern) then
            local f = io.open(file, "r")
            if f then
                f:close()
                table.insert(testFiles, file)
            end
        end
    end
    
    return testFiles
end

local function runTest(filename)
    local env, TestResults = createTestEnvironment()
    
    local file = io.open(filename, "r")
    if not file then
        return {
            result = TestResults.TEST_RESULT.ERROR,
            error = "Could not open file: " .. filename
        }
    end
    
    local content = file:read("*all")
    file:close()
    
    local chunk, err = loadstring(content, filename)
    if not chunk then
        return {
            result = TestResults.TEST_RESULT.ERROR,
            error = "Compilation error: " .. err
        }
    end
    
    setfenv(chunk, env)
    
    local success, err = pcall(chunk)
    if not success then
        return {
            result = TestResults.TEST_RESULT.ERROR,
            error = "Load error: " .. err
        }
    end
    
    if not env.test then
        return {
            result = TestResults.TEST_RESULT.ERROR,
            error = "No test() function found"
        }
    end
    
    if env.setup then
        local setupOk, setupErr = pcall(env.setup)
        if not setupOk then
            return {
                result = TestResults.TEST_RESULT.ERROR,
                error = "Setup error: " .. setupErr
            }
        end
    end
    
    local startTime = os.clock()
    local testOk, testErr = pcall(env.test)
    local endTime = os.clock()
    local duration = math.floor((endTime - startTime) * 1000) -- milliseconds
    
    if env.cleanup then
        pcall(env.cleanup) -- Don't fail test if cleanup fails
    end
    
    if testOk then
        return {
            result = TestResults.TEST_RESULT.PASS,
            milliseconds = duration
        }
    else
        return {
            result = TestResults.TEST_RESULT.FAIL,
            error = testErr,
            milliseconds = duration
        }
    end
end

local function formatResult(filename, result, TestResults)
    local label = filename:match("([^/]+)%.lua$") or filename
    local status = result.result
    local color = ""
    local reset = ""
    
    if status == TestResults.TEST_RESULT.PASS then
        color = "\27[32m" -- Green
    elseif status == TestResults.TEST_RESULT.FAIL then
        color = "\27[31m" -- Red
    elseif status == TestResults.TEST_RESULT.ERROR then
        color = "\27[35m" -- Magenta
    end
    reset = "\27[0m"
    
    local output = color .. status .. reset .. ": " .. label
    if result.milliseconds then
        output = output .. " [" .. result.milliseconds .. " ms]"
    end
    if result.error then
        output = output .. " | " .. result.error
    end
    
    return output
end

local function main(args)
    local patterns = args or {}
    local allPassed = true
    local totalTests = 0
    local passedTests = 0
    
    print("BAR Standalone Test Runner")
    print("==========================")
    
    if #patterns == 0 then
        patterns = { "" }
    end
    
    local env, TestResults = createTestEnvironment()
    
    for _, pattern in ipairs(patterns) do
        local testFiles = findTestFiles(pattern)
        
        if #testFiles == 0 then
            print("No test files found matching pattern: " .. pattern)
        else
            for _, filename in ipairs(testFiles) do
                totalTests = totalTests + 1
                local result = runTest(filename)
                
                if result.result == TestResults.TEST_RESULT.PASS then
                    passedTests = passedTests + 1
                else
                    allPassed = false
                end
                
                print(formatResult(filename, result, TestResults))
            end
        end
    end
    
    print("")
    print("Results: " .. passedTests .. "/" .. totalTests .. " tests passed")
    
    if allPassed then
        print("All tests passed! ✓")
        os.exit(0)
    else
        print("Some tests failed! ✗")
        os.exit(1)
    end
end

main(arg)
