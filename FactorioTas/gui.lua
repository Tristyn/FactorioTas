tas.gui = { }

function tas.gui.init_globals()
    global.gui = { }
    global.gui.is_playing = false
end

function tas.gui.init_player(player_index)
    local gui = { }
    global.players[player_index].gui = gui
    gui.is_editor_visible = false

    gui.editor_visible_toggle = game.players[player_index].gui.top.add { type = "button", name = "tas_editor_visible_toggle", caption = "TAS" }
end

function tas.gui.show_editor(player_index)
    local gui = global.players[player_index].gui

    if gui.is_editor_visible == true then
        return
    end

    gui.is_editor_visible = true;

    local player = game.players[player_index]

    gui.editor = player.gui.left.add { type = "frame", direction = "vertical", name = "tas_editor", caption = "TAS Editor" }

    gui.play = gui.editor.add { type = "button", caption = "play" }
    gui.clear = gui.editor.add { type = "button", caption = "clear" }

    gui.editor.add { type = "label", caption = "Waypoint Mode:" }
    local waypoints = gui.editor.add { type = "flow", direction = "horizontal" }

    gui.waypoints = { }
    gui.waypoints.move = waypoints.add { type = "button", name = "tas_editor_waypoint_move_toggle", caption = "insert" }

end

function tas.gui.hide_editor(player_index)
    local gui = global.players[player_index].gui

    if gui.is_editor_visible == false then
        return
    end

    gui.is_editor_visible = false

    gui.editor.destroy()
end

function tas.gui.toggle_editor_visible(player_index)
    if global.players[player_index].gui.is_editor_visible == true then
        tas.gui.hide_editor(player_index)
    else
        tas.gui.show_editor(player_index)
    end
end

function tas.gui.reset_waypoint_toggles(player_index)
    local waypoints = global.players[player_index].gui.waypoints

    waypoints.move.caption = "insert"
end

function tas.gui.on_click(event)
    local element = event.element
    local player_index = event.player_index
    local gui = global.players[player_index].gui

    local waypoints = gui.waypoints

    if element == gui.editor_visible_toggle then
        tas.ensure_first_sequence_initialized(true)
        tas.gui.toggle_editor_visible(player_index)
    elseif element == waypoints.move then
        if gui.current_state == "move" then
            tas.gui.reset_waypoint_toggles(player_index)
            gui.current_state = nil
        else
            tas.gui.reset_waypoint_toggles(player_index)
            gui.current_state = "move"
            waypoints.move.caption = "move"
        end
    elseif element == gui.play then
        tas.runner.new_runner(global.sequences[1])
        global.gui.is_playing = true
    elseif element == gui.clear then
        global.gui.is_playing = false
        for i = #global.runner.runners, 1, -1 do
            tas.runner.remove_runner(global.runner.runners[i])
        end
    end
end