local M = {}

local pipeline = {
	onAllowResourceTransfer = {},
	onAllowUnitTransfer = {},
	onAllowCommand = {},
}

function M.RegisterAllowResourceTransfer(fn)
	pipeline.onAllowResourceTransfer[#pipeline.onAllowResourceTransfer + 1] = fn
end

function M.RegisterAllowUnitTransfer(fn)
	pipeline.onAllowUnitTransfer[#pipeline.onAllowUnitTransfer + 1] = fn
end

function M.RegisterAllowCommand(fn)
	pipeline.onAllowCommand[#pipeline.onAllowCommand + 1] = fn
end

function M.GetPipeline()
	return pipeline
end

return M
