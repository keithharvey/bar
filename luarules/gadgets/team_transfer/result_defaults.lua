-- Default result shapes for transfer categories

local M = {}

function M.Metal()
  return {
    maxMetalShareAmount = 0,
    canShareMetal = false,
    blockReason = nil,
    taxRate = nil,
    metalThreshold = nil,
    amountAlreadySent = nil,
    amountRemainingAllowance = nil,
  }
end

function M.Energy()
  return {
    maxEnergyShareAmount = 0,
    canShareEnergy = false,
    blockReason = nil,
    taxRate = nil,
    energyThreshold = nil,
    amountAlreadySent = nil,
    amountRemainingAllowance = nil,
  }
end

function M.Unit()
  return {
    canShareUnits = false,
    blockReason = nil,
  }
end

function M.Command()
  return {
    allowGuardCommands = true,
    allowRepairCommands = true,
    allowReclaimCommands = true,
    blockReason = nil,
  }
end

return M


