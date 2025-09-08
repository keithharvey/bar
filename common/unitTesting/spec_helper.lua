-- Make unpack universally available
_G.unpack = _G.unpack or table.unpack or function(t, i, j)
    i = i or 1; j = j or #t
    if i > j then return end
    return t[i], _G.unpack(t, i+1, j)
end

_G.pp = function(o, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local t = type(o)
    if t ~= "table" then return tostring(o) end
    local out = {"{"}
    for k, v in pairs(o) do
      out[#out+1] = string.format("%s  %s: %s", pad, tostring(k), pp(v, indent+1))
    end
    out[#out+1] = pad .. "}"
    return table.concat(out, "\n")
  end

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

-- Basic Spring mock for testing (will be replaced by SpringRepository)
_G.Spring = _G.Spring or {
    Log = function(section, level, message, ...)
        -- Simple logging for tests
        print(string.format("[%s:%s] %s", section, level, message))
    end
}
  
