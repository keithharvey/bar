local DSL = VFS.Include("luarules/gadgets/team_transfer/dsl.lua")
local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")
local ModOptions = VFS.Include("luarules/gadgets/team_transfer/modoption_enums.lua")
local PolicyEngine = VFS.Include("modules/policy_engine.lua")

local PolicyCacheRepository = VFS.Include("luarules/gadgets/team_transfer/repositories/policy_cache_repository.lua")
local ContextFactory = VFS.Include("luarules/gadgets/team_transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("luarules/gadgets/team_transfer/actions/resource_transfer.lua")
local UnitTransfer = VFS.Include("luarules/gadgets/team_transfer/actions/unit_transfer.lua")

---@class TeamTransferService
---@field springRepo SpringRepository
---@field policyRepo PolicyRepository
---@field sharingModeRepo SharingModeRepository
---@field engine PolicyEngine
---@field policyCacheRepo PolicyCacheRepository
---@field contextFactory ContextFactory
---@field policyWhitelist? string[]
local TeamTransferService = {}
TeamTransferService.__index = TeamTransferService

---Create a new team transfer service instance
---@param springRepo SpringRepository
---@param policyRepo PolicyRepository
---@return TeamTransferService
function TeamTransferService.new(springRepo, policyRepo, sharingModeRepo, policyWhitelist)
    local engine = PolicyEngine.new()

    DSL.registerDefaults(engine)

    local instance = setmetatable({
        springRepo = springRepo,
        policyRepo = policyRepo,
        sharingModeRepo = sharingModeRepo,
        engine = engine,
        policyCacheRepo = PolicyCacheRepository.new(),
        contextFactory = ContextFactory.create(springRepo),
        policyWhitelist = policyWhitelist,
    }, TeamTransferService)

    instance:LoadEnabledPolicies()

    instance:RunPolicyInitializeHandlers()
    return instance
end

function TeamTransferService:LoadEnabledPolicies()
    local allPolicies = self.policyRepo:GetAllPolicies()
    local count = 0
    for _ in pairs(allPolicies) do count = count + 1 end
    local allPolicies = self.policyRepo:GetAllPolicies()
    local modOptions = self.springRepo:GetModOptions()

    -- Determine which policies to enable
    local policiesToLoad = {}

    if self.policyWhitelist then
        -- used to pass explicit policies to the service during specs
        for _, policyName in ipairs(self.policyWhitelist) do
            local policy = allPolicies[policyName]
            if policy and policy.enabled then
                table.insert(policiesToLoad, policy)
            end
        end
    else
        -- Production mode: load all policies, let their enabled() functions determine activation
        local sharingMode = modOptions[ModOptions.Options.SharingMode]
        if not sharingMode then
            error("TeamTransferService: sharing_mode must be set for data-driven policy loading")
        end

        policiesToLoad = allPolicies
    end

    -- Load the determined policies into the engine
    for name, policy in pairs(policiesToLoad) do
        if policy.enabled then
            ---@type RegisterInitializePolicyContext
            local context = {
                repositories = { springRepo = self.springRepo },
                playerIds = self.springRepo:GetPlayerList()
            }
            local enabled = policy.enabled(context)
            if enabled then
                local builder = DSL.new(self.engine, policy.name, modOptions)
                policy.func(builder)
            end
        end
    end
end

function TeamTransferService:RunPolicyInitializeHandlers()
    ---@type RegisterInitializePolicyContext
    local ctx = {
        repositories = {
            springRepo = self.springRepo
        },
        playerIds = self.springRepo:GetPlayerList(),
    }
    for _, handlerEntry in ipairs(self.engine.initHandlers) do
        local success, err = pcall(function()
            handlerEntry.handler(ctx)
        end)
        if not success and Spring and Spring.Log then
            Spring.Log("TeamTransferService", LOG.ERROR, "Initialization handler failed: " .. tostring(err))
        end
    end
end

---Get expose data for a transfer category
---@param senderTeamID number
---@param receiverTeamID number
---@param transferCategory TransferCategory
---@return table
function TeamTransferService:GetResultCategory(senderTeamID, receiverTeamID, transferCategory)
    local ctx = self.contextFactory.policy(senderTeamID, receiverTeamID)

    -- Evaluate using engine
    local result = self.engine:evaluate(transferCategory, ctx)

    -- Preserve _evaluationPlan if it exists
    local exposeData = result.expose or result
    if result._evaluationPlan then
        exposeData._evaluationPlan = result._evaluationPlan
    end

    return exposeData
end

---Query expose data for all categories
---@param senderTeamID number
---@param receiverTeamID number
---@return CombinedPolicyResult result Combined result
---@return table? plan Evaluation plan
function TeamTransferService:GetResult(senderTeamID, receiverTeamID)
    local gameFrame = self.springRepo:GetGameFrame()

    -- Check cache first
    local cachedResult, cachedPlan = self.policyCacheRepo:GetCachedExpose(senderTeamID, receiverTeamID, gameFrame)
    if cachedResult then
        -- Return cached result with plan data
        ---@cast cachedResult CombinedPolicyResult
        return cachedResult, cachedPlan
    end

    local result = {}
    local combinedPlan = {
        senderTeamId = senderTeamID,
        receiverTeamId = receiverTeamID,
        context = {
            areAlliedTeams = self.springRepo:AreAlliedTeams(senderTeamID, receiverTeamID),
            isCheatingEnabled = self.springRepo:IsCheatingEnabled()
        },
        categories = {}
    }

    -- Get all registered categories dynamically
    ---@type TransferCategory[]
    local categories = {}
    for category, _ in pairs(self.engine.defaultHandlers) do
        table.insert(categories, category)
    end

    for _, category in ipairs(categories) do
        ---@type TransferCategory
        local cat = category
        local exposeData = self:GetResultCategory(senderTeamID, receiverTeamID, cat)

        if exposeData then
            -- Debug: check evaluation plan
            if exposeData._evaluationPlan then
                combinedPlan.categories[category] = exposeData._evaluationPlan
                -- Remove plan from expose data
                exposeData._evaluationPlan = nil
            end

            -- Assign result using category enum value as field name
            result[category] = exposeData
        end
    end

    -- Cache the result with plan before returning
    self.policyCacheRepo:CacheExpose(senderTeamID, receiverTeamID, gameFrame, result, combinedPlan)

    return result, combinedPlan
end


---Evaluate policies for all team pairs to update cache every 300 frames
---@param gameFrame number Current game frame
function TeamTransferService:EvaluateAllTeamPolicies(gameFrame)
    local teams = self.springRepo:GetTeamList()
    if not teams then return end

    -- Forward-only evaluation: only evaluate pairs where sender < receiver
    for i = 1, #teams do
        local senderTeam = teams[i]
        if not senderTeam.isDead then
            for j = i + 1, #teams do
                local receiverTeam = teams[j]
                if not receiverTeam.isDead then
                    -- Evaluate policies for this team pair (this will update cache)
                    self:GetResult(senderTeam.id, receiverTeam.id)
                end
            end
        end
    end
end

---Handle GameFrame updates for cache maintenance
---@param gameFrame number Current game frame
function TeamTransferService:GameFrame(gameFrame)
    self.policyCacheRepo:ClearExpired(gameFrame)

    -- Evaluate all team policies every 300 frames to catch team changes
    if gameFrame % 300 == 0 then
        self:EvaluateAllTeamPolicies(gameFrame)
    end
end

---Validate a resource transfer
---@param senderTeamID number
---@param receiverTeamID number
---@param resourceType ResourceType
---@param amount number
---@return ResourceValidationResult[]
function TeamTransferService:ValidateResourceTransfer(senderTeamID, receiverTeamID, resourceType, amount)
    local transferCategory = (resourceType == SharedEnums.ResourceType.METAL)
        and SharedEnums.TransferCategory.MetalTransfer
        or SharedEnums.TransferCategory.EnergyTransfer

    local policyResults = self:GetResult(senderTeamID, receiverTeamID)
    local resourcePolicyResult = policyResults[transferCategory]
    
    -- Use contextFactory to build validation context
    local validationContext = self.contextFactory.resource(senderTeamID, receiverTeamID, resourceType, amount, resourcePolicyResult)
    
    return self.engine:validateItem(transferCategory, validationContext, function(ctx)
        return ctx
    end)
end

---Validate a unit transfer
---@param senderTeamID number
---@param receiverTeamID number
---@param unitID number
---@param unitDefID number
---@return UnitValidationResult[]
function TeamTransferService:ValidateUnitTransfer(senderTeamID, receiverTeamID, unitID, unitDefID)
    local transferCategory = SharedEnums.TransferCategory.UnitTransfer
    local policyResult = self:GetResultCategory(senderTeamID, receiverTeamID, transferCategory)

    return self.engine:validateItems(transferCategory, {unitID}, function(unitId)
        return self.contextFactory.unit(senderTeamID, receiverTeamID, unitId, policyResult)
    end)
end

---Validate a command (Guard/Repair/Reclaim)
---@param unitID number
---@param unitDefID number
---@param teamID number
---@param cmdID number
---@param cmdParams table
---@param cmdOptions table
---@param cmdTag number
---@param playerID number
---@return boolean allowed, string? reason
function TeamTransferService:ValidateCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID)
    local CMD = self.springRepo.CMD or Spring.CMD

    -- Only validate commands that have target units (Guard, Repair, Reclaim)
    if (cmdID == CMD.GUARD or cmdID == CMD.REPAIR or cmdID == CMD.RECLAIM) and cmdParams and type(cmdParams) == "table" and #cmdParams >= 1 then
        local targetUnitID = cmdParams[1]

        -- Check if target unit exists
        if not self.springRepo.ValidUnitID(targetUnitID) then
            return false, "Invalid target unit"
        end

        local context = self.contextFactory.command(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID)

        local validationResults = self.engine:validateItems(context.transferCategory, {targetUnitID}, function(unitId)
            return context
        end)

        -- Return first validation result (should only be one)
        local result = validationResults[1]
        if result and not result.ok then
            return false, result.reason or "Command validation failed"
        end

        return true
    end

    -- Allow all other commands
    return true
