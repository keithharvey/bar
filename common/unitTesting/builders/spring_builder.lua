---@class SpringMock
---@field GetModOptions fun(): table
---@field GetTeamResources fun(teamID: number, resource: string, resourceType: string?): number, number, number, number, number, number, number, number
---@field AreTeamsAllied fun(team1: number, team2: number): boolean
---@field GetGameFrame fun(): number
---@field IsCheatingEnabled fun(): boolean
---@field GetGaiaTeamID fun(): number
---@field GetTeamInfo fun(teamID: number): number, number, number, boolean, boolean, number, boolean, boolean
---@field GetTeamLuaAI fun(teamID: number): string?
---@field GetPlayerList fun(teamID: number?, active: boolean?): number[]
---@field GetPlayerInfo fun(playerID: number, full: boolean?): string, boolean, boolean, number
---@field Log fun(tag: string, level: string, msg: string)

---@class SpringBuilder
---@field teams table<number, TeamData>
---@field teamRefs TeamData[]
---@field teamCounter number
---@field gameFrame number
---@field cheatingEnabled boolean
---@field alliances table<number, table<number, boolean>>
---@field modOptions table<string, any>
---@field _lastTeamResult TeamData?
local SpringBuilder = {}

-- Default data for SpringBuilder instances
local defaultData = {
    teams = {},
    teamRefs = {},
    teamCounter = 0,
    gameFrame = 1,
    cheatingEnabled = false,
    alliances = {},
    modOptions = {
        unit_sharing_mode = "enabled",
        resource_sharing_mode = "enabled"
    }
}

---Create a new SpringBuilder instance
---@return SpringBuilder
function SpringBuilder.new()
    local instance = {}
    
    -- Copy default data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end
    
    return setmetatable(instance, SpringBuilder)
end

---WithGameFrame sets the current game frame
---@param self SpringBuilder
---@param frame number The game frame number
---@return SpringBuilder
function SpringBuilder:WithGameFrame(frame)
    self.gameFrame = frame
    return self
end

---WithCheating enables or disables cheating mode
---@param self SpringBuilder
---@param enabled boolean Whether cheating should be enabled
---@return SpringBuilder
function SpringBuilder:WithCheating(enabled)
    self.cheatingEnabled = enabled
    return self
end

---WithModOption sets a mod option in the Spring environment
---@param self SpringBuilder
---@param key string The mod option key
---@param value any The mod option value
---@return SpringBuilder
function SpringBuilder:WithModOption(key, value)
    self.modOptions[key] = value
    return self
end

---Build creates the final Spring environment mock from the current configuration
---@param self SpringBuilder
---@return SpringMock
function SpringBuilder:Build()
    -- Set up all globals that Spring environment needs
    _G.GG = _G.GG or {}
    _G.LOG = _G.LOG or { INFO = "INFO", WARNING = "WARNING", ERROR = "ERROR" }
    _G.CMD = _G.CMD or {
        GUARD = 10, MOVE = 20, ATTACK = 30, STOP = 0, WAIT = 5,
        MOVE_STATE = 50, FIRE_STATE = 45, REPEAT = 115, CLOAK = 37, ONOFF = 35
    }
    
    -- Store instance globally so functions can access it
    _G.SpringBuilderInstance = self

    local springMock = {
        GetModOptions = function()
            return _G.SpringBuilderInstance and _G.SpringBuilderInstance.modOptions or {}
        end,

        GetTeamResources = function(teamID, resource, resourceType)
            local instance = _G.SpringBuilderInstance
            local team = instance.teams[teamID]
            if not team then
                error("Team not found: " .. teamID)
            end

            if resourceType == "storage" then
                return resource == "metal" and team.metalStorage or team.energyStorage
            end

            local current = resource == "metal" and team.metalAmount or team.energyAmount
            local storage = resource == "metal" and team.metalStorage or team.energyStorage
            return current, storage, 0, storage, storage, 0, 0, 0
        end,

        AreTeamsAllied = function(team1, team2)
            if team1 == team2 then return true end
            local instance = _G.SpringBuilderInstance
            return instance.alliances[team1] and instance.alliances[team1][team2] or false
        end,

        GetGameFrame = function()
            local instance = _G.SpringBuilderInstance
            return instance.gameFrame
        end,

        IsCheatingEnabled = function()
            local instance = _G.SpringBuilderInstance
            return instance.cheatingEnabled
        end,

        GetGaiaTeamID = function()
            return 999
        end,

        GetTeamInfo = function(teamID)
            local instance = _G.SpringBuilderInstance
            local team = instance.teams[teamID]
            if team then
                return 0, 0, 0, not team.isHuman, false, 0, false, false
            end
            return 0, 0, 0, false, false, 0, false, false
        end,

        GetTeamLuaAI = function(teamID)
            local instance = _G.SpringBuilderInstance
            local team = instance.teams[teamID]
            return (team and not team.isHuman) and "AI" or nil
        end,

        GetPlayerList = function(teamID, active)
            local instance = _G.SpringBuilderInstance
            if teamID then
                local team = instance.teams[teamID]
                return (team and team.isHuman) and {teamID} or {}
            end
            local players = {}
            for id, team in pairs(instance.teams) do
                if team.isHuman then
                    table.insert(players, id)
                end
            end
            return players
        end,

        GetPlayerInfo = function(playerID, full)
            local instance = _G.SpringBuilderInstance
            local team = instance.teams[playerID]
            if team then
                return team.playerName, true, false, playerID
            end
            return "TestPlayer", true, false, playerID
        end,

        Log = function(tag, level, msg)
            -- Silent mock for testing
        end
    }

    -- Add helper methods to the mock for easy team access
    springMock.GetFirstTeam = function() return self.teamRefs[1] end
    springMock.GetSecondTeam = function() return self.teamRefs[2] end
    springMock.GetTeam = function(index) return self.teamRefs[index] end

    return springMock
end

return SpringBuilder