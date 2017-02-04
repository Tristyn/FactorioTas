require "util"
require "tas"
require "gui"
require "runner"

inspect = require "inspect"
json = require "JSON"

function msg_all(message)
    for _, p in pairs(game.players) do
        p.print(message)
    end
end

-- error if the argument evaluates to false or nil
function fail_if_missing(var, msg)
    if not var then
        if msg then
            error(msg, 3)
        else
            error("Missing value", 3)
        end
    end
    return false
end

script.on_init( function()
    local _, err = xpcall( function()
        tas.init_globals()
        util.init_globals()
        tas.runner.init_globals()
        tas.gui.init_globals()
    end , debug.traceback)
    if err then msg_all( { "TAS-err-generic", err }) end
end )

script.on_event(defines.events.on_player_created, function(event)
    local _, err = xpcall(tas.on_player_created, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_player_created", err }) end
end )

script.on_event(defines.events.on_gui_click, function(event)
    local _, err = xpcall(tas.gui.on_click, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_gui_click", err }) end
end )

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local _, err = xpcall(tas.gui.on_check_changed, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_check_changed", err }) end
end)

script.on_event(defines.events.on_built_entity, function(event)
    local _, err = xpcall(tas.on_built_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_built_entity", err }) end
end )

script.on_event(defines.events.on_preplayer_mined_item, function(event)
    local _, err = xpcall(tas.on_pre_mined_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_preplayer_mined_item", err }) end
end )

script.on_event(defines.events.on_robot_pre_mined, function(event)
    local _, err = xpcall(tas.on_pre_mined_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_robot_pre_mined", err }) end
end )

script.on_event("tas-select-hotkey", function(event)
    local _, err = xpcall(tas.on_left_click, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "tas-select-hotkey", err }) end
end )

script.on_event(defines.events.on_tick, function(event)
    local _, err = xpcall(tas.on_tick, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_tick", err }) end
end )