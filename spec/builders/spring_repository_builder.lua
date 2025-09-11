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
---@param teamID number
---@param resource string
---@param amount number
---@return SpringRepositoryBuilder
function SpringRepositoryBuilder:WithTeamResources(teamID, resource, amount)
    self.teamResources[teamID] = self.teamResources[teamID] or {}
    self.teamResources[teamID][resource] = amount
    return self
end

---Build creates the final SpringRepository mock from the current configuration
---@param self SpringRepositoryBuilder
---@return SpringRepositoryMock
function SpringRepositoryBuilder:Build()
    local instance = self
    local springRepo = {
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
            -- Respect LOG_LEVEL filtering directly
            local LOG_LEVELS = {
                DEBUG = 0,
                INFO = 1,
                WARNING = 2,
                ERROR = 3
            }
            local LOG_LEVEL = LOG_LEVELS.INFO
            local levelValue = LOG_LEVELS[level] or LOG_LEVELS.INFO
            if levelValue >= LOG_LEVEL then
                print(string.format("[%s:%s] %s", tag, level, msg))
            end
        end,
        GetLoggedMessages = function()
            return instance.logMessages
        end
    }

    -- Setup _G.Spring globals when building
    _G.Spring.GetGameFrame = springRepo.GetGameFrame
    _G.Spring.IsCheatingEnabled = springRepo.IsCheatingEnabled
    _G.Spring.GetModOptions = springRepo.GetModOptions
    _G.Spring.Log = springRepo.Log

    return springRepo
end
return SpringRepositoryBuilder
