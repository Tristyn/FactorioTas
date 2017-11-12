local tas = require("tas")

require("util")
require("gui")

inspect = require("inspect")
json = require("JSON")

function msg_all(message)
    for _, p in pairs(game.players) do
        if p.connected == true then
            p.print(message)
        end
    end
end

--[Comment]
-- Error if the argument evaluates to false or nil
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

--[Comment]
-- Returns true if the entity currently exists in the game world. (not null and valid == true)
function is_valid(entity)
    if not entity then
        return false
    end

    return entity.valid == true
end

--[Comment]
-- Error if the argument evaluates to false or nil,
-- or if the `valid` property of the argument is not true.
function fail_if_invalid(entity, msg)
    if not fail_if_missing(entity, msg) then
        if entity.valid ~= true then
            if msg then
                error(msg, 3)
            else
                error("Entity is invalid.", 3)
            end
        end
    end
    return false
end

script.on_init( function()
    -- Dont capture and print error, players won't see it as they haven't been added to the game
    -- Instead collect the traceback in err and rethrow.
    local _, err = xpcall(function() 
        tas.init_globals()
        util.init_globals()
        tas.gui.init_globals()

        tas.set_metatable()
    end, debug.traceback, event)

    if err then
        error(err)
    end
end )

script.on_load( function()
    -- Dont capture and print error, printing will result in another error 
    -- (resulting in loss of the initial stacktrace) because `game` is nil.
    -- Instead collect the traceback in err and rethrow.
    local _, err = xpcall(function() 
        tas.set_metatable()
    end, debug.traceback, event)
    
    if err then
        error(err)
    end
end)

script.on_event(defines.events.on_player_created, function(event)
    local _, err = xpcall(tas.on_player_created, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_player_created", err }) end
end )

script.on_event(defines.events.on_gui_click, function(event)
    local _, err = xpcall(tas.gui.on_click, debug.debug, event)
    if err then msg_all( { "TAS-err-specific", "on_gui_click", err }) end
end )

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local _, err = xpcall(tas.gui.on_check_changed, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_check_changed", err }) end
end )

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local _, err = xpcall(tas.gui.on_dropdown_selection_changed, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_dropdown_selection_changed", err }) end
end )

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

script.on_event(defines.events.on_player_crafted_item, function(event)
    local _, err = xpcall(tas.on_crafted_item, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_crafted_item", err }) end
end )

script.on_event("tas-select-hotkey", function(event)
    local _, err = xpcall(tas.on_left_click, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "tas-select-hotkey", err }) end
end )

script.on_event(defines.events.on_tick, function(event)
    local _, err = xpcall(tas.on_tick, debug.traceback, event)
    if err then msg_all( { "TAS-err-specific", "on_tick", err }) end
end )