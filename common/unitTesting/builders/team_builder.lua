-- Team Builder
-- Builds individual team/player configurations with automatic ID generation

local BaseBuilder = require("common/unitTesting/builders/base_builder")
local sequence = require("common/unitTesting/builders/sequence")

---@class TeamData
---@field id number Team ID assigned by SpringBuilder
---@field isHuman boolean
---@field playerName string
---@field metalAmount number
---@field energyAmount number
---@field metalStorage number
---@field energyStorage number

---@class TeamBuilder : BaseBuilder<TeamData>
---@field Human fun(): TeamBuilder
---@field AI fun(): TeamBuilder
---@field PoorButNotBroke fun(): TeamBuilder
---@field Broke fun(): TeamBuilder
---@field Rich fun(): TeamBuilder
---@field Named fun(name: string): TeamBuilder
---@field WithResources fun(metal: number, energy: number): TeamBuilder
---@field WithMetal fun(metal: number): TeamBuilder
---@field WithMetalStorage fun(storage: number): TeamBuilder
---@field WithEnergy fun(energy: number): TeamBuilder
---@field WithEnergyStorage fun(storage: number): TeamBuilder
---@field Build fun(): TeamData
local TeamBuilder = {}

-- Sequence generator for team IDs
local nextTeamId = sequence.sequence("team_id", { start = 0, format = function(p, n) return tostring(n) end })

-- Default data for TeamBuilder instances
---@type TeamData
local defaultData = {
    id = 0, -- Will be set properly during build
    isHuman = true,
    metalAmount = 1000,
    energyAmount = 1000,
    metalStorage = 2000,
    energyStorage = 2000,
    playerName = "TestPlayer"
}

-- Fluent methods that mutate the instance
local methods = {
    ---AI sets the player type to AI
    ---@param instance TeamData
    ---@return TeamData
    AI = function(instance)
        instance.isHuman = false
        return instance
    end,

    ---PoorButNotBroke sets team resources to low but playable amounts
    ---@param instance TeamData
    ---@return TeamData
    PoorButNotBroke = function(instance)
        instance.metalAmount = 200
        instance.energyAmount = 300
        return instance
    end,

    ---Broke sets team resources to minimal amounts
    ---@param instance TeamData
    ---@return TeamData
    Broke = function(instance)
        instance.metalAmount = 50
        instance.energyAmount = 50
        return instance
    end,

    ---Rich sets team resources to abundant amounts
    ---@param instance TeamData
    ---@return TeamData
    Rich = function(instance)
        instance.metalAmount = 5000
        instance.energyAmount = 8000
        return instance
    end,

    ---Human sets the player type to human
    ---@param instance TeamData
    ---@return TeamData
    Human = function(instance)
        instance.isHuman = true
        return instance
    end,

    ---Named sets the player name
    ---@param instance TeamData
    ---@param name string The player name
    ---@return TeamData
    Named = function(instance, name)
        instance.playerName = name
        return instance
    end,

    ---WithResources sets specific metal and energy amounts
    ---@param instance TeamData
    ---@param metal number Metal amount
    ---@param energy number Energy amount
    ---@return TeamData
    WithResources = function(instance, metal, energy)
        instance.metalAmount = metal
        instance.energyAmount = energy
        return instance
    end,

    ---WithMetal configures specific metal amount
    ---@param instance TeamData
    ---@param metal number Metal amount for the team
    ---@return TeamData
    WithMetal = function(instance, metal)
        instance.metalAmount = metal
        return instance
    end,

    ---WithMetalStorage configures specific metal storage capacity
    ---@param instance TeamData
    ---@param storage number Metal storage capacity
    ---@return TeamData
    WithMetalStorage = function(instance, storage)
        instance.metalStorage = storage
        return instance
    end,

    ---WithEnergy configures specific energy amount
    ---@param instance TeamData
    ---@param energy number Energy amount for the team
    ---@return TeamData
    WithEnergy = function(instance, energy)
        instance.energyAmount = energy
        return instance
    end,

    ---WithEnergyStorage configures specific energy storage capacity
    ---@param instance TeamData
    ---@param storage number Energy storage capacity
    ---@return TeamData
    WithEnergyStorage = function(instance, storage)
        instance.energyStorage = storage
        return instance
    end
}

-- Build function for the TeamBuilder
---@param instance TeamData
---@return TeamData
local buildFunction = function(instance)
    ---Build creates the final TeamData object from the current configuration
    local out = {
        id = tonumber(nextTeamId()),
        isHuman = instance.isHuman,
        playerName = instance.playerName,
        metalAmount = instance.metalAmount,
        energyAmount = instance.energyAmount,
        metalStorage = instance.metalStorage,
        energyStorage = instance.energyStorage
    }
    -- Attach built id back to builder instance for tests that reference me.id / ally.id
    instance.id = out.id
    return out
end

-- Create the complete builder with automatic static methods
local BaseBuilder = require("common/unitTesting/builders/base_builder")
local TeamBuilder = BaseBuilder.createBuilder({
    defaultData = defaultData,
    methods = methods,
    buildFunction = buildFunction,
    className = "TeamBuilder"
})

return TeamBuilder