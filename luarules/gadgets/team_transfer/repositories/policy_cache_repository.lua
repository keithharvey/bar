-- Policy Cache Repository for Team Transfer System
-- Manages cached expose data to ensure Query/Validate operations use the same results

local M = {}

---@class PolicyCacheRepository
---@field cache table<string, table> Cache of expose results keyed by cache key
---@field cacheTimeout number Time in seconds after which cache entries expire
---@field lastClearTime number Last time cache was cleared
local PolicyCacheRepository = {}
PolicyCacheRepository.__index = PolicyCacheRepository

-- Default cache timeout (in seconds)
local DEFAULT_CACHE_TIMEOUT = 1.0

---Create a new PolicyCacheRepository
---@param cacheTimeout number|nil Optional cache timeout in seconds
---@return PolicyCacheRepository
function M.new(cacheTimeout)
    local self = setmetatable({}, PolicyCacheRepository)
    self.cache = {}
    self.cacheTimeout = cacheTimeout or DEFAULT_CACHE_TIMEOUT
    self.lastClearTime = 0
    return self
end

---Generate cache key for expose data
---@param senderTeamID number
---@param receiverTeamID number
---@param gameFrame number
---@return string
local function generateCacheKey(senderTeamID, receiverTeamID, gameFrame)
    return string.format("%d_%d_%d", senderTeamID, receiverTeamID, gameFrame)
end

---Get cached expose data and plan if available and not expired
---@param senderTeamID number
---@param receiverTeamID number
---@param gameFrame number
---@return table|nil, table|nil exposeData, plan The cached expose data and plan or nil if not cached/expired
function PolicyCacheRepository:GetCachedExpose(senderTeamID, receiverTeamID, gameFrame)
    local cacheKey = generateCacheKey(senderTeamID, receiverTeamID, gameFrame)
    local cachedEntry = self.cache[cacheKey]
    
    if not cachedEntry then
        return nil
    end
    
    -- Check if cache entry has expired
    local currentTime = gameFrame / 30.0 -- Convert frames to seconds (assuming 30 FPS)
    if currentTime - cachedEntry.timestamp > self.cacheTimeout then
        self.cache[cacheKey] = nil
        return nil
    end
    
    return cachedEntry.data, cachedEntry.plan
end

---Cache expose data with plan
---@param senderTeamID number
---@param receiverTeamID number
---@param gameFrame number
---@param exposeData table The expose data to cache
---@param plan table|nil The evaluation plan to cache alongside the data
function PolicyCacheRepository:CacheExpose(senderTeamID, receiverTeamID, gameFrame, exposeData, plan)
    local cacheKey = generateCacheKey(senderTeamID, receiverTeamID, gameFrame)
    local currentTime = gameFrame / 30.0 -- Convert frames to seconds (assuming 30 FPS)
    
    self.cache[cacheKey] = {
        data = exposeData,
        plan = plan,
        timestamp = currentTime
    }
end

---Clear expired cache entries
---@param gameFrame number Current game frame
function PolicyCacheRepository:ClearExpired(gameFrame)
    local currentTime = gameFrame / 30.0 -- Convert frames to seconds (assuming 30 FPS)
    
    -- Only clear periodically to avoid performance impact
    if currentTime - self.lastClearTime < self.cacheTimeout then
        return
    end
    
    for cacheKey, cachedEntry in pairs(self.cache) do
        if currentTime - cachedEntry.timestamp > self.cacheTimeout then
            self.cache[cacheKey] = nil
        end
    end
    
    self.lastClearTime = currentTime
end

---Clear all cached data
function PolicyCacheRepository:ClearAll()
    self.cache = {}
    self.lastClearTime = 0
end

---Get cache statistics for debugging
---@return table stats Cache statistics
function PolicyCacheRepository:GetStats()
    local count = 0
    for _ in pairs(self.cache) do
        count = count + 1
    end
    
    return {
        entryCount = count,
        cacheTimeout = self.cacheTimeout,
        lastClearTime = self.lastClearTime
    }
end

return M