end

---Execute a resource transfer
---@param senderTeamID number
---@param receiverTeamID number
---@param resourceType ResourceType
---@param desiredAmount number
---@return ResourceTransferResult
function TeamTransferService:TransferResource(senderTeamID, receiverTeamID, resourceType, desiredAmount)
    if desiredAmount <= 0 then
        return {
            success = false,
            sent = 0,
            received = 0,
            reason = "Desired amount must be greater than 0"
        }
    end

    local result = self:GetResult(senderTeamID, receiverTeamID)
    local policyResult = (resourceType == SharedEnums.ResourceType.METAL)
        and result[SharedEnums.TransferCategory.MetalTransfer]
        or result[SharedEnums.TransferCategory.EnergyTransfer]

    -- Check if transfer is allowed
    if not policyResult.canShare then
        return {
            success = false,
            sent = 0,
            received = 0,
            blockReason = SharedEnums.BlockReason.PolicyDenied
        }
    end

    local resourceTransferContext = self.contextFactory.resourceTransfer(senderTeamID, receiverTeamID, resourceType, desiredAmount, policyResult)

    local result = ResourceTransfer(resourceTransferContext)

    -- Notify post-transfer hooks if transfer was successful
    if result.success then
        if resourceType == SharedEnums.ResourceType.METAL then
            self:NotifyPostMetalTransfer(result)
        else
            self:NotifyPostEnergyTransfer(result)
        end
    end

    return result
