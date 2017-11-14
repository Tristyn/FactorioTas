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
    gui.entity_editor = {
        container = gui.root.add { type = "flow", direction = "vertical" },
        entity_inventory = {
            selected_inventory_index = 1
        },
        character_inventory = {
            selected_inventory_index = 1
        }
    }
    gui.waypoint_container = gui.root.add { type = "flow", direction = "vertical" }
    gui.waypoint_editor = {
        item_transfer_rows = { }
    }

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

function tas.gui.hide_entity_editor(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.entity_editor.root ~= nil then
        gui.entity_editor.container.clear()
    end
end

function tas.gui.show_entity_editor(player_index, entity, character)
    fail_if_missing(player_index)
    fail_if_missing(entity)

    local entity_editor = global.players[player_index].gui.entity_editor

    tas.gui.hide_entity_editor(player_index)

    -- store the arguments so the editor can be refreshed at any time
    entity_editor.entity = entity
    entity_editor.character = character

    local container_frame = entity_editor.container.add { type = "frame", direction = "vertical" }
    entity_editor.root = container_frame.add { type = "table", colspan = 1 }

    -- inventory transfer ui
    -- transfer mode button: stack/item
    -- creates inventory transfer orders in the waypoint

    -- Collect inventories
    local entity_inventories = util.entity.get_inventory_info(entity.type)
    local character_inventories = util.entity.get_inventory_info(character.type)

    -- Inventory Transfer UI
    if #entity_inventories > 0 and #character_inventories > 0 and entity ~= character then

        local entity_inventory_names = { }
        for i = 1, #entity_inventories do
            entity_inventory_names[i] = entity_inventories[i].name
        end
        local character_inventory_names = { }
        for i = 1, #character_inventories do
            character_inventory_names[i] = character_inventories[i].name
        end

        -- Entity Inventory

        local entity_inventory = entity.get_inventory(entity_editor.entity_inventory.selected_inventory_index)
        if entity_inventory == nil then 
            entity_editor.entity_inventory.selected_inventory_index = entity_inventories[1].id
            entity_inventory = entity.get_inventory(entity_inventories[1].id)
        end
        entity_editor.entity_inventory.dropdown = entity_editor.root.add { type = "drop-down", selected_index = entity_editor.entity_inventory.selected_inventory_index, items = entity_inventory_names, name = util.get_guid() }
        tas.gui.register_dropdown_selection_changed_callback(entity_editor.entity_inventory.dropdown, tas.gui.handle_inventory_transfer_dropdown_changed)
        if entity_inventory.is_empty() == true then
            entity_editor.root.add { type = "label", caption = "empty" }
        else
            tas.gui.build_inventory_grid_control(entity_editor.root, entity_inventory, "item/", tas.gui.entity_info_transfer_inventory_clicked_callback)
        end
        
        -- Character Inventory

        local character_inventory = character.get_inventory(entity_editor.character_inventory.selected_inventory_index)
        if character_inventory == nil then 
            entity_editor.character_inventory.selected_inventory_index = character_inventories[1].id
            character_inventory = character.get_inventory(character_inventories[1].id)
        end
        entity_editor.character_inventory.dropdown = entity_editor.root.add { type = "drop-down", selected_index = entity_editor.character_inventory.selected_inventory_index, items = character_inventory_names, name = util.get_guid() }
        tas.gui.register_dropdown_selection_changed_callback(entity_editor.character_inventory.dropdown,  tas.gui.handle_inventory_transfer_dropdown_changed)
        if character_inventory.is_empty() == true then
            entity_editor.root.add { type = "label", caption = "empty" }
        else
            tas.gui.build_inventory_grid_control(entity_editor.root, character_inventory, "item/", tas.gui.entity_info_transfer_inventory_clicked_callback)
        end
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

        local mine = entity_editor.root.add { type = "checkbox", caption = "mine", state = mine_order_exists, name = util.get_guid() }
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
    local entity = nil
    local entity_editor = global.players[player_index].gui.entity_editor

    if entity_editor.character_inventory.dropdown == dropdown_element then
        inventory_viewmodel = entity_editor.character_inventory
        entity = entity_editor.character
    elseif entity_editor.entity_inventory.dropdown == dropdown_element then
        inventory_viewmodel = entity_editor.entity_inventory
        entity = entity_editor.entity
    else
        error()
    end

    local inventories = util.entity.get_inventory_info(entity.type)
    inventory_viewmodel.selected_inventory_index = inventories[inventory_viewmodel.dropdown.selected_index].id

    tas.gui.refresh(player_index)
end

function tas.gui.entity_info_transfer_inventory_clicked_callback(event)
    -- event = { gui_element, player_index, inventory, item_stack, item_stack_index }
    local click_event = event.click_event
    local player_index = click_event.player_index
    local inventory = event.inventory
    local item_stack = event.item_stack
    local item_stack_index = event.item_stack_index
    local entity_editor = global.players[player_index].gui.entity_editor
    local character = entity_editor.character
    local entity = entity_editor.entity

    local character_inventory = character.get_inventory(entity_editor.character_inventory.selected_inventory_index)
    local entity_inventory = entity.get_inventory(entity_editor.entity_inventory.selected_inventory_index)


    local is_player_receiving = util.get_inventory_owner(inventory) == entity

    local item_stack_count = util.get_item_stack_split_count(click_event, item_stack.name)

    local items = { name = item_stack.name, count = item_stack_count }
    tas.add_item_transfer_order(player_index, is_player_receiving, character_inventory, entity_inventory, items)
    tas.gui.refresh(player_index)
end

function tas.gui.hide_waypoint_info(player_index)
    fail_if_missing(player_index)

    local gui = global.players[player_index].gui

    if gui.waypoint ~= nil then
        gui.waypoint_container.clear()
        gui.waypoint = nil
    end
end

function tas.gui.crafting_queue_item_clicked_callback(event)
    local click_event = event.click_event
    local gui = global.players[click_event.player_index].gui
    local waypoint = global.sequence_indexer.sequences[gui.sequence_index].waypoints[gui.waypoint_index]
    local craft_order = waypoint.craft_orders[event.item_stack_index]
   

    local items_to_remove = util.get_item_stack_split_count(event, craft_order.item_name)

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
    local container_frame = gui.waypoint_container.add { type = "frame", direction = "vertical", caption = "Waypoint # " .. waypoint_index }
    gui.waypoint = container_frame.add { type = "table", colspan = 1}
    
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

        if #waypoint.item_transfer_orders > 0 then
            gui.waypoint.add{type ="label", caption = "item transfers" }
        end
        
        local item_transfer_table = gui.waypoint.add { type = "table", colspan = 5 }
        local item_transfer_rows = { }

        for i, order in ipairs(waypoint.item_transfer_orders) do
            local item_transfer_row = { order = order }
            table.insert(item_transfer_rows, item_transfer_row)

            local transfer_direction_sprite = nil
            if order.is_player_receiving == true then
                transfer_direction_sprite = "tas-arrow-right"
            else
                transfer_direction_sprite = "tas-arrow-left"
            end

            item_transfer_row.reveal_entity_button = tas.gui.build_inventory_item_control(item_transfer_table, { name = order.container_name, count = 0 } , "entity/")
            item_transfer_table.add { type = "sprite", sprite = transfer_direction_sprite}
            item_transfer_row.increment_button = tas.gui.build_inventory_item_control(item_transfer_table, order.item_stack, "item/")
            item_transfer_row.decrement_button = item_transfer_table.add { type = "sprite-button", sprite = "tas-decrement", style = "button-style"}
            item_transfer_row.remove_button = item_transfer_table.add { type = "sprite-button", sprite = "tas-cancel", style = "button-style"}
        end

        gui.waypoint_editor.item_transfer_rows = item_transfer_rows

    end
end

function tas.gui.try_handle_waypoint_editor_item_transfer_clicked(event)

    local button = event.element
    local waypoint_editor = global.players[event.player_index].gui.waypoint_editor

    for k, row in ipairs(waypoint_editor.item_transfer_rows) do
        if button == row.reveal_entity_button then
            util.alert(row.order.container_surface_name, row.order.container_position)
            return true
        elseif button == row.increment_button then
            local num_to_add = util.get_item_stack_split_count(event, row.order.item_stack.name)
            row.order:set_count(row.order:get_count() + num_to_add)
            tas.gui.refresh(event.player_index)
            return true
        elseif button == row.decrement_button then
            local num_to_remove = util.get_item_stack_split_count(event, row.order.item_stack.name)
            local new_count = math.max(row.order:get_count() - num_to_remove, 1)
            row.order:set_count(new_count)
            tas.gui.refresh(event.player_index)
            return true
        elseif button == row.remove_button then
            row.order.waypoint:remove_item_transfer_order(row.order.index)
            tas.gui.refresh(event.player_index)
            return true
        end
    end

    return false
end

-- Transforms a collection of craft_orders to a collection of SimpleItemStack
-- See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
function tas.gui.craft_orders_to_inventory(craft_orders)
    local inventory = { }
    local inventory_index = 1

    for i, craft_order in ipairs(craft_orders) do

        local simple_item_stack = { name = craft_order.recipe_name, count = craft_order:get_count() }
        table.insert(inventory, simple_item_stack)
    end

    return inventory
end

-- inventory is a collection of SimpleItemStack
-- on_item_stack_clicked_callback accepts a table with the fields { gui_element, player_index, inventory, item_stack, item_stack_index }
-- returns the root flow container elemnt for the inventory
function tas.gui.build_inventory_grid_control(container_frame, inventory, sprite_path_prefix, on_item_stack_clicked_callback)
    local inventory_container = container_frame.add { type = "table", colspan = 10 }

    -- item_stack is SimpleItemStack or LuaItemStack. See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
    
    for i = 1, #inventory do
        local item_stack = inventory[i]
        if item_stack.valid_for_read == nil or item_stack.valid_for_read == true then

            local btn = tas.gui.build_inventory_item_control(inventory_container, item_stack, sprite_path_prefix)

            if on_item_stack_clicked_callback ~= nil then
                tas.gui.register_click_callback(btn, function(event)
                    on_item_stack_clicked_callback( { gui_element = btn, click_event = event, inventory = inventory, item_stack = item_stack, item_stack_index = i })
                end )
            end

        end
    end

    return inventory_container
end

function tas.gui.build_inventory_item_control(container, item_stack, sprite_path_prefix)
    local btn = container.add( { type = "sprite-button", sprite = sprite_path_prefix .. item_stack.name, style = "button-style", name = util.get_guid() })
    if item_stack.count > 0 then
        btn.add( { type = "label", caption = tostring(item_stack.count) })
    end
    return btn
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

    local entity_editor = gui.entity_editor
    if entity_editor.root ~= nil then
        tas.gui.show_entity_editor(player_index, entity_editor.entity, entity_editor.character)
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
    elseif tas.gui.try_handle_waypoint_editor_item_transfer_clicked(event) == true then
        -- handled
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