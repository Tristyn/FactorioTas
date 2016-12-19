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
    local _, err = pcall(tas.init_globals)
    if err then msg_all( { "TAS-err-generic", err }) end
end )

script.on_event(defines.events.on_player_created, function(event)
    local _, err = pcall(tas.on_player_created, event)
    if err then msg_all( { "TAS-err-specific", "on_player_created", err }) end
end )

script.on_event(defines.events.on_gui_click, function(event)
    local _, err = pcall(tas.gui.on_click, event)
    if err then msg_all( { "TAS-err-specific", "on_gui_click", err }) end
end )

script.on_event(defines.events.on_built_entity, function(event)
    local _, err = pcall(tas.on_built_entity, event)
    if err then msg_all( { "TAS-err-specific", "on_built_entity", err }) end
end )

script.on_event(defines.events.on_preplayer_mined_item, function(event)
    local _, err = pcall(tas.on_pre_removing_entity, event)
    if err then msg_all( { "TAS-err-specific", "on_preplayer_mined_item", err }) end
end )

script.on_event(defines.events.on_robot_pre_mined, function(event)
    local _, err = pcall(tas.on_pre_removing_entity, event)
    if err then msg_all( { "TAS-err-specific", "on_robot_pre_mined", err }) end
end )

script.on_event("waypoint_select_hotkey", function(event)
    local _, err = pcall(tas.on_left_click, event)
    if err then msg_all( { "TAS-err-specific", "waypoint_select_hotkey", err }) end
end )
