-- Spring Repository Builder
-- Builds SpringRepository with mocked Spring API for testing

---@class SpringRepositoryBuilder
---@field modOptions table
---@field teamRulesParams table
---@field teamResources table
---@field teamList table
---@field logMessages table
---@field alliances table
---@field gameFrame number
---@field cheatingEnabled boolean

---@class SpringRepositoryMock
---@field GetModOptions fun(): table
---@field GetGameFrame fun(): number
---@field IsCheatingEnabled fun(): boolean
---@field Log fun(tag: string, level: string, msg: string)

---@class SpringRepositoryBuilder
local SpringRepositoryBuilder = {}
SpringRepositoryBuilder.__index = SpringRepositoryBuilder

---Create a new SpringRepositoryBuilder instance
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder.new()
    return setmetatable({
        modOptions = {},
        teamRulesParams = {}, -- teamID -> paramName -> value
        teamResources = {}, -- teamID -> resource -> amount
        teamList = {},
        logMessages = {},
        alliances = {}, -- teamID -> teamID -> boolean
        gameFrame = 1,
        cheatingEnabled = false
    }, SpringRepositoryBuilder)
end

-- Concrete colon methods for IntelliSense and navigation

---@param self SpringRepositoryBuilder
---@param options table
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithModOptions(options)
    self.modOptions = options
    return self
end

---@param self SpringRepositoryBuilder
---@param key string
---@param value any
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithModOption(key, value)
    self.modOptions[key] = value
    return self
end

---@param self SpringRepositoryBuilder
---@param teams number[]
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithTeamList(teams)
    self.teamList = teams
    return self
end

---@param self SpringRepositoryBuilder
---@param teamID number
---@param paramName string
---@param value any
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithTeamRulesParam(teamID, paramName, value)
    self.teamRulesParams[teamID] = self.teamRulesParams[teamID] or {}
    self.teamRulesParams[teamID][paramName] = value
    return self
end

---@param self SpringRepositoryBuilder
---@param teamID number
---@param resource string
---@param amount number
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithTeamResources(teamID, resource, amount)
    self.teamResources[teamID] = self.teamResources[teamID] or {}
    self.teamResources[teamID][resource] = amount
    return self
end

local function resolveTeamId(team)
    if type(team) == "number" then return team end
    if type(team) == "table" then
        if type(team.Build) == "function" then
            local built = team:Build()
            return built and built.id or team.id
        end
        return team.id
    end
    return team
end

---@param self SpringRepositoryBuilder
---@param a any
---@param b any
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithAlliance(a, b)
    local aId = resolveTeamId(a)
    local bId = resolveTeamId(b)
    self.alliances[aId] = self.alliances[aId] or {}
    self.alliances[bId] = self.alliances[bId] or {}
    self.alliances[aId][bId] = true
    self.alliances[bId][aId] = true
    return self
end

---Build creates the final SpringRepository mock from the current configuration
---@param self SpringRepositoryBuilder
---@return SpringRepositoryMock
function SpringRepositoryBuilder:Build()
    local instance = self
    return {
        GetModOptions = function()
            return instance.modOptions
        end,
        GetGameFrame = function()
            return instance.gameFrame
        end,
        IsCheatingEnabled = function()
            return instance.cheatingEnabled
        end,
        Log = function(tag, level, msg)
            table.insert(instance.logMessages, {tag = tag, level = level, msg = msg})
        end,
        GetLoggedMessages = function()
            return instance.logMessages
        end
    }
end
return SpringRepositoryBuilder