end

---Execute a unit transfer
---@param senderTeamID number
---@param receiverTeamID number
---@param unitIds number[]
---@param given boolean?
---@return UnitTransferResult
function TeamTransferService:TransferUnits(senderTeamID, receiverTeamID, unitIds, given)
    local transferCategory = SharedEnums.TransferCategory.UnitTransfer
    local policyResult = self:GetResultCategory(senderTeamID, receiverTeamID, transferCategory)

    local validationResults = self.engine:validateItems(transferCategory, unitIds, function(unitId)
        return self.contextFactory.unit(senderTeamID, receiverTeamID, unitId, policyResult)
    end)
    
    local unitTransferContext = self.contextFactory.unitTransfer(senderTeamID, receiverTeamID, unitIds, given, policyResult)
    unitTransferContext.validationResults = validationResults
    
    local result = UnitTransfer(unitTransferContext)
    
    if #result.successfulUnitIds > 0 then
        self:NotifyPostUnitTransfer(result)
    end
    
    return result
end

---Simple resource addition without transfer logic (for reclaim, construction, etc.)
---@param teamID number
---@param resourceType ResourceType
---@param amount number
---@return ResourceTransferResult
function TeamTransferService:AddTeamResource(teamID, resourceType, amount)
    local transferCategory = (resourceType == SharedEnums.ResourceType.METAL)
        and SharedEnums.TransferCategory.MetalTransfer
        or SharedEnums.TransferCategory.EnergyTransfer

    local resourcePolicyResult = self:GetResultCategory(teamID, teamID, transferCategory)
    local resourceTransferContext = self.contextFactory.resourceTransfer(teamID, teamID, resourceType, amount, resourcePolicyResult)

    local result = ResourceTransfer(resourceTransferContext)

    if result.success then
        if resourceType == SharedEnums.ResourceType.METAL then
            self:NotifyPostMetalTransfer(result)
        else
            self:NotifyPostEnergyTransfer(result)
        end
    end

    return result
end

---Notify post-metal-transfer hooks
---@param transferResult ResourceTransferResult
function TeamTransferService:NotifyPostMetalTransfer(transferResult)
    local categoryHandlers = self.engine.postActionHandlers[SharedEnums.TransferCategory.MetalTransfer] or {}

    for _, handlerEntry in ipairs(categoryHandlers) do
        local success, err = pcall(function()
            handlerEntry.handler(transferResult, self.springRepo)
        end)
        if not success then
            Spring.Log("TeamTransferService", "ERROR", "Post-metal-transfer handler failed: " .. tostring(err))
        end
    end
end

---Notify post-energy-transfer hooks
---@param transferResult ResourceTransferResult
function TeamTransferService:NotifyPostEnergyTransfer(transferResult)
    local categoryHandlers = self.engine.postActionHandlers[SharedEnums.TransferCategory.EnergyTransfer] or {}

    for _, handlerEntry in ipairs(categoryHandlers) do
        local success, err = pcall(function()
            handlerEntry.handler(transferResult, self.springRepo)
        end)
        if not success then
            Spring.Log("TeamTransferService", "ERROR", "Post-energy-transfer handler failed: " .. tostring(err))
        end
    end
end

---Notify post-unit-transfer hooks
---@param transferResult UnitTransferResult
function TeamTransferService:NotifyPostUnitTransfer(transferResult)
    local categoryHandlers = self.engine.postActionHandlers[SharedEnums.TransferCategory.UnitTransfer] or {}

    for _, handlerEntry in ipairs(categoryHandlers) do
        local success, err = pcall(function()
            local context = {
                transferResult = transferResult,
                repositories = {
                    springRepo = self.springRepo
                }
            }
            handlerEntry.handler(context)
        end)
        if not success then
            Spring.Log("TeamTransferService", "ERROR", "Post-unit-transfer handler failed: " .. tostring(err))
        end
    end
end

return TeamTransferService
