local Globals = {}

-- Command constants
Globals.CMD = {
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

-- Unit definitions - simple declarative defaults
Globals.UnitDefs = {
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

-- Unit definition names lookup
Globals.UnitDefNames = {
    armcom = { id = 1 },
    armlab = { id = 2 },
    armpw = { id = 3 },
    armadvcv = { id = 4 },
    armvp = { id = 5 },
    armsolar = { id = 6 },
    armmex = { id = 7 },
}

-- GG table for global gadgets
Globals.GG = {
    TeamTransfer = nil
}

-- LOG level constants
Globals.LOG = {
    INFO = "INFO",
    WARNING = "WARNING",
    ERROR = "ERROR",
    DEBUG = "DEBUG"
}

return Globals
