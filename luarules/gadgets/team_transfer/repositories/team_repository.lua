---@class TeamRepository
---@field GetCumulativeMetalSent fun(teamID: number): number
---@field AddCumulativeMetalSent fun(teamID: number, amount: number): number
---@field AreAlliedTeams fun(team1ID: number, team2ID: number): boolean
---@field GetTeamResources fun(teamID: number, resource: string): number
---@field GetTeamInfo fun(teamID: number): number, number, number, boolean, boolean, number, boolean, boolean

local TeamRepository = {}

local cumulativeMetalSent = {}
local alliedTeams = {}

---Get cumulative metal sent for a team
---@param teamID number
---@return number
function TeamRepository.GetCumulativeMetalSent(teamID)
    return cumulativeMetalSent[teamID] or 0
end

---Add to cumulative metal sent for a team
---@param teamID number
---@param amount number
---@return number newTotal
function TeamRepository.AddCumulativeMetalSent(teamID, amount)
    local current = cumulativeMetalSent[teamID] or 0
    local newTotal = current + (amount or 0)
    cumulativeMetalSent[teamID] = newTotal
    return newTotal
end

---Check if two teams are allied
---@param team1ID number
---@param team2ID number
---@return boolean
function TeamRepository.AreAlliedTeams(team1ID, team2ID)
    if team1ID == team2ID then return true end
    return alliedTeams[team1ID] and alliedTeams[team1ID][team2ID] or false
end

---Set alliance between two teams
---@param team1ID number
---@param team2ID number
function TeamRepository.SetAlliance(team1ID, team2ID)
    alliedTeams[team1ID] = alliedTeams[team1ID] or {}
    alliedTeams[team2ID] = alliedTeams[team2ID] or {}
    alliedTeams[team1ID][team2ID] = true
    alliedTeams[team2ID][team1ID] = true
end

---Get team resources
---@param teamID number
---@param resource string
---@param resourceType string? "storage" for storage capacity, nil for current amount
---@return number
function TeamRepository.GetTeamResources(teamID, resource, resourceType)
    if resourceType == "storage" then
        local _, storage = Spring.GetTeamResources(teamID, resource)
        return storage
    else
        local current = Spring.GetTeamResources(teamID, resource)
        return current
    end
end

---Get team info
---@param teamID number
---@return number, number, number, boolean, boolean, number, boolean, boolean
function TeamRepository.GetTeamInfo(teamID)
    local teamID_ret, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys = Spring.GetTeamInfo(teamID)
    return teamID_ret, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys
end

---Compute take bypass (receiver has no active players)
---@param fromTeamID number
---@param toTeamID number
---@return boolean
function TeamRepository.computeTakeBypass(fromTeamID, toTeamID)
    if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
        for _, playerID in ipairs(Spring.GetPlayerList()) do
            local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
            if active and not spectator and teamID == fromTeamID then
                return false
            end
        end
        return true
    end
    return false
end

return TeamRepository
