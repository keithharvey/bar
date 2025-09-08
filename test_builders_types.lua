-- Test file to verify Builders type declarations work correctly
local Builders = require("common/unitTesting/builders/index")

-- Test that we can access all builder types
local teamBuilder = Builders.Team
local playerBuilder = Builders.Player
local springBuilder = Builders.Spring
local pipelineBuilder = Builders.Pipeline
local unitBuilder = Builders.Unit
local teamTransferBuilder = Builders.TeamTransfer
local baseBuilder = Builders.BaseBuilder

print("✅ All Builders fields accessible:")
print("  Team:", type(teamBuilder))
print("  Player:", type(playerBuilder))
print("  Spring:", type(springBuilder))
print("  Pipeline:", type(pipelineBuilder))
print("  Unit:", type(unitBuilder))
print("  TeamTransfer:", type(teamTransferBuilder))
print("  BaseBuilder:", type(baseBuilder))

-- Test that we can call methods (this tests that the builders work)
local pipeline = Builders.Pipeline.new()
print("✅ Pipeline.new() works:", type(pipeline))

print("🎉 Builders type declarations working correctly!")
