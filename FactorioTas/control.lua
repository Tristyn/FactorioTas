require "util"
require "tas"
require "gui"
require "runner"

json = require "JSON"

function msg_all(message)
    for _, p in pairs(game.players) do
        p.print(message)
    end
end

script.on_init( function()
    local _, err = xpcall(tas.init_globals, debug.traceback)
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

script.on_event(defines.events.on_built_entity, function(event)
    local _, err = xpcall(tas.on_built_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_built_entity", err }) end
end )

script.on_event(defines.events.on_preplayer_mined_item, function(event)
    local _, err = xpcall(tas.on_pre_removing_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_preplayer_mined_item", err }) end
end )

script.on_event(defines.events.on_robot_pre_mined, function(event)
    local _, err = xpcall(tas.on_pre_removing_entity, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_robot_pre_mined", err }) end
end )

script.on_event("waypoint_select_hotkey", function(event)
    local _, err = xpcall(tas.on_left_click, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "waypoint_select_hotkey", err }) end
end )

script.on_event(defines.events.on_tick, function(event)
    local _, err = xpcall(tas.on_tick, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_tick", err }) end
end )