-- Team Builder
-- Builds individual team/player configurations with automatic ID generation

local sequence = require("spec/builders/sequence")

---@class TeamData
---@field id number Team ID assigned by SpringBuilder
---@field isHuman boolean
---@field playerName string
---@field metalAmount number
---@field energyAmount number
---@field metalStorage number
---@field energyStorage number


---@class TeamBuilder
---@field id number Team ID assigned by SpringBuilder
---@field isHuman boolean
---@field playerName string
---@field metalAmount number
---@field energyAmount number
---@field metalStorage number
---@field energyStorage number
--- __index = TeamBuilder
local TeamBuilder = {}

-- Sequence generator for team IDs
local nextTeamId = sequence.sequence("team_id", { start = 0, format = function(p, n) return tostring(n) end })

---@type TeamData
local defaultData = {
    id = 0,
    isHuman = true,
    metalAmount = 1000,
    energyAmount = 1000,
    metalStorage = 1000,
    energyStorage = 1000,
    playerName = "TestPlayer"
}

-- Build function for the TeamBuilder
---@param instance TeamBuilder
---@return TeamData
local buildFunction = function(instance)
    ---Build creates the final TeamData object from the current configuration
    -- ID is already assigned in constructor
    local teamId = instance.id
    local out = {
        id = teamId,
        isHuman = instance.isHuman,
        playerName = instance.playerName,
        metalAmount = instance.metalAmount,
        energyAmount = instance.energyAmount,
        metalStorage = instance.metalStorage,
        energyStorage = instance.energyStorage,
    }
    return out
end

-- Create the builder using traditional metatable approach like other builders
---@class TeamBuilder
local TeamBuilder = {}
TeamBuilder.__index = TeamBuilder

-- Instance methods for fluent interface
function TeamBuilder:WithEnergy(energy)
    self.energyAmount = energy
    return self
end

function TeamBuilder:WithEnergyStorage(storage)
    self.energyStorage = storage
    return self
end

function TeamBuilder:WithMetal(metal)
    self.metalAmount = metal
    return self
end

function TeamBuilder:WithMetalStorage(storage)
    self.metalStorage = storage
    return self
end

-- Add Build method
TeamBuilder.Build = function(instance)
    return buildFunction(instance)
end

-- Static factory methods for fluent interface
function TeamBuilder.new()
    local instance = {}

    -- Copy default data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end

    -- Assign unique ID immediately to prevent collisions
    instance.id = tonumber(nextTeamId())

    return setmetatable(instance, TeamBuilder)
end

function TeamBuilder.Human(instance)
    instance = instance or TeamBuilder.new()
    instance.isHuman = true
    return instance
end

function TeamBuilder.AI(instance)
    instance = instance or TeamBuilder.new()
    instance.isHuman = false
    return instance
end

function TeamBuilder.Rich(instance)
    instance = instance or TeamBuilder.new()
    instance.metalAmount = 5000
    instance.energyAmount = 8000
    return instance
end

function TeamBuilder.PoorButNotBroke(instance)
    instance = instance or TeamBuilder.new()
    instance.metalAmount = 200
    instance.energyAmount = 300
    return instance
end

function TeamBuilder.Broke(instance)
    instance = instance or TeamBuilder.new()
    instance.metalAmount = 50
    instance.energyAmount = 50
    return instance
end

function TeamBuilder.Named(instance, name)
    instance = instance or TeamBuilder.new()
    instance.playerName = name
    return instance
end

-- Removed duplicate static methods - use instance methods with colons instead

return TeamBuilder