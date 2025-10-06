-- Type definitions for Team Transfer Unit Testing
-- Thin reference layer for Lua LSP discovery - actual types defined in implementation files
-- This file is for IntelliSense only and should not be executed

---@load-file luaui/types/team_transfer.lua

-- Core data types - defined in respective builder files
---@class PlayerData
---@see common/unitTesting/builders/team_builder.lua
---@class TeamData
---@see common/unitTesting/builders/team_builder.lua
---@class UnitDef
---@see common/unitTesting/builders/unit_builder.lua
---@class SpringMock
---@see common/unitTesting/builders/spring_builder.lua

-- Pipeline and API types
---@class TeamTransferPipeline
---@see common/unitTesting/builders/pipeline_builder.lua
---@class TeamTransferAPI
---@see common/unitTesting/builders/team_transfer_builder.lua

-- Builder classes - defined in respective implementation files
---@class PlayerBuilder
---@see common/unitTesting/builders/team_builder.lua
---@class TeamBuilder
---@see common/unitTesting/builders/team_builder.lua
---@class UnitBuilder
---@see common/unitTesting/builders/unit_builder.lua
---@class SpringBuilder
---@see common/unitTesting/builders/spring_builder.lua
---@class PipelineBuilder
---@see common/unitTesting/builders/pipeline_builder.lua
---@class PipelineBuilderClass
---@field new fun(): PipelineBuilder
---@class TeamTransferBuilder
---@see common/unitTesting/builders/team_transfer_builder.lua

-- Builders namespace with direct navigation properties (following GG pattern from main types)
---@class Builders
---@see common/unitTesting/builders/index.lua

-- Global Builders object (following GG pattern)
Builders = {}

---@type TeamBuilder
Builders.Team = nil
---@see common/unitTesting/builders/team_builder.lua:TeamBuilder

---@type SpringBuilder
Builders.Spring = nil
---@see common/unitTesting/builders/spring_builder.lua:SpringBuilder

---@type PipelineBuilder
Builders.Pipeline = nil
---@see common/unitTesting/builders/pipeline_builder.lua:PipelineBuilder

---@class SpringRepositoryBuilder
---@see common/unitTesting/builders/spring_repository_builder.lua
---@class SpringRepositoryBuilderClass
---@field new fun(): SpringRepositoryBuilder
---@class UnitRepositoryBuilder
---@see common/unitTesting/builders/unit_repository_builder.lua
---@class UnitRepositoryBuilderClass
---@field new fun(): UnitRepositoryBuilder

---@type SpringRepositoryBuilderClass
Builders.SpringRepository = nil
---@see common/unitTesting/builders/spring_repository_builder.lua
---@type UnitRepositoryBuilderClass
Builders.UnitRepository = nil
---@see common/unitTesting/builders/unit_repository_builder.lua

---@type PipelineBuilderClass
Builders.Pipeline = nil

---@type UnitBuilder
Builders.Unit = nil
---@see common/unitTesting/builders/unit_builder.lua:UnitBuilder

---@type TeamTransferBuilder
Builders.TeamTransfer = nil
---@see common/unitTesting/builders/team_transfer_builder.lua:TeamTransferBuilder

-- Sharing Mode Helper types (test-specific)
---@class SharingModeHelper
---@field LoadSharingModes fun(): table<SharingMode, SharingModeConfig>
---@field ValidateSharingModeConfig fun(config: SharingModeConfig): boolean
---@field GetSharingMode fun(key: SharingMode): SharingModeConfig|nil
    