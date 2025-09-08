---@class BaseBuilder<T>
local BaseBuilder = {}
local unwrapBuild = require("common/unitTesting/builders/unwrap_build")

---Helper function to create a builder instance (internal use only)
---@param defaultData table Default data for new instances
---@param methods table<string, function> Methods that mutate the instance
---@param buildFunction function The function to call for the Build method
---@param customData table? Optional custom data to override defaults
---@return table builder instance with fluent interface
local function createBuilderInstance(defaultData, methods, buildFunction, customData)
    customData = customData or {}
    local instance = {}

    -- Merge default data with custom data
    for k, v in pairs(defaultData) do
        instance[k] = v
    end
    for k, v in pairs(customData) do
        instance[k] = v
    end

    -- Add fluent methods that mutate the instance
    for methodName, methodFn in pairs(methods) do
        instance[methodName] = function(...)
            return methodFn(instance, ...)
        end
    end

    -- Add the standard Build method
    instance.Build = function(...)
        unwrapBuild(instance)
        return buildFunction(instance, ...)
    end

    return instance
end

-- Export the helper function for use by individual builders
BaseBuilder.createInstance = createBuilderInstance

---Creates a complete builder with automatic static factory methods
---@param config table Configuration for the builder
---@param config.defaultData table Default data for new instances
---@param config.methods table<string, function> Methods that mutate the instance
---@param config.buildFunction function The function to call for the Build method
---@param config.className string Name of the builder class for type annotations
---@param config.staticMethods? table<string, function> Optional static methods to add (for explicit control)
---@return BaseBuilder<T>
function BaseBuilder.createBuilder(config)
    local BuilderClass = {}

    -- Store configuration for later use
    BuilderClass._config = config

    -- Create the build function
    local buildFunction = config.buildFunction

    -- Auto-generate static factory methods from fluent methods
    for methodName, methodFn in pairs(config.methods) do
        if methodName ~= "Build" then
            BuilderClass[methodName] = function(...)
                local instance = createBuilderInstance(config.defaultData, config.methods, buildFunction)
                return instance[methodName](...)
            end
        end
    end

    -- Add explicit static methods if provided (for more control like SpringBuilder pattern)
    if config.staticMethods then
        for methodName, methodFn in pairs(config.staticMethods) do
            BuilderClass[methodName] = methodFn
        end
    end

    -- Add static Build method for convenience
    BuilderClass.Build = function()
        return createBuilderInstance(config.defaultData, config.methods, buildFunction).Build()
    end

    -- Add explicit new() method
    BuilderClass.new = function()
        return createBuilderInstance(config.defaultData, config.methods, buildFunction)
    end

    return BuilderClass
end

---Creates a builder using the SpringBuilder static method pattern
---This gives explicit control over which methods become static (like SpringBuilder)
---@param config table Configuration for the builder
---@param config.defaultData table Default data for new instances
---@param config.fluentMethods table<string, function> Methods that mutate the instance
---@param config.staticMethods table<string, function> Static methods to add to the class
---@param config.buildFunction function The function to call for the Build method
---@param config.className string Name of the builder class for type annotations
---@return BaseBuilder<T>
function BaseBuilder.createBuilderWithStaticMethods(config)
    local BuilderClass = {}

    -- Store configuration for later use
    BuilderClass._config = config

    -- Add static methods (explicit control like SpringBuilder)
    for methodName, methodFn in pairs(config.staticMethods) do
        BuilderClass[methodName] = methodFn
    end

    -- Add explicit new() method that creates instance and attaches fluent methods
    BuilderClass.new = function()
        local instance = {}

        -- Copy default data
        for k, v in pairs(config.defaultData) do
            instance[k] = v
        end

        -- Attach fluent methods to the instance
        for methodName, methodFn in pairs(config.fluentMethods) do
            instance[methodName] = methodFn
        end

        -- Attach Build method
        instance.Build = function(...)
            unwrapBuild(instance)
            return config.buildFunction(instance, ...)
        end

        return instance
    end

    -- Add convenience Build method
    BuilderClass.Build = function()
        return BuilderClass.new().Build()
    end

    return BuilderClass
end

return BaseBuilder
