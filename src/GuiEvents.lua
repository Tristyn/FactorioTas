-- relays the stream of gui element events to callbacks that are subscribed to those elements

local Delegate = require("Delegate")

local GuiEvents = { }
local metatable = { __index = GuiEvents }

function GuiEvents.set_metatable(instance)
    if getmetatable(instance) ~= nil then return end

    setmetatable(instance, metatable)

    -- I don't like type guessing but it's a quick solution for getting save/load implemented
    for k, callback in pairs(instance._click_event_callbacks) do
        if type(callback) == "table" then
            Delegate.set_metatable(callback)
        end
    end
    for k, callback in pairs(instance._check_changed_callbacks) do
        if type(callback) == "table" then
            Delegate.set_metatable(callback)
        end
    end
    for k, callback in pairs(instance._dropdown_selection_state_changed_callbacks) do
        if type(callback) == "table" then
            Delegate.set_metatable(callback)
        end
    end

end

function GuiEvents.new()
    local new = {
        _click_event_callbacks = { },
        _check_changed_callbacks = { },
        _dropdown_selection_state_changed_callbacks = { }
    }

    GuiEvents.set_metatable(new)

    return new
end

--[Comment]
--Invokes `callback(event)` when a LuaGuiElement `element` is clicked.
--argument `event` is a table that contains:
---element :: LuaGuiElement: The clicked element.
---player_index :: uint: The player who did the clicking.
function GuiEvents:register_click_callback(element, callback)
    fail_if_invalid(element)
    fail_if_missing(callback)

    local callbacks = self._click_event_callbacks

    if element.name == "" or callbacks[element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[element.name] = callback
end

--[Comment]
--Gui:unregister_click_callbacks(element_1, element_2, ...) or int indexed array
function GuiEvents:unregister_click_callbacks(...)
    fail_if_missing(...)

    for _, element in ipairs(...) do
        self._click_event_callbacks[element.name] = nil
    end
end

function GuiEvents:on_click(event)
    fail_if_missing(event)

    local callback = self._click_event_callbacks[event.element.name]
    if callback ~= nil then
        callback:invoke(event)
    end

end

function GuiEvents:register_check_changed_callback(checkbox_element, callback)
    fail_if_invalid(checkbox_element)
    fail_if_missing(callback)

    local callbacks = self._check_changed_callbacks

    if checkbox_element.name == "" or callbacks[checkbox_element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[checkbox_element.name] = callback
end

function GuiEvents:unregister_check_changed_callbacks(...)
    fail_if_missing(...)

    local callbacks = self._check_changed_callbacks
    for _, element in ipairs(...) do
        callbacks[element.name] = nil
    end
end

function GuiEvents:on_check_changed(event)
    fail_if_missing(event)

    local element = event.element
    local callback = self._check_changed_callbacks[element.name]
    if callback ~= nil then
        callback:invoke(event)
    end
end

function GuiEvents:register_dropdown_selection_changed_callback(dropdown_element, callback)
    fail_if_invalid(dropdown_element)
    fail_if_missing(callback)

    local callbacks = self._dropdown_selection_state_changed_callbacks

    if dropdown_element.name == "" or callbacks[dropdown_element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[dropdown_element.name] = callback
end

function GuiEvents:unregister_dropdown_selection_changed_callbacks(...)
    fail_if_missing(...)

    local callbacks = self._dropdown_selection_state_changed_callbacks
    for _, element in ipairs(...) do
        callbacks[element.name] = nil
    end
end

function GuiEvents:on_dropdown_selection_changed(event)
    fail_if_missing(event)

    local element = event.element
    local player_index = event.player_index

    local callback = self._dropdown_selection_state_changed_callbacks[element.name]
    if callback ~= nil then
        callback:invoke(event)
    end
end

return GuiEvents