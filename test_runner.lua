#!/usr/bin/env lua5.3

--
--   lua5.3 test_runner.lua                           # Run all unit tests
--   lua5.3 test_runner.lua unit/                     # Run all unit tests


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
    
    local Test = {
        mock = Mock.mock,
        spy = Mock.spy,
        clearMap = function() end, -- No-op for unit tests
        waitFrames = function(frames) end, -- No-op for unit tests
    }
    
    local env = {
        Test = Test,
        VFS = VFS,
        
        assert = assert,
        error = error,
        print = print,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        unpack = table.unpack or unpack,
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
        },
        CMD = { GUARD = 10, MOVE = 20, ATTACK = 30 },
        GG = {},
        debug = debug,
        
    }
    
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
        "luaui/Tests/team_transfer/unit/test_unit_sharing_logic.lua"
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
    
    local chunk, err = load(content, filename, "t")
    if not chunk then
        return {
            result = TestResults.TEST_RESULT.ERROR,
            error = "Compilation error: " .. err
        }
    end
    
    if setfenv then
        setfenv(chunk, env)
    else
        local function setEnvironment(f, env)
            local i = 1
            while true do
                local name = debug.getupvalue(f, i)
                if name == "_ENV" then
                    debug.upvaluejoin(f, i, (function() return env end), 1)
                    break
                elseif not name then
                    break
                end
                i = i + 1
            end
        end
        setEnvironment(chunk, env)
    end
    
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
        patterns = { "unit/" }
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
