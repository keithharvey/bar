-- Team Transfer Policy: Enemy Transfer
-- Handles resource and unit transfers between enemy teams

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

-- Shared logging utility
local Logger = VFS.Include("luarules/gadgets/team_transfer/shared_logging.lua")
Logger.SetLogMode("NONE")  -- Set to "NONE" to disable all logging, "ERROR" for errors only, "DEBUG" for all

local LogDebug = Logger.LogDebug
local LogInfo = Logger.LogInfo
local LogError = Logger.LogError

LogDebug("Loading enemy transfer policy")

local function shouldAllowResourceTransfer(ctx)
	return ctx.isCheatingEnabled or ctx.senderIsNonPlayer or ctx.receiverIsNonPlayer
end

local function shouldAllowUnitTransfer(ctx)
	if ctx.capture then
		return true
	end
	return ctx.isCheatingEnabled or ctx.fromIsNonPlayer or ctx.toIsNonPlayer
end

GG.TeamTransfer.RegisterPolicy(SharedEnums.Policies.EnemyTransfer, function(policy)
	policy.ForEnemyMetalTransfers.Use(function(ctx)
		LogDebug("Enemy metal transfer policy called")
		if shouldAllowResourceTransfer(ctx) then
			-- Use default calculations but cap at 1000 for enemy transfers
			local maxAmount = math.min(ctx.defaultMetalTransfer.amountSendable, 1000)
			---@type EnemyMetalTransferResult
			local metalExpose = {
				amountSendable = maxAmount,  -- Required by DefaultMetalTransferResult
				blockReason = nil,
				amountRemainingAllowance = maxAmount -- Common concept on base type
			}
			
			return {
				allow = true,
				expose = {
					[SharedEnums.TransferCategory.MetalTransfer] = metalExpose
				}
			}
		end
		---@type EnemyMetalTransferResult
		local metalExpose = {
			amountSendable = 0,  -- Required by DefaultMetalTransferResult
			blockReason = "Enemy metal transfer not allowed",
			amountRemainingAllowance = 0 -- Common concept on base type
		}
		
		return {
			deny = true,
			expose = {
				[SharedEnums.TransferCategory.MetalTransfer] = metalExpose
			}
		}
	end)
	
	policy.ForEnemyEnergyTransfers.Use(function(ctx)
		LogDebug("Enemy energy transfer policy called")
		if shouldAllowResourceTransfer(ctx) then
			-- Use default calculations but cap at 1000 for enemy transfers
			local maxAmount = math.min(ctx.defaultEnergyTransfer.amountSendable, 1000)
			---@type EnemyEnergyTransferResult
			local energyExpose = {
				amountSendable = maxAmount,  -- Required by DefaultEnergyTransferResult
				blockReason = nil,
				amountRemainingAllowance = maxAmount -- Common concept on base type
			}
			
			return {
				allow = true,
				expose = {
					[SharedEnums.TransferCategory.EnergyTransfer] = energyExpose
				}
			}
		end
		---@type EnemyEnergyTransferResult
		local energyExpose = {
			canShare = false,
			amountSendable = 0,  -- Required by DefaultEnergyTransferResult
			blockReason = "Enemy energy transfer not allowed",
			amountRemainingAllowance = 0 -- Common concept on base type
		}
		
		return {
			deny = true,
			expose = {
				[SharedEnums.TransferCategory.EnergyTransfer] = energyExpose
			}
		}
	end)

	policy.ForEnemyUnitTransfers.Use(function(ctx)
		LogDebug("Enemy unit transfer policy called")
		if shouldAllowUnitTransfer(ctx) then
			-- Use default unit transfer calculations for enemy transfers
			---@type EnemyUnitTransferResult
			local unitExpose = {
				canShareUnits = ctx.defaultUnitTransfer.canShareUnits,  -- Required by DefaultUnitTransferResult
				blockReason = nil
			}
			
			return {
				allow = true,
				expose = {
					[SharedEnums.TransferCategory.UnitTransfer] = unitExpose
				}
			}
		end
		---@type EnemyUnitTransferResult
		local unitExpose = {
			canShareUnits = false,  -- Required by DefaultUnitTransferResult
			blockReason = "Enemy transfer not allowed"
		}
		
		return {
			deny = true,
			expose = {
				[SharedEnums.TransferCategory.UnitTransfer] = unitExpose
			}
		}
	end)
end)
