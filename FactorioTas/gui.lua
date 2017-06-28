tas.gui = { }

function tas.gui.init_globals()
    global.gui = { }
    global.gui.click_event_callbacks = { }
    global.gui.check_changed_callbacks = { }
end

function tas.gui.init_player(player_index)
    fail_if_missing(player_index)

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
    gui.playback.reset = playback.add { type = "button", caption = "reset", style = "playback-button" }
    gui.playback.play_pause = playback.add { type = "button", caption = "play", style = "playback-button" }
    gui.playback.step = playback.add { type = "button", caption = "step:", style = "playback-button" }
    gui.playback.step_ticks = playback.add { type = "textfield", caption = "# ticks", style = "playback-textfield" }
    gui.playback.step_ticks.text = "10"

    gui.waypoint_mode = gui.editor.add { type = "button", caption = "insert waypoint" }

    -- End Editor constructor

    tas.gui.hide_editor(player_index)
end

function tas.gui.show_editor(player_index)
    fail_if_missing(player_index)

    tas.gui.hide_editor(player_index)

    local gui = global.players[player_index].gui

    -- gui.editor_visible_toggle.style.visible = false
    gui.root.style.visible = true
end

function tas.gui.hide_editor(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    gui.root.style.visible = false
    -- gui.editor_visible_toggle.style.visible = true
end

function tas.gui.toggle_editor_visible(player_index)
    fail_if_missing(player_index)

    if global.gui.editor == nil then
        tas.gui.show_editor(player_index)
    else
        tas.gui.hide_editor(player_index)
    end
end

function tas.gui.reset_waypoint_toggles(player_index)
    fail_if_missing(player_index)

    global.players[player_index].gui.waypoint_mode.caption = "insert waypoint"
end

function tas.gui.hide_entity_info(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.entity ~= nil then
        gui.entity.destroy()
        gui.entity = nil
    end
end

function tas.gui.show_entity_info(player_index, entity)
    fail_if_missing(player_index)
    fail_if_missing(entity)

    tas.gui.hide_entity_info(player_index)

    if entity.minable ~= true or entity.type == "resource" then
        return
    end

    local gui = global.players[player_index].gui

    gui.entity_object = entity
    gui.entity = gui.entity_container.add { type = "frame", direction = "vertical", caption = entity.localised_name }

    -- entity mine order
    if entity.minable == true then

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

    -- inventory transfer ui
    -- transfer mode button: stack/item
    -- container inventory
    -- your inventories (dropdown?)
    -- creates inventory transfer orders in the waypoint
end

function tas.gui.hide_waypoint_info(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.waypoint ~= nil then
        gui.waypoint.destroy()
        gui.waypoint = nil
    end
end

function tas.gui.show_waypoint_info(player_index, sequence_index, waypoint_index)
    fail_if_missing(player_index)
    fail_if_missing(sequence_index)
    fail_if_missing(waypoint_index)

    tas.gui.hide_waypoint_info(player_index)

    local waypoint = global.sequences[sequence_index].waypoints[waypoint_index]
    local gui = global.players[player_index].gui
    gui.sequence_index = sequence_index
    gui.waypoint_index = waypoint_index
    gui.waypoint = gui.waypoint_container.add { type = "frame", direction = "vertical", caption = "Waypoint # " .. waypoint_index }

    -- delay

    -- mine orders targeted at resources
    for _, mine_order in ipairs(waypoint.mine_orders) do

        -- only show mine orders from resources here
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

    -- crafting queue
    if #waypoint.craft_orders > 0 then
        local num_columns = 10

        gui.waypoint.add { type = "label", caption = "crafting queue" }
        local craft_orders_as_inventory = tas.gui.craft_orders_to_inventory(waypoint.craft_orders)
        tas.gui.build_inventory_grid_control(gui.waypoint, craft_orders_as_inventory, 10, function(event)
            tas.remove_craft_order(waypoint.craft_orders[event.item_stack_index])
            tas.gui.unregister_click_callbacks(event.gui_element)
            tas.gui.refresh(event.player_index)
        end )
    end
end

-- Transforms a collection of craft_orders to a collection of SimpleItemStack
-- See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
function tas.gui.craft_orders_to_inventory(craft_orders)
    local inventory = { }
    local inventory_index = 1

    for i, craft_order in ipairs(craft_orders) do
        --[[
        if #inventory > 0 and craft_order.name == inventory[#inventory].name then
            -- fast-path, merge with the top item stack
        end
        --]]

        local simple_item_stack = { recipe_name = craft_order.recipe.name, count = craft_order.count }
        table.insert(inventory, simple_item_stack)
    end

    return inventory
end

-- inventory is a collection of SimpleItemStack
-- on_item_stack_clicked_callback accepts a table with the fields { gui_element, player_index, inventory, item_stack, item_stack_index }
-- returns the root flow container elemnt for the inventory
function tas.gui.build_inventory_grid_control(container_frame, inventory, num_columns, on_item_stack_clicked_callback)
    local inventory_container = container_frame.add { type = "flow", direction = "vertical" }
    local inventory_row

    -- item_stack is SimpleItemStack. See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
    for i, item_stack in ipairs(inventory) do
        -- add a new row every n columns
        if i % num_columns == 1 then
            inventory_row = inventory_container.add { type = "flow", direction = "horizontal" }
        end

        local btn = inventory_row.add( { type = "sprite-button", sprite = "recipe/" .. item_stack.recipe_name, style = mod_gui.button_style, name = util.get_guid() })
        btn.add( { type = "label", caption = tostring(item_stack.count) })

        if on_item_stack_clicked_callback ~= nil then
            tas.gui.register_click_callback(btn, function(element, player_index)
                on_item_stack_clicked_callback( { gui_element = btn, player_index = player_index, inventory = inventory, item_stack = item_stack, item_stack_index = i })
            end )
        end
    end

    return inventory_container
end

function tas.gui.mine_order_info_to_localised_string(mine_order)
    fail_if_missing(mine_order)
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
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.sequence_index ~= nil and gui.waypoint_index ~= nil then
        tas.gui.show_waypoint_info(player_index, gui.sequence_index, gui.waypoint_index)
    end

    if gui.entity_object ~= nil then
        tas.gui.show_entity_info(player_index, gui.entity_object)
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
    fail_if_missing(...)

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
    fail_if_missing(...)

    for _, element in ipairs(...) do
        global.gui.check_changed_callbacks[element.name] = nil
    end
end

function tas.gui.on_click(event)
    fail_if_missing(event)

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
    elseif element == gui.playback.reset then
        tas.runner.reset_runner()
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
    fail_if_missing(event)

    local element = event.element
    local callback = global.gui.check_changed_callbacks[element.name]
    if callback ~= nil then
        callback(element, player_index)
    end
end