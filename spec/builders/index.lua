local TeamBuilder = require("spec/builders/team_builder")
local SpringRepositoryBuilder = require("spec/builders/spring_repository_builder")
local TeamTransferServiceBuilder = require("spec/builders/team_transfer_service_builder")

---@class Builders
---@field Team TeamBuilder
---@field SpringRepository SpringRepositoryBuilder
---@field TeamTransferService TeamTransferServiceBuilder
local Builders = {
    Team = TeamBuilder,
    SpringRepository = SpringRepositoryBuilder,
    TeamTransferService = TeamTransferServiceBuilder
}

return Builders