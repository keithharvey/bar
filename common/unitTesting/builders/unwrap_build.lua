---@param instance table
---@return table
return function(instance)
    for key, value in pairs(instance) do
        if type(value) == "table" then
            if type(value.Build) == "function" then
                instance[key] = value:Build()
            else
                local n = #value
                if n > 0 then
                    for i = 1, n do
                        local element = value[i]
                        if type(element) == "table" and type(element.Build) == "function" then
                            value[i] = element:Build()
                        end
                    end
                end
            end
        end
    end
    return instance
end


