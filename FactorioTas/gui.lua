tas.gui = { }

function tas.gui.init_globals()
    global.gui = { }
    global.gui.click_event_callbacks = { }
    global.gui.check_changed_callbacks = { }
end

function tas.gui.init_player(player_index)
    local gui = { }
    global.players[player_index].gui = gui

    local player = game.players[player_index]

    gui.editor_visible_toggle = player.gui.top.add { type = "button", name = "tas_editor_visible_toggle", caption = "TAS" }

    gui.root = player.gui.left.add { type = "flow", direction = "vertical" }
    gui.editor_container = gui.root.add { type = "flow", direction = "vertical" }
    gui.entity_container = gui.root.add { type = "flow", direction = "vertical" }
    gui.waypoint_container = gui.root.add { type = "flow", direction = "vertical" }


    -- Editor constructor
    gui.editor = gui.editor_container.add { type = "frame", direction = "vertical", caption = "TAS Editor" }

    local playback = gui.editor.add { type = "flow", direction = "horizontal" }
    gui.playback = { }
    gui.playback.play_pause = playback.add {type = "button", caption = "play", style="playback-button" }
    gui.playback.step = playback.add { type = "button", caption = "step:", style = "playback-button" }
    gui.playback.step_ticks = playback.add { type = "textfield", caption = "# ticks", style = "playback-textfield" }
    gui.playback.step_ticks.text = "30"

    gui.waypoint_mode = gui.editor.add { type = "button", caption = "insert waypoint" }

    -- End Editor constructor

    tas.gui.hide_editor(player_index)
end

function tas.gui.show_editor(player_index)
    tas.gui.hide_editor(player_index)

    local gui = global.players[player_index].gui

    -- gui.editor_visible_toggle.style.visible = false
    gui.root.style.visible = true
end

function tas.gui.hide_editor(player_index)
    local gui = global.players[player_index].gui

    gui.root.style.visible = false
    -- gui.editor_visible_toggle.style.visible = true
end

function tas.gui.toggle_editor_visible(player_index)
    if global.gui.editor == nil then
        tas.gui.show_editor(player_index)
    else
        tas.gui.hide_editor(player_index)
    end
end

function tas.gui.reset_waypoint_toggles(player_index)
    global.players[player_index].gui.waypoint_mode.caption = "insert waypoint"
end

function tas.gui.hide_entity_info(player_index)
    local gui = global.players[player_index].gui

    if gui.entity ~= nil then
        gui.entity.destroy()
        gui.entity = nil
    end
end

function tas.gui.show_entity_info(player_index, entity)
    tas.gui.hide_entity_info(player_index)

    if entity.minable ~= true or entity.type == "resource" then
        return
    end

    local gui = global.players[player_index].gui

    gui.entity_object = entity
    gui.entity = gui.entity_container.add { type = "frame", direction = "vertical", caption = entity.localised_name }

    local mine_order_exists = false
    local selected_items = tas.try_get_player_data(player_index)
    if selected_items ~= nil and selected_items.waypoint ~= nil then
        if tas.find_mine_order_from_entity_and_waypoint(entity, selected_items.waypoint) ~= nil then
            mine_order_exists = true
        end
    end

    local mine = gui.entity.add { type = "checkbox", caption = "mine", state = mine_order_exists, name = util.get_guid() }
    tas.gui.register_check_changed_callback(mine, function()
        if mine.state == true then
            tas.add_mine_order(player_index, entity)
        else
            local player_data = tas.try_get_player_data(player_index)
            if player_data == nil then return end
            local find_results = tas.find_mine_order_from_entity_and_waypoint(entity, player_data.waypoint)
            tas.destroy_mine_order(find_results.mine_order)
        end
    end )
end

function tas.gui.hide_waypoint_info(player_index)
    local gui = global.players[player_index].gui

    if gui.waypoint ~= nil then
        gui.waypoint.destroy()
        gui.waypoint = nil
    end
end

function tas.gui.show_waypoint_info(player_index, sequence_index, waypoint_index)
    tas.gui.hide_waypoint_info(player_index)

    local waypoint = global.sequences[sequence_index].waypoints[waypoint_index]
    local gui = global.players[player_index].gui
    gui.sequence_index = sequence_index
    gui.waypoint_index = waypoint_index
    gui.waypoint = gui.waypoint_container.add { type = "frame", direction = "vertical", caption = "Waypoint # " .. waypoint_index }

    -- delay

    for _, mine_order in ipairs(waypoint.mine_orders) do

        -- only show mine orders from resources here, all other mine orders are from entity info
        if mine_order.entity.type == "resource" then

            -- collect all controls for a mine order into a single frame for easy removal later
            local mine_order_frame = gui.waypoint.add { type = "flow", direction = "vertical" }

            local mine_order_label = mine_order_frame.add { type = "label", caption = tas.gui.mine_order_info_to_localised_string(mine_order) }

            local button_frame = mine_order_frame.add { type = "flow", direction = "horizontal" }

            local increment_count = button_frame.add { type = "button", caption = "+", style = "playback-button", name = util.get_guid() }
            tas.gui.register_click_callback(increment_count, function()
                tas.set_mine_order_count(mine_order, mine_order.count + 1)
                mine_order_label.caption = tas.gui.mine_order_info_to_localised_string(mine_order)
            end )

            local decrement_count = button_frame.add { type = "button", caption = "-", style = "playback-button", name = util.get_guid() }
            tas.gui.register_click_callback(decrement_count, function()
                if mine_order.count <= 1 then return end
                tas.set_mine_order_count(mine_order, mine_order.count - 1)
                mine_order_label.caption = tas.gui.mine_order_info_to_localised_string(mine_order)
            end )

            local destroy = button_frame.add { type = "button", caption = "x", style = "playback-button", name = util.get_guid() }
            tas.gui.register_click_callback(destroy, function()
                tas.destroy_mine_order(mine_order)
                mine_order_frame.destroy()
                tas.gui.unregister_click_callbacks(increment_count, decrement_count, destroy)
            end )

        end
    end

end

function tas.gui.mine_order_info_to_localised_string(mine_order)
    return { "TAS-mine-order-info", mine_order.count, mine_order.entity.localised_name }
end

function tas.gui.set_entity_reference_count(num_entity_references)
    for player_index, player in pairs(game.connected_players) do
        local gui = global.players[player_index].gui

        if gui.entity_count == nil then
            gui.entity_count = player.gui.top.add { type = "label", caption = num_entity_references }
        else
            gui.entity_count.caption = num_entity_references
        end
    end
end

function tas.gui.refresh(player_index)
    local gui = global.players[player_index].gui

    if gui.sequence_index ~= nil and gui.waypoint_index ~= nil then
        tas.gui.show_waypoint_info(player_index, gui.sequence_index, gui.waypoint_index)
    end

    if gui.entity_object ~= nil then
        tas.gui.show_entity_info(gui.entity_object)
    end
end

function tas.gui.register_click_callback(element, callback)
    fail_if_missing(element)
    fail_if_missing(callback)

    local callbacks = global.gui.click_event_callbacks

    if element.name == "" or callbacks[element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[element.name] = callback
end

function tas.gui.unregister_click_callbacks(...)
    for _, element in ipairs(...) do
        global.gui.click_event_callbacks[element.name] = nil
    end
end

function tas.gui.register_check_changed_callback(checkbox_element, callback)
    fail_if_missing(checkbox_element)
    fail_if_missing(callback)

    local callbacks = global.gui.check_changed_callbacks

    if checkbox_element.name == "" or callbacks[checkbox_element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[checkbox_element.name] = callback
end

function tas.gui.unregister_check_changed_callbacks(...)
    for _, element in ipairs(...) do
        global.gui.check_changed_callbacks[element.name] = nil
    end
end

function tas.gui.on_click(event)
    local element = event.element
    local player_index = event.player_index
    local gui = global.players[player_index].gui

    local waypoints = gui.waypoints

    local callback = global.gui.click_event_callbacks[element.name]
    if callback ~= nil then
        callback(element, player_index)
    end

    if element == gui.editor_visible_toggle then
        tas.ensure_first_sequence_initialized(true)
        tas.gui.toggle_editor_visible(player_index)
    elseif element == gui.waypoint_mode then
        if gui.current_state == "move" then
            tas.gui.reset_waypoint_toggles(player_index)
            gui.current_state = nil
        else
            gui.current_state = "move"
            gui.waypoint_mode.caption = "move waypoint"
        end
    elseif element == gui.playback.play_pause then
        if element.caption == "play" then
            tas.runner.play(player_index, nil)
            element.caption = "pause"
        else
            tas.runner.pause(player_index, nil)
            element.caption = "play"
        end
    elseif element == gui.playback.play then
        tas.runner.play(player_index, nil)
    elseif element == gui.playback.pause then
        tas.runner.pause()
    elseif element == gui.playback.step then
        local num_ticks = tonumber(gui.playback.step_ticks.text)
        if num_ticks ~= nil then
            tas.runner.play(player_index, num_ticks)
        end
    end
end

function tas.gui.on_check_changed(event)
    local element = event.element
    local callback = global.gui.check_changed_callbacks[element.name]
    if callback ~= nil then
        callback(element, player_index)
    end
end