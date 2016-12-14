global.gui = { }
tas.gui = { }

function tas.gui.init_player(player_index)
    global.players[player_index].gui = { }
    global.players[player_index].gui.is_editor_visible = false

    game.players[player_index].gui.top.add { type = "button", name = "tas_editor_visible_toggle", caption = "TAS" }
end

function tas.gui.show_editor(player_index)

    if global.players[player_index].gui.is_editor_visible == true then
        return
    end

    global.players[player_index].gui.is_editor_visible = true;

    local player = game.players[player_index]

    local editor = player.gui.left.add { type = "frame", direction = "vertical", name = "tas_editor", caption = "TAS Editor" }

    editor.add { type = "label", caption = "waypoints" }
    local waypoints = editor.add { type = "flow", direction = "horizontal" }

    waypoints.add { type = "button", name = "tas_editor_waypoint_visible_toggle", caption = "show/hide" }

end

function tas.gui.hide_editor(player_index)
    if global.players[player_index].gui.is_editor_visible == false then
        return
    end

    global.players[player_index].gui.is_editor_visible = false

    game.players[player_index].gui.left.tas_editor.destroy()
end

function tas.gui.toggle_editor_visible(player_index)
    if global.players[player_index].gui.is_editor_visible == true then
        tas.gui.hide_editor(player_index)
    else
        tas.gui.show_editor(player_index)
    end
end

function tas.gui.toggle_waypoint_add(element, player_index)
    if tas.is_adding_waypoint(player_index) then
        element.caption = "New"
        tas.set_adding_waypoint(false)
    else
        element.caption = "X"
        tas.set_adding_waypoint(true)
    end
end

function tas.gui.on_click(event)
    local name = event.element.name
    local player_index = event.player_index

    if name == "tas_editor_visible_toggle" then
        tas.gui.toggle_editor_visible(player_index)
    elseif name =="tas_editor_waypoint_visible_toggle" then
        
    end
    
end