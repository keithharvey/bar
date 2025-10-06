--- Sharing Mode Repository
--- Handles loading and validation of the current sharing mode configuration

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class SharingModeRepository
---@field currentSharingMode SharingModeConfig
local SharingModeRepository = {}
SharingModeRepository.__index = SharingModeRepository

---Create a new sharing mode repository
---@return SharingModeRepository
function SharingModeRepository.new()
    local instance = setmetatable({}, SharingModeRepository)
    return instance
end

---Load and validate the current sharing mode configuration based on mod options
---@param sharingMode string
---@return SharingModeConfig
function SharingModeRepository:LoadSharingMode(sharingMode)
    local configPath = "luarules/gadgets/team_transfer/sharing_modes/" .. sharingMode .. ".lua"
    local success, modeConfig = pcall(VFS.Include, configPath)

    if success and modeConfig and self:ValidateSharingModeConfig(modeConfig) then
        self.currentSharingMode = modeConfig
        return modeConfig
    else
        error("Failed to load default sharing mode, it is either not present or invalid: " .. sharingMode)
    end
end

---Validate a sharing mode configuration
---@param config SharingModeConfig
---@return boolean isValid
function SharingModeRepository:ValidateSharingModeConfig(config)
    if not config.key or type(config.key) ~= "string" then
        return false
    end

    if not config.name or type(config.name) ~= "string" then
        return false
    end

    if not config.desc or type(config.desc) ~= "string" then
        return false
    end

    if config.allowRanked == nil or type(config.allowRanked) ~= "boolean" then
        return false
    end

    if not config.modOptions or type(config.modOptions) ~= "table" then
        return false
    end

    for optionKey, optionConfig in pairs(config.modOptions) do
        if type(optionConfig) ~= "table" then
            return false
        end
        if optionConfig.locked == nil or type(optionConfig.locked) ~= "boolean" then
            return false
        end
    end

    return true
end

---Get the current sharing mode configuration
---@return SharingModeConfig|nil
function SharingModeRepository:GetCurrentSharingMode()
    return self.currentSharingMode
end

return SharingModeRepository
