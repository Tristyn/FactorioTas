require("Globals")

local Tas = require("Tas");

require("util")
local Gui = require("Gui")
local GuiEvents = require("GuiEvents")

inspect = require("inspect")

script.on_init( function()
    -- Dont capture and print error, players won't see it as they haven't been added to the game
    -- Instead collect the traceback in err and rethrow to display it in the main menu.
    local _, err = xpcall(function()
        log_error({"TAS-info-generic", "Calling script.on_init"}, true)
        Tas.init_globals()
        util.init_globals()
        global.gui_events = GuiEvents.new()
        global.gui = Gui.new(global.gui_events)


        Gui.set_metatable(global.gui)
        -- this is totally optional and increases load time, but catches some loading bugs

    end, debug.traceback, event)

    if err then
        error(err)
    end
end )

script.on_load( function()
    -- Dont capture and print error, printing will result in another error because `game` is nil.
    -- (resulting in loss of the initial stacktrace).
    -- Instead collect the traceback in err and rethrow to display it in the main menu.
    local _, err = xpcall(function() 
        log_error({"TAS-info-generic", "Calling script.on_load"}, true)
        Gui.set_metatable(global.gui)
    end, debug.traceback, event)
    
    if err then
        error(err)
    end
end )

script.on_event(defines.events.on_player_created, function(event)
    local _, err = xpcall(function(event)
        global.gui:init_player(event.player_index)
    end, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_player_created", err } end
end )

script.on_event(defines.events.on_gui_click, function(event)
    local _, err = xpcall(function (event)
        global.gui_events:on_click(event)
        -- gui:on_click is deprecated, use gui_events in the future
        global.gui:on_click(event)
    end, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_gui_click", err } end
end )

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local _, err = xpcall(function (event) global.gui_events:on_check_changed(event) end, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_check_changed", err } end
end )

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local _, err = xpcall(function (event) global.gui_events:on_dropdown_selection_changed(event) end, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_dropdown_selection_changed", err } end
end )

script.on_event(defines.events.on_built_entity, function(event)
    local _, err = xpcall(Tas.on_built_entity, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_built_entity", err } end
end )

script.on_event(defines.events.on_pre_player_mined_item, function(event)
    local _, err = xpcall(Tas.on_pre_mined_entity, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_preplayer_mined_item", err } end
end )

script.on_event(defines.events.on_robot_pre_mined, function(event)
    local _, err = xpcall(Tas.on_pre_mined_entity, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_robot_pre_mined", err } end
end )

script.on_event(defines.events.on_player_crafted_item, function(event)
    local _, err = xpcall(Tas.on_crafted_item, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_crafted_item", err } end
end )

script.on_event("tas-select-hotkey", function(event)
    local _, err = xpcall(Tas.on_left_click, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "tas-select-hotkey", err } end
end )

script.on_event(defines.events.on_tick, function(event)
    local _, err = xpcall(Tas.on_tick, debug.traceback, event)
    if err then log_error { "TAS-exception-specific", "on_tick", err } end
end )