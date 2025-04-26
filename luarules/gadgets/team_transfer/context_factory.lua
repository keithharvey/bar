-- Context Factory with Closures
-- Functions that capture repositories in closures for cleaner APIs

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class ContextFactory
---@field create fun(springRepo: SpringRepository): ContextFactory
---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
---@field unit fun(senderTeamID: number, receiverTeamID: number, unitID: number, policyResult: UnitTransferPolicyResult): UnitTransferPolicyContext
---@field resource fun(senderTeamId: number, receiverTeamId: number, resourceType: string, amount: number, policyResult: ResourcePolicyResult): ResourceTransferPolicyContext
---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean?, policyResult: UnitTransferPolicyResult): UnitTransferContext
---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field commandValidation fun(senderTeamID: number, receiverTeamID: number, commandType: string, commandParams: table): CommandValidationContext
local ContextFactory = {}

---Create a context factory with repositories captured in closures
---@param springRepo SpringRepository
---@return table Context factory with closures
function ContextFactory.create(springRepo)
    ---Create context with optional extensions
    ---@param senderTeamID number
    ---@param receiverTeamID number
    ---@param extensions? table Additional fields to merge
    ---@return table Context
    local function buildContext(senderTeamID, receiverTeamID, extensions)
        -- Get resource data using the single source of truth
        local senderMetal = springRepo:GetTeamResourcesUnpacked(senderTeamID, SharedEnums.ResourceType.METAL)
        local senderEnergy = springRepo:GetTeamResourcesUnpacked(senderTeamID, SharedEnums.ResourceType.ENERGY)
        local receiverMetal = springRepo:GetTeamResourcesUnpacked(receiverTeamID, SharedEnums.ResourceType.METAL)
        local receiverEnergy = springRepo:GetTeamResourcesUnpacked(receiverTeamID, SharedEnums.ResourceType.ENERGY)

        ---@type TeamResources
        local senderResources = {
            metal = senderMetal,
            energy = senderEnergy
        }

        ---@type TeamResources
        local receiverResources = {
            metal = receiverMetal,
            energy = receiverEnergy
        }

        ---@type ContextRepositories
        local repositories = {
            springRepo = springRepo,
        }

        ---@type PolicyContext
        local ctx = {
            senderTeamId = senderTeamID,
            receiverTeamId = receiverTeamID,
            resultSoFar = {},
            sender = senderResources,
            receiver = receiverResources,
            repositories = repositories,
            areAlliedTeams = springRepo:AreAlliedTeams(senderTeamID, receiverTeamID),
            isCheatingEnabled = springRepo:IsCheatingEnabled()
        }

        -- Merge extensions if provided
        if extensions then
            for k, v in pairs(extensions) do
                ctx[k] = v
            end
        end

        return ctx
    end

    ---Create policy context
    ---@param senderTeamID number
    ---@param receiverTeamID number
    ---@param commandType? string
    ---@return PolicyContext
    local function policy(senderTeamID, receiverTeamID, commandType)
        return buildContext(senderTeamID, receiverTeamID, {
            commandType = commandType
        })
    end

    ---Create action context
    ---@param transferCategory string
    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@return PolicyActionContext
    local function action(senderTeamId, receiverTeamId, transferCategory)
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory
        })
    end

    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@param unitId number
    ---@param policyResult UnitTransferPolicyResult
    ---@return UnitTransferPolicyContext
    local function unit(senderTeamId, receiverTeamId, unitId, policyResult)
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = SharedEnums.TransferCategory.UnitTransfer,
            unitID = unitId,
            policyResult = policyResult
        })
    end

    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@param resourceType ResourceType
    ---@param amount number
    ---@param policyResult ResourcePolicyResult
    ---@return ResourceTransferPolicyContext
    local function resource(senderTeamId, receiverTeamId, resourceType, amount, policyResult)
        local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory,
            resource = resourceType,
            amount = amount,
            policyResult = policyResult
        })
    end

    ---Create unit transfer context for transfer actions
    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@param unitIds number[]
    ---@param given boolean?
    ---@param policyResult UnitTransferPolicyResult
    ---@return UnitTransferContext
    local function unitTransfer(senderTeamId, receiverTeamId, unitIds, given, policyResult)
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = SharedEnums.TransferCategory.UnitTransfer,
            unitIds = unitIds,
            given = given,
            policyResult = policyResult
        })
    end

    ---Create resource transfer context for transfer actions
    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@param resourceType ResourceType
    ---@param desiredAmount number
    ---@param policyResult ResourcePolicyResult
    ---@return ResourceTransferContext
    local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
        local transferCategory = resourceType == SharedEnums.ResourceType.METAL 
            and SharedEnums.TransferCategory.MetalTransfer 
            or SharedEnums.TransferCategory.EnergyTransfer
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory,
            resourceType = resourceType,
            desiredAmount = desiredAmount,
            policyResult = policyResult
        })
    end

    ---Create command validation context
    ---@param senderTeamID number
    ---@param receiverTeamID number
    ---@param commandType string
    ---@param commandParams? table
    ---@return CommandValidationPolicyContext
    local function commandValidation(senderTeamID, receiverTeamID, commandType, commandParams)
        return buildContext(senderTeamID, receiverTeamID, {
            transferCategory = commandType,
            commandParams = commandParams
        })
    end

    ---@param senderTeamID number
    ---@param targetUnitID number
    ---@param targetUnitDef table
    ---@return GuardTransferContext
    local function guard(senderTeamID, targetUnitID, targetUnitDef)
        local targetTeamID = springRepo:GetUnitTeam(targetUnitID)
        return buildContext(senderTeamID, targetTeamID, {
            transferCategory = SharedEnums.TransferCategory.GuardTransfer,
            targetUnitID = targetUnitID,
            targetUnitDef = targetUnitDef
        })
    end

    ---@param senderTeamID number
    ---@param targetUnitID number
    ---@param targetUnitDef table
    ---@return RepairTransferContext
    local function repair(senderTeamID, targetUnitID, targetUnitDef)
        local targetTeamID = springRepo:GetUnitTeam(targetUnitID)
        return buildContext(senderTeamID, targetTeamID, {
            transferCategory = SharedEnums.TransferCategory.RepairTransfer,
            targetUnitID = targetUnitID,
            targetUnitDef = targetUnitDef
        })
    end

    return {
        policy = policy,
        action = action,
        unit = unit,
        resource = resource,
        unitTransfer = unitTransfer,
        resourceTransfer = resourceTransfer,
        commandValidation = commandValidation,
        guard = guard,
        repair = repair
    }
end

return ContextFactory
