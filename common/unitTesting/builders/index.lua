local TeamBuilder = require("common/unitTesting/builders/team_builder")
local SpringBuilder = require("common/unitTesting/builders/spring_builder")
local PipelineBuilder = require("common/unitTesting/builders/pipeline_builder")
local UnitBuilder = require("common/unitTesting/builders/unit_builder")
local UnitRepositoryBuilder = require("common/unitTesting/builders/unit_repository_builder")
local TeamRepositoryBuilder = require("common/unitTesting/builders/team_repository_builder")
local SpringRepositoryBuilder = require("common/unitTesting/builders/spring_repository_builder")
local TeamTransferBuilder = require("common/unitTesting/builders/team_transfer_builder")
local PolicyRepositoryBuilder = require("common/unitTesting/builders/policy_repository_builder")

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