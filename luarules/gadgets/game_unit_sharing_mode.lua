local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name    = 'Unit Sharing Mode',
    desc    = 'Controls which units can be shared with allies',
    author  = 'Rimilel, Attean',
    date    = 'April 2024',
    license = 'GNU GPL, v2 or later',
    layer   = 1,
    enabled = true
  }
end

local ContextFactoryModule = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
local ModOptions = VFS.Include("common/luaUtilities/team_transfer/modoption_enums.lua")
local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local UnitTransfer = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_synced.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_comms.lua")

local POLICY_CACHE_TAINT_FRAME_RATE_HEAVY = 2000

------------------------------------------------
--- Initialization
------------------------------------------------

local contextFactory = ContextFactoryModule.create(Spring)
local unitSharingMode = Spring.GetModOptions()[ModOptions.Options.UnitSharingMode]

local lastGameFrameCacheUpdate = 0

---@param policyContext PolicyContext
---@return UnitTransferPolicyResult
function BuildPolicyCache(policyContext)
  local policyResult = UnitTransfer.GetPolicy(policyContext)
  UnitTransfer.CachePolicyResult(
    Spring,
    policyContext.senderTeamId,
    policyContext.receiverTeamId,
    policyResult
  )
  return policyResult
end

local function InitializeNewTeam(senderTeamId, receiverTeamId)
  local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
  BuildPolicyCache(ctx)
end

function gadget:Initialize()
  local teams = Spring.GetTeamList() or {}
  for _, sender in ipairs(teams) do
    for _, receiver in ipairs(teams) do
      InitializeNewTeam(sender, receiver)
    end
  end
  lastGameFrameCacheUpdate = Spring.GetGameFrame()
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
  if capture then
    return true
  end
  local policyResult = Shared.GetCachedPolicyResult(fromTeamID, toTeamID)
  local given = false
  local transferCtx = contextFactory.unitTransfer(fromTeamID, toTeamID, { unitID }, given, policyResult)

  local result = UnitTransfer.UnitTransfer(transferCtx)
  Comms.SendTransferChatMessages(result, policyResult)

  return false
end

function gadget:GameFrame(frame)
  local nextSchedHeavy = lastGameFrameCacheUpdate + POLICY_CACHE_TAINT_FRAME_RATE_HEAVY
  if frame < nextSchedHeavy then
    return
  end
  local teamList = Spring.GetTeamList() or {}
  lastGameFrameCacheUpdate = frame
  local senderTeamId = Spring.GetMyTeamID()
  -- we also calculate me -> me just so every player has a consistent policy. This is more useful for resources
  for receiverTeamId, _teamInfo in ipairs(teamList) do
    local ctx = contextFactory.policy(senderTeamId, receiverTeamId)
    BuildPolicyCache(ctx)
  end
end
