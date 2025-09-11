-- Spring environment mocks for unit testing
local M = {}

-- Mock Spring API
M.Spring = {
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
    GetTeamUnits = function(teamID) return {} end,
    GetPlayerList = function() return {0, 1} end,
    GetPlayerInfo = function(playerID) return "Player" .. playerID, true, false, playerID end,
    IsCheatingEnabled = function() return false end,
    GetGaiaTeamID = function() return 999 end,
    GetTeamLuaAI = function(teamID) return nil end
}

-- Mock CMD constants
M.CMD = {
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

-- Mock UnitDefs
M.UnitDefs = {
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

-- Mock UnitDefNames
M.UnitDefNames = {
    armcom = { id = 1 },
    armlab = { id = 2 },
    armpw = { id = 3 },
    armadvcv = { id = 4 },
    armvp = { id = 5 },
    armsolar = { id = 6 },
    armmex = { id = 7 },
}

-- Mock GG table
M.GG = {
    TeamTransfer = nil
}

-- Mock LOG levels
M.LOG = { INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR", DEBUG = "DEBUG" }

return M
