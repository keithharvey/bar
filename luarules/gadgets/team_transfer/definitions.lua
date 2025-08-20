local M = {}

M.PolicyType = {
	ResourceTransfer = "ResourceTransfer",
	UnitTransfer = "UnitTransfer",
	Command = "Command",
}

M.SharingOutcomes = {
	EnergyTransfer = "EnergyTransfer",
	MetalTransfer = "MetalTransfer",
	BuildAssist = "BuildAssist",
	UnitTransfer = "UnitTransfer",
}

M.SharingTriggerUnits = {
	EnergyStorage = "EnergyStorage",
	MetalStorage = "MetalStorage",
	Pinpointer = "Pinpointer",
}

return M
