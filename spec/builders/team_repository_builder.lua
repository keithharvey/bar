-- Team Repository Builder
-- Builds TeamRepository with mocked team operations for testing

---@class TeamRepositoryBuilder
---@field cumulativeMetalSent table
---@field alliedTeams table
---@field teamResources table
---@field teamInfo table
---@field trackedTeams table Teams to set up resources for automatically
---@field pendingAlliance table? Deferred alliance setup until team IDs are assigned

---@class TeamRepositoryMock
---@field GetCumulativeMetalSent fun(teamID: number): number
---@field AddCumulativeMetalSent fun(teamID: number, amount: number): number
---@field AreAlliedTeams fun(team1ID: number, team2ID: number): boolean
---@field SetAlliance fun(team1ID: number, team2ID: number)
---@field GetTeamResources fun(teamID: number, resource: string, resourceType: string|nil): number
---@field GetTeamResourcesData fun(teamID: number): TeamResourcesData
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
        trackedTeams = {},
    }, TeamRepositoryBuilder)
end

local function resolveTeamData(value)
    if type(value) == "table" and type(value.Build) == "function" then
        -- If builder already has an ID (assigned during WithTeam/WithAlliedPlayers), return as-is
        if value.id then
            return value
        else
            -- Otherwise build it to get an ID
            return value:Build()
        end
    end
    return value
end

---Add a team to be tracked for automatic resource setup
---@param self TeamRepositoryBuilder
---@param teamData TeamData|TeamBuilder
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithTeam(teamData)
    -- Check if team is already tracked to avoid duplicates
    for _, trackedTeam in ipairs(self.trackedTeams) do
        if trackedTeam == teamData then
            return self -- Already tracked, return early
        end
    end

    table.insert(self.trackedTeams, teamData)
    return self
end

---Set up alliance between two teams and track them for automatic resource setup
---@param self TeamRepositoryBuilder
---@param team1Data TeamData|TeamBuilder
---@param team2Data TeamData|TeamBuilder
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithAlliedPlayers(team1Data, team2Data)
    -- Store the team builders for deferred alliance setup
    self.pendingAlliance = { team1Data, team2Data }

    -- Track these teams for automatic resource setup (avoid duplicates)
    self:WithTeam(team1Data)
    self:WithTeam(team2Data)

    return self
end

---Alias for WithTeam - add a player/team for resource tracking
---@param self TeamRepositoryBuilder
---@param teamData TeamData|TeamBuilder
---@return TeamRepositoryBuilder
function TeamRepositoryBuilder:WithPlayer(teamData)
    return self:WithTeam(teamData)
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
    if type(self.teamResources[teamID][resource]) ~= "table" then
        self.teamResources[teamID][resource] = { current = 0, storage = 0 }
    end
    self.teamResources[teamID][resource].current = amount
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

    -- Clear existing state to ensure fresh build with late binding
    instance.teamResources = {}
    instance.alliedTeams = {}

    -- Rebuild alliance data from stored builder references (for late binding)
    if instance.pendingAlliance then
        local team1Data = resolveTeamData(instance.pendingAlliance[1])
        local team2Data = resolveTeamData(instance.pendingAlliance[2])


        -- Set up alliance with current team IDs
        instance.alliedTeams[team1Data.id] = instance.alliedTeams[team1Data.id] or {}
        instance.alliedTeams[team2Data.id] = instance.alliedTeams[team2Data.id] or {}
        instance.alliedTeams[team1Data.id][team2Data.id] = true
        instance.alliedTeams[team2Data.id][team1Data.id] = true
    end

    -- Set up resources for all tracked teams (alliance status doesn't matter)
    for _, teamData in ipairs(instance.trackedTeams) do
        local resolvedTeam = resolveTeamData(teamData)

        -- Always update resources to support late binding when builders are modified
        instance.teamResources[resolvedTeam.id] = {
            metal = { current = resolvedTeam.metalAmount, storage = resolvedTeam.metalStorage },
            energy = { current = resolvedTeam.energyAmount, storage = resolvedTeam.energyStorage }
        }
    end

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

        GetTeamResourcesData = function(teamID)
            local teamRes = instance.teamResources[teamID]
            if not teamRes then
                return {
                    metal = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 },
                    energy = { current = 0, storage = 0, pull = 0, income = 0, expense = 0, shareSlider = 0 }
                }
            end

            return {
                metal = {
                    current = teamRes.metal and teamRes.metal.current or 0,
                    storage = teamRes.metal and teamRes.metal.storage or 0,
                    pull = 0,
                    income = 0,
                    expense = 0,
                    shareSlider = 0
                },
                energy = {
                    current = teamRes.energy and teamRes.energy.current or 0,
                    storage = teamRes.energy and teamRes.energy.storage or 0,
                    pull = 0,
                    income = 0,
                    expense = 0,
                    shareSlider = 0
                }
            }
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
