describe("Widget Helpers", function()
    local WidgetHelpers

    before_each(function()
        WidgetHelpers = require("luaui.Include.widget_helpers.index")
    end)

    it("should load the widget helpers module", function()
        assert.is_table(WidgetHelpers)
    end)

    -- Add more tests for specific helpers here
    -- it("should provide my_helper functionality", function()
    --     assert.is_function(WidgetHelpers.myHelper.someFunction)
    -- end)
end)
