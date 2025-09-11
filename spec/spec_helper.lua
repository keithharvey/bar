-- Make unpack universally available
_G.unpack = _G.unpack or table.unpack or function(t, i, j)
    i = i or 1; j = j or #t
    if i > j then return end
    return t[i], _G.unpack(t, i+1, j)
end

-- to enable, `luarocks install inspect`
_G.inspect = (function()
  local ok, mod = pcall(require, "inspect")
  if ok and mod then return mod end
  -- fallback: no-op string (won't break prints/concats)
  return function(_) return _ end
end)()

-- VFS.Include mock for testing - caches loaded modules
_G.VFS = _G.VFS or {}
_G.VFS._cache = _G.VFS._cache or {}
_G.VFS.Include = function(path)
    -- Convert filesystem-like path to module name for require
    local mod = path
        :gsub("^%./", "")
        :gsub("%.lua$", "")
        :gsub("/", ".")
    return require(mod)
end
_G.VFS.FileExists = function(path)
    return true -- Assume files exist for testing
end

-- Spring logging mocks
_G.LOG = _G.LOG or {
    INFO = "INFO",
    ERROR = "ERROR", 
    DEBUG = "DEBUG",
    WARNING = "WARNING"
}

-- Logging functions for testing
_G.LogDebug = _G.LogDebug or function(msg) end -- Silent debug
_G.LogInfo = _G.LogInfo or function(msg) end -- Silent info  
_G.LogError = _G.LogError or function(msg) print("[ERROR] " .. msg) end

-- Log level filter
local LOG_LEVELS = {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3
}
local LOG_LEVEL = LOG_LEVELS.INFO

-- Basic Spring mock for testing (will be replaced by SpringRepository)
_G.Spring = _G.Spring or {
    Log = function(section, level, message, ...)
        -- Simple logging for tests with level filtering
        local levelValue = LOG_LEVELS[level] or LOG_LEVELS.INFO
        if levelValue >= LOG_LEVEL then
            print(string.format("[%s:%s] %s", section, level, message))
        end
    end
}
  
