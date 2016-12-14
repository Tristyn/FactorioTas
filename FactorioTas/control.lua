require "tas"
require "gui"

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


-- script.on_configuration_changed(function()
--    local _, err = pcall(tas.init_globals)
--    if err then msg_all({"tas-err-generic", err}) end
-- end)


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
