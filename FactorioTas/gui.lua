local tas = require("tas")

tas.gui = { }

function tas.gui.init_globals()
    global.gui = { }
    global.gui.click_event_callbacks = { }
    global.gui.check_changed_callbacks = { }
    global.gui.dropdown_selection_state_changed_callbacks = { }
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
    gui.entity_inventory = { }
    gui.player_inventory = { }

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

    if global.players[player_index].gui.root.style.visible == true then
        tas.gui.hide_editor(player_index)
    else
        tas.gui.show_editor(player_index)
    end
end

function tas.gui.reset_waypoint_toggles(player_index)
    fail_if_missing(player_index)

    global.players[player_index].gui.waypoint_mode.caption = "insert waypoint"
end

function tas.gui.hide_entity_info(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if is_valid(gui.player_inventory.dropdown) then
        tas.gui.unregister_dropdown_selection_changed_callbacks(gui.player_inventory.dropdown)
    end

    if is_valid(gui.entity_inventory.dropdown) then
        tas.gui.unregister_dropdown_selection_changed_callbacks(gui.entity_inventory.dropdown)
    end

    if gui.entity ~= nil then
        gui.entity.destroy()
        gui.entity = nil
    end
end

function tas.gui.show_entity_info(player_index, entity)
    fail_if_missing(player_index)
    fail_if_missing(entity)

    local character_entity = game.players[player_index].character
    local gui = global.players[player_index].gui

    tas.gui.hide_entity_info(player_index)

    gui.entity_info = {
        surface_name = entity.surface.name,
        position = entity.position,
        name = entity.name }

    gui.entity = gui.entity_container.add { type = "frame", direction = "vertical", caption = entity.localised_name }



    -- inventory transfer ui
    -- transfer mode button: stack/item
    -- creates inventory transfer orders in the waypoint

    -- Collect inventories
    local entity_inventories = util.entity.get_inventory_info(entity.type)
    local player_inventories = util.entity.get_inventory_info(character_entity.type)
    gui.entity_inventory.all_inventories = entity_inventories
    gui.player_inventory.all_inventories = player_inventories
    -- Inventory Transfer UI
    if #entity_inventories > 0 and #player_inventories > 0 then

        local entity_inventory_names = { }
        for i = 1, #entity_inventories do
            entity_inventory_names[i] = entity_inventories[i].name
        end
        local player_inventory_names = { }
        for i = 1, #player_inventories do
            player_inventory_names[i] = player_inventories[i].name
        end

        --- Ensure that the inventory dropdowns are not null and set to entity inventories
        if entity_inventories[gui.entity_inventory.opened_inventory_index] == nil then
            gui.entity_inventory.opened_inventory_index = 1
        end
        --
        if player_inventories[gui.player_inventory.opened_inventory_index] == nil then
            gui.player_inventory.opened_inventory_index = 1
        end
        ---


        -- Entity Inventory

        gui.entity_inventory.dropdown = gui.entity.add { type = "drop-down", selected_index = gui.entity_inventory.opened_inventory_index, items = entity_inventory_names, name = util.get_guid() }
        tas.gui.register_dropdown_selection_changed_callback(gui.entity_inventory.dropdown, tas.gui.handle_inventory_transfer_dropdown_changed)

        gui.entity_inventory.inventory_grid_container = gui.entity.add { type = "flow" }
        tas.gui.show_entity_info_transfer_inventory(player_index, gui.entity_inventory)

        -- Player Inventory

        gui.player_inventory.dropdown = gui.entity.add { type = "drop-down", selected_index = gui.player_inventory.opened_inventory_index, items = player_inventory_names, name = util.get_guid() }
        tas.gui.register_dropdown_selection_changed_callback(gui.player_inventory.dropdown,  tas.gui.handle_inventory_transfer_dropdown_changed)

        gui.player_inventory.inventory_grid_container = gui.entity.add { type = "flow" }
        tas.gui.show_entity_info_transfer_inventory(player_index, gui.player_inventory)

    end

    -- entity mine order
    if entity.minable == true and entity.type ~= "resource" then

        local mine_order_exists = false
        local waypoint = global.players[player_index].waypoint
        if waypoint ~= nil then
            if tas.find_mine_order_from_entity_and_waypoint(entity, waypoint) ~= nil then
                mine_order_exists = true
            end
        end

        local mine = gui.entity.add { type = "checkbox", caption = "mine", state = mine_order_exists, name = util.get_guid() }
        tas.gui.register_check_changed_callback(mine, function()
            if mine.state == true then
                tas.add_mine_order(player_index, entity)
            else
                local waypoint = global.players[player_index].waypoint
                if waypoint == nil then return end
                local find_results = tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
                tas.destroy_mine_order(find_results.mine_order)
            end
        end )
    end
end

function tas.gui.handle_inventory_transfer_dropdown_changed(dropdown_element, player_index)
    local inventory_viewmodel = nil
    local gui = global.players[player_index].gui


    if gui.player_inventory.dropdown == dropdown_element then
        inventory_viewmodel = gui.player_inventory
    elseif gui.entity_inventory.dropdown == dropdown_element then
        inventory_viewmodel = gui.entity_inventory
    else
        error()
    end

    
    inventory_viewmodel.opened_inventory_index = inventory_viewmodel.dropdown.selected_index
    tas.gui.show_entity_info_transfer_inventory(player_index, inventory_viewmodel)
end

function tas.gui.show_entity_info_transfer_inventory(player_index, inventory_viewmodel)
    local inventory_index = inventory_viewmodel.opened_inventory_index
    local inventory_info = inventory_viewmodel.all_inventories[inventory_index]
    local inventory = inventory_viewmodel.entity.get_inventory(inventory_info.id)

    --- 0.15 Impl
    -- gui.entity_inventory.dropdown = gui.entity.add { type = "drop-down", inventory_viewmodel.inventory_grid_container, items = entity_inventory_names, name = util.get_guid() }
    -- tas.gui.register_dropdown_selection_changed_callback(gui.entity_inventory.dropdown, function(event, player_index) tas.gui.entity_current_inventory_dropdown_changed_callback(player_index, gui.entity_inventory) end)

    
    inventory_viewmodel.inventory_grid_container.clear()
    tas.gui.build_inventory_grid_control(inventory_viewmodel.inventory_grid_container, inventory, "item/", tas.gui.entity_info_transfer_inventory_clicked_callback)
end

function tas.gui.entity_info_transfer_inventory_clicked_callback(event)
    -- event = { gui_element, player_index, inventory, item_stack, item_stack_index }
    local click_event = event.click_event
    local player_index = click_event.player_index
    local player_entity = game.players[player_index]
    local inventory = event.inventory
    local item_stack = event.item_stack
    local item_stack_index = event.item_stack_index
    local gui = global.players[player_index].gui

    local inventory_owner = util.get_inventory_owner(inventory)
    local is_player_receiving = inventory_owner ~= player_entity and inventory_owner ~= player_entity.character

    local item_stack_count = 1
    if click_event.button == defines.mouse_button_type.left and click_event.shift then
        item_stack_count = game.item_prototypes[item_stack.name].stack_size
    elseif click_event.button == defines.mouse_button_type.right then
        item_stack_count = 5
    end

    tas.gui.new_item_transfer_order(player_index, gui.entity_inventory, gui.player_inventory, is_player_receiving, { name = item_stack.name, count = item_stack_count })
end

function tas.gui.new_item_transfer_order(player_index, entity_inventory_viewmodel, player_inventory_viewmodel, is_player_receiving, items_to_transfer)
    if game.players[player_index].character ~= player_inventory_viewmodel.entity then
        error("player index and character entity don't match")
    end

    local entity_inventory = entity_inventory_viewmodel.entity.get_inventory(entity_inventory_viewmodel.all_inventories[entity_inventory_viewmodel.opened_inventory_index].id)
    local player_inventory = player_inventory_viewmodel.entity.get_inventory(player_inventory_viewmodel.all_inventories[player_inventory_viewmodel.opened_inventory_index].id)

    tas.add_item_transfer_order(player_index, is_player_receiving, player_inventory, entity_inventory_viewmodel.entity, entity_inventory, items_to_transfer)

end

function tas.gui.hide_waypoint_info(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.waypoint ~= nil then
        gui.waypoint.destroy()
        gui.waypoint = nil
    end
end

function tas.gui.crafting_queue_item_clicked_callback(event)
    local click_event = event.click_event
    local gui = global.players[click_event.player_index].gui
    local waypoint = global.sequence_indexer.sequences[gui.sequence_index].waypoints[gui.waypoint_index]
    local craft_order = waypoint.craft_orders[event.item_stack_index]
   

    local items_to_remove = 1
    if click_event.button == defines.mouse_button_type.left and click_event.shift then
        items_to_remove = game.item_prototypes[event.item_stack.name].stack_size
    elseif click_event.button == defines.mouse_button_type.right then
        items_to_remove = 5
    end

    
    if craft_order:get_count() > items_to_remove then
        craft_order:set_count(craft_order:get_count() - items_to_remove)
    else
        waypoint:remove_craft_order(event.item_stack_index)
    end
    
    tas.gui.refresh(click_event.player_index)
end

function tas.gui.show_waypoint_info(player_index, sequence_index, waypoint_index)
    fail_if_missing(player_index)
    fail_if_missing(sequence_index)
    fail_if_missing(waypoint_index)

    tas.gui.hide_waypoint_info(player_index)

    local waypoint = global.sequence_indexer.sequences[sequence_index].waypoints[waypoint_index]
    local gui = global.players[player_index].gui
    gui.sequence_index = sequence_index
    gui.waypoint_index = waypoint_index
    gui.waypoint = gui.waypoint_container.add { type = "frame", direction = "vertical", caption = "Waypoint # " .. waypoint_index }

    -- delay

    -- mine orders targeted at resources
    for _, mine_order in ipairs(waypoint.mine_orders) do

        local mine_order_entity = mine_order:get_entity()
        -- only show mine orders from resources here
        if is_valid(mine_order_entity) and mine_order_entity.type == "resource" then

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
        gui.waypoint.add { type = "label", caption = "crafting queue" }
        local craft_orders_as_inventory = tas.gui.craft_orders_to_inventory(waypoint.craft_orders)
        tas.gui.build_inventory_grid_control(gui.waypoint, craft_orders_as_inventory, "recipe/", tas.gui.crafting_queue_item_clicked_callback)
    end

    -- item transfer orders
    do
        for i, order in ipairs(waypoint.item_transfer_orders) do

            gui.waypoint.add { type = "label", caption = { "TAS-item-transfer-order-description", order.container_entity.name, order.container_entity.position.x, order.container_entity.position.y } }
            tas.gui.build_inventory_grid_control(gui.waypoint, { order.item_stack }, "item/", nil)

        end

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

        local simple_item_stack = { name = craft_order.recipe_name, count = craft_order:get_count() }
        table.insert(inventory, simple_item_stack)
    end

    return inventory
end

-- inventory is a collection of SimpleItemStack
-- on_item_stack_clicked_callback accepts a table with the fields { gui_element, player_index, inventory, item_stack, item_stack_index }
-- returns the root flow container elemnt for the inventory
function tas.gui.build_inventory_grid_control(container_frame, inventory, sprite_path_prefix, on_item_stack_clicked_callback)
    local num_columns = 10
    local inventory_container = container_frame.add { type = "flow", direction = "vertical" }
    local inventory_row

    -- item_stack is SimpleItemStack. See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
    
    for i = 1, #inventory do
        local item_stack = inventory[i]
        if item_stack.valid_for_read == nil or item_stack.valid_for_read == true then

            -- add a new row every n columns
            if i % num_columns == 1 then
                inventory_row = inventory_container.add { type = "flow", direction = "horizontal" }
            end

            local btn = inventory_row.add( { type = "sprite-button", sprite = sprite_path_prefix .. item_stack.name, style = "button-style", name = util.get_guid() })
            btn.add( { type = "label", caption = tostring(item_stack.count) })

            if on_item_stack_clicked_callback ~= nil then
                tas.gui.register_click_callback(btn, function(event)
                    on_item_stack_clicked_callback( { gui_element = btn, click_event = event, inventory = inventory, item_stack = item_stack, item_stack_index = i })
                end )
            end

        end
    end

    return inventory_container
end

function tas.gui.mine_order_info_to_localised_string(mine_order)
    fail_if_missing(mine_order)
    return { "TAS-mine-order-info", mine_order.get_count(), game.entity_prototypes[mine_order.name].localised_name }
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

    if gui.entity_info ~= nil then
        local entity_object = util.find_entity(gui.entity_info.surface_name, gui.entity_info.name, gui.entity_info.position)
        if is_valid(entity_object) then
            tas.gui.show_entity_info(player_index, entity_object)
        end
    end
end

--[Comment]
--Invokes `callback(event)` when a LuaGuiElement `element` is clicked.
--argument `event` is a table that contains:
---element :: LuaGuiElement: The clicked element.
---player_index :: uint: The player who did the clicking.
function tas.gui.register_click_callback(element, callback)
    fail_if_missing(element)
    fail_if_missing(callback)

    local callbacks = global.gui.click_event_callbacks

    if element.name == "" or callbacks[element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[element.name] = callback
end

--[Comment]
--tas.gui.unregister_click_callbacks(element_1, element_2, ...) or int indexed array
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

function tas.gui.register_dropdown_selection_changed_callback(dropdown_element, callback)
    fail_if_missing(dropdown_element)
    fail_if_missing(callback)

    local callbacks = global.gui.dropdown_selection_state_changed_callbacks

    if dropdown_element.name == "" or callbacks[dropdown_element.name] ~= nil then
        error("Element name must be a unique string. Use util.get_guid()!")
    end

    callbacks[dropdown_element.name] = callback
end

function tas.gui.unregister_dropdown_selection_changed_callbacks(...)
    fail_if_missing(...)

    for _, element in ipairs(...) do
        global.gui.dropdown_selection_state_changed_callbacks[element.name] = nil
    end
end

function tas.gui.on_dropdown_selection_changed(event)
    fail_if_missing(event)

    local element = event.element
    local player_index = event.player_index

    local callback = global.gui.dropdown_selection_state_changed_callbacks[element.name]
    if callback ~= nil then
        callback(element, player_index)
    end
end

function tas.gui.on_click(event)
    fail_if_missing(event)
    local element = event.element
    local player_index = event.player_index
    local player = game.players[player_index]
    local gui = global.players[player_index].gui

    local waypoints = gui.waypoints

    local callback = global.gui.click_event_callbacks[element.name]
    if callback ~= nil then
        callback(event)
    end

    if element == gui.editor_visible_toggle then
        tas.ensure_cheat_mode_enabled(player_index)
        tas.ensure_first_sequence_initialized()
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
            global.playback_controller:play(player)
            element.caption = "pause"
        else
            global.playback_controller:pause()
            element.caption = "play"
        end
    elseif element == gui.playback.reset then
        global.playback_controller:reset()
    elseif element == gui.playback.step then
        local num_ticks = tonumber(gui.playback.step_ticks.text)
        if num_ticks ~= nil then
            global.playback_controller:play(player, num_ticks)
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