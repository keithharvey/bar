local TeamBuilder = require("spec/builders/team_builder")
local SpringBuilder = require("spec/builders/spring_builder")
local PipelineBuilder = require("spec/builders/pipeline_builder")
local UnitBuilder = require("spec/builders/unit_builder")
local UnitRepositoryBuilder = require("spec/builders/unit_repository_builder")
local TeamRepositoryBuilder = require("spec/builders/team_repository_builder")
local SpringRepositoryBuilder = require("spec/builders/spring_repository_builder")
local TeamTransferBuilder = require("spec/builders/team_transfer_builder")
local PolicyRepositoryBuilder = require("spec/builders/policy_repository_builder")

---@class Builders
---@field Team TeamBuilder
---@field Spring SpringBuilder
---@field Pipeline PipelineBuilder
---@field Unit UnitBuilder
---@field UnitRepository UnitRepositoryBuilder
---@field TeamRepository TeamRepositoryBuilder
---@field SpringRepository SpringRepositoryBuilder
---@field TeamTransfer TeamTransferBuilder
---@field Policy PolicyBuilder
---@field PolicyRepository PolicyRepositoryBuilder
local Builders = {
    Team = TeamBuilder,
    Spring = SpringBuilder,
    Pipeline = PipelineBuilder,
    Unit = UnitBuilder,
    UnitRepository = UnitRepositoryBuilder,
    TeamRepository = TeamRepositoryBuilder,
    SpringRepository = SpringRepositoryBuilder,
    TeamTransfer = TeamTransferBuilder,
    PolicyRepository = PolicyRepositoryBuilder
}

return Builders