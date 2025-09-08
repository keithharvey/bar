-- Team Repository Builder
-- Builds TeamRepository with mocked team operations for testing

---@class TeamRepositoryBuilder
---@field cumulativeMetalSent table
---@field alliedTeams table
---@field teamResources table
---@field teamInfo table

---@class TeamRepositoryMock
---@field GetCumulativeMetalSent fun(teamID: number): number
---@field AddCumulativeMetalSent fun(teamID: number, amount: number): number
---@field AreAlliedTeams fun(team1ID: number, team2ID: number): boolean
---@field SetAlliance fun(team1ID: number, team2ID: number)
---@field GetTeamResources fun(teamID: number, resource: string, resourceType: string|nil): number
---@field GetTeamInfo fun(teamID: number): number, number, number, boolean, boolean, number, boolean, boolean

---@class TeamRepositoryBuilder
local TeamRepositoryBuilder = {}
TeamRepositoryBuilder.__index = TeamRepositoryBuilder

---@return TeamRepositoryBuilder
function TeamRepositoryBuilder.new()
    return setmetatable({
        cumulativeMetalSent = {},
        alliedTeams = {},
        teamResources = {},
        teamInfo = {},
    }, TeamRepositoryBuilder)
end

local function resolveTeamData(value)
    if type(value) == "table" and type(value.Build) == "function" then
        return value:Build()
    end
    return value
end

---@param self TeamRepositoryBuilder
---@param team1Data TeamData|TeamBuilder
---@param team2Data TeamData|TeamBuilder
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithAlliedPlayers(team1Data, team2Data)
    team1Data = resolveTeamData(team1Data)
    team2Data = resolveTeamData(team2Data)
    self.alliedTeams[team1Data.id] = self.alliedTeams[team1Data.id] or {}
    self.alliedTeams[team2Data.id] = self.alliedTeams[team2Data.id] or {}
    self.alliedTeams[team1Data.id][team2Data.id] = true
    self.alliedTeams[team2Data.id][team1Data.id] = true
    self.teamResources[team1Data.id] = {
        metal = { current = team1Data.metalAmount, storage = team1Data.metalStorage },
        energy = { current = team1Data.energyAmount, storage = team1Data.energyStorage }
    }
    self.teamResources[team2Data.id] = {
        metal = { current = team2Data.metalAmount, storage = team2Data.metalStorage },
        energy = { current = team2Data.energyAmount, storage = team2Data.energyStorage }
    }
    return self
end

---@param self TeamRepositoryBuilder
---@param teamID number
---@param amount number
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithCumulativeMetalSent(teamID, amount)
    self.cumulativeMetalSent[teamID] = amount
    return self
end

---@param self TeamRepositoryBuilder
---@param teamID number
---@param resource string
---@param amount number
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithTeamResources(teamID, resource, amount)
    self.teamResources[teamID] = self.teamResources[teamID] or {}
    self.teamResources[teamID][resource] = amount
    return self
end

---@param self TeamRepositoryBuilder
---@param teamID number
---@param info table
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithTeamInfo(teamID, info)
    self.teamInfo[teamID] = info
    return self
end


---Build returns the TeamRepository mock
---@param self TeamRepositoryBuilder
---@return TeamRepositoryMock
function TeamRepositoryBuilder:Build()
    local instance = self
    return {
        GetCumulativeMetalSent = function(teamID)
            return instance.cumulativeMetalSent[teamID] or 0
        end,

        AddCumulativeMetalSent = function(teamID, amount)
            local current = instance.cumulativeMetalSent[teamID] or 0
            local newTotal = current + (amount or 0)
            instance.cumulativeMetalSent[teamID] = newTotal
            return newTotal
        end,

        AreAlliedTeams = function(team1ID, team2ID)
            if team1ID == team2ID then return true end
            return instance.alliedTeams[team1ID] and instance.alliedTeams[team1ID][team2ID] or false
        end,

        SetAlliance = function(team1ID, team2ID)
            instance.alliedTeams[team1ID] = instance.alliedTeams[team1ID] or {}
            instance.alliedTeams[team2ID] = instance.alliedTeams[team2ID] or {}
            instance.alliedTeams[team1ID][team2ID] = true
            instance.alliedTeams[team2ID][team1ID] = true
        end,

        GetTeamResources = function(teamID, resource, resourceType)
            local teamRes = instance.teamResources[teamID]
            if not teamRes or not teamRes[resource] then
                return 0
            end
            
            if resourceType == "storage" then
                return teamRes[resource].storage
            else
                return teamRes[resource].current
            end
        end,

        GetTeamInfo = function(teamID)
            local info = instance.teamInfo[teamID]
            return info and unpack(info) or 0, 0, 0, false, false, 0, false, false
        end,

        GetPlayerList = function()
            -- Mock player list - return some default players
            return {0, 1}
        end,

        GetPlayerInfo = function(playerID)
            -- Mock player info: name, active, spectator, teamID
            if playerID == 0 then
                return "Player0", true, false, 0
            elseif playerID == 1 then
                return "Player1", true, false, 1
            else
                return "Unknown", false, true, -1
            end
        end
    }
end

return TeamRepositoryBuilder
