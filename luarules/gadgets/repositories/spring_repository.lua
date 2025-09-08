---@class SpringRepository
---@field GetModOptions fun(): table
---@field GetGameFrame fun(): number
---@field IsCheatingEnabled fun(): boolean
---@field Log fun(tag: string, level: string, msg: string)
local SpringRepository = {}

---Create a new SpringRepository instance
---@return SpringRepository
function SpringRepository.new()
    return {
        GetModOptions = function()
            return Spring.GetModOptions()
        end,

        GetGameFrame = function()
            return Spring.GetGameFrame()
        end,

        IsCheatingEnabled = function()
            return Spring.IsCheatingEnabled()
        end,

        Log = function(tag, level, msg)
            Spring.Log(tag, level, msg)
        end
    }
end

return SpringRepository
