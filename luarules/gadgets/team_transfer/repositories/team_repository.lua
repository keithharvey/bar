---@class TeamRepository
---@field GetCumulativeMetalSent fun(teamID: number): number
---@field AddCumulativeMetalSent fun(teamID: number, amount: number): number
---@field AreAlliedTeams fun(team1ID: number, team2ID: number): boolean
---@field SetAlliance fun(team1ID: number, team2ID: number)
---@field GetTeamResources fun(teamID: number, resource: string, resourceType: string|nil): number
---@field GetTeamInfo fun(teamID: number): number, number, boolean, boolean, any, number, number, table|nil
---@field GetPlayerList fun(): number[]
---@field GetPlayerInfo fun(playerID: number, includeAI: boolean|nil): string, boolean, boolean, number

local TeamRepository = {}
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

local cumulativeMetalSent = {}
local alliedTeams = {}

---Get cumulative metal sent for a team
---@param teamID number
---@return number
function TeamRepository.GetCumulativeMetalSent(teamID)
    local val = Spring.GetGameRulesParam and Spring.GetGameRulesParam("TT_CUM_METAL_" .. tostring(teamID))
    if type(val) == "number" then return val end
    return cumulativeMetalSent[teamID] or 0
end

---Add to cumulative metal sent for a team
---@param teamID number
---@param amount number
---@return number newTotal
function TeamRepository.AddCumulativeMetalSent(teamID, amount)
    local current = TeamRepository.GetCumulativeMetalSent(teamID)
    local newTotal = current + (amount or 0)
    if Spring.SetGameRulesParam then
        Spring.SetGameRulesParam("TT_CUM_METAL_" .. tostring(teamID), newTotal)
    else
        cumulativeMetalSent[teamID] = newTotal
    end
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
    return teamID_ret or teamID, leader or -1, not not isDead, not not isAiTeam, side, allyTeam or -1, incomeMultiplier or 1, customTeamKeys
end

---Compute take bypass (receiver has no active players)
---@param fromTeamID number
---@param toTeamID number
---@return boolean
function TeamRepository.computeTakeBypass(fromTeamID, toTeamID)
    if Spring.AreTeamsAllied(fromTeamID, toTeamID) then
        local list = Spring.GetPlayerList() or {}
        for _, playerID in ipairs(list) do
            local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
            if active and not spectator and teamID == fromTeamID then
                return false
            end
        end
        return true
    end
    return false
end

---Pass-throughs for consistency with mocks
---@return number[]
function TeamRepository.GetPlayerList()
    return Spring.GetPlayerList() or {}
end

---@param playerID number
---@param includeAI boolean|nil
---@return string, boolean, boolean, number
function TeamRepository.GetPlayerInfo(playerID, includeAI)
    return Spring.GetPlayerInfo(playerID, includeAI or false)
end

---Compute maximum shareable amount for a resource type
---@param receiverTeamID number
---@param resourceName string
---@return number, number maxShare, receiverCurrent
function TeamRepository.ComputeMaxShare(receiverTeamID, resourceName)
    if not receiverTeamID or not resourceName then
        return 0, 0
    end
    local current, storage, _, _, _, shareSlider = Spring.GetTeamResources(receiverTeamID, resourceName)
    if not current or not storage or not shareSlider then
        return 0, 0
    end
    local maxShare = math.max(0, (storage * shareSlider) - current)
    return maxShare, current
end

---Get complete resource data for a team (both metal and energy)
---@param teamID number
---@return TeamResourcesData
function TeamRepository.GetTeamResourcesData(teamID)
    if not teamID or teamID < 0 then
        return {
            metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
            energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
        }
    end

    local metalResourceType = SharedEnums.ResourceType.METAL or "metal"
    local energyResourceType = SharedEnums.ResourceType.ENERGY or "energy"

    local sMCur, sMStor, sMPull, sMInc, sMExp, sMShare = Spring.GetTeamResources(teamID, metalResourceType)
    local sECur, sEStor, sEPull, sEInc, sEExp, sEShare = Spring.GetTeamResources(teamID, energyResourceType)

    return {
        metal = {
            current = sMCur or 0,
            storage = sMStor or 0,
            pull = sMPull or 0,
            income = sMInc or 0,
            expense = sMExp or 0,
            shareSlider = sMShare or 0
        },
        energy = {
            current = sECur or 0,
            storage = sEStor or 0,
            pull = sEPull or 0,
            income = sEInc or 0,
            expense = sEExp or 0,
            shareSlider = sEShare or 0
        }
    }
end

return TeamRepository
