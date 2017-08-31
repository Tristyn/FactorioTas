tas = { }

function tas.log(level, message)
    if level == "debug" then
        msg_all(message)
    end
end

local init = false
function tas.init_globals()
    global.sequences = { }
    global.players = { }
    global.arrow_auto_update_repository = { }
end

function tas.on_player_created(event)
    local player_index = event.player_index

    global.players[player_index] =
    {
        hover_arrows = { }
    }

    --  select the first sequence if any exist
    if #global.sequences > 0 then
        global.players[player_index].selected_sequence_index = 1
    end

    tas.gui.init_player(player_index)
end

ArrowController = require("entities.ArrowController")

-- Creates and returns a static text entity that never despawns.
-- If color is nil, the text will be white
function tas.create_static_text(surface, position, content, color)
    local text = surface.create_entity
    {
        name = "flying-text",
        position = position,
        text = content,
        color = color
    }

    -- Text will be stationary and never despawns
    text.active = false

    return text
end

--[Comment]
-- Creates a new arrow facade instance that displays a beam onscreen between two entities.
-- Other methods can control its lifetime.
function tas.create_arrow(source_entity, target_entity)

    -- Note: The arrow is drawn using a beam entity, which requries the source and target to have health.
    -- A beam can be drawn to any entity by using an invisible proxy entity when necessary
    -- Proxy entity positions have to be updated manually in that case.


    local arrow_facade =
    {
        source = source_entity,
        target = target_entity,
        disposed = false
    }
    
    local arrow_builder = {
        name = "tas-arrow",
        position = { 0, 0 },
        -- source and target entities may be the proxies created earlier
        source = source_entity,
        target = target_entity
    }

    -- determine if we should wrap the source and target entities for the beam entity
    -- References to these will be saved in the arrow_facade for proper cleanup later

    -- This pcall returns true if the entity has health, false if the call threw an exception accessing the field
    if pcall( function() if type(arrow_facade.source.health) ~= "float" then error() end end) == false then
        arrow_facade.source_proxy = arrow_facade.source.surface.create_entity( {
            name = "tas-arrow-proxy",
            position = source_entity.position
        } )
        arrow_builder.source = arrow_facade.source_proxy
    end

    if pcall( function() if type(arrow_facade.target.health) ~= "float" then error() end end) == false then
        arrow_facade.target_proxy = arrow_facade.target.surface.create_entity( {
            name = "tas-arrow-proxy",
            position = target_entity.position
        } )
        arrow_builder.target = arrow_facade.target_proxy
    end

    arrow_facade.beam = source_entity.surface.create_entity(arrow_builder)

    return arrow_facade
end

-- [Comment]
-- Ensures that the arrows position matches that of the source and target entities.
-- Returns true if the beam still exists in the game world, otherwise false.
function tas.update_arrow(arrow_facade)

    if arrow_facade.disposed == true then
        error("Attempted to update an arrow that has been destroyed. Throwing to warn of a resource leak")
    end

    -- update the proxy entities positions so that the beam entity draws in the correct position

    if arrow_facade.source_proxy ~= nil and arrow_facade.source_proxy.valid == true and arrow_facade.source.valid == true then
        arrow_facade.source_proxy.teleport(arrow_facade.source.position)
    end

    if arrow_facade.target_proxy ~= nil and arrow_facade.target_proxy.valid == true and arrow_facade.target.valid == true then
        arrow_facade.target_proxy.teleport(arrow_facade.target.position)
    end

end

-- [Comment]
-- Destroys any internal entities and renders the object useless.
-- Subsequent calls to other instance methods will result in an error.
-- instance field disposed will return true
function tas.destroy_arrow(arrow_facade)
    arrow_facade.disposed = true

    if arrow_facade.source_proxy ~= nil and arrow_facade.source_proxy.valid == true then
        arrow_facade.source_proxy.destroy()
    end

    if arrow_facade.target_proxy ~= nil and arrow_facade.target_proxy.valid == true then
        arrow_facade.target_proxy.destroy()
    end

    -- beam should never be nil
    if arrow_facade.beam.valid == true then
        arrow_facade.beam.destroy()
    end

end

-- [Comment]
-- Notifies the user and sets cheat mode to true if it is currently false.
-- `player` can be a LuaPlayer, LuaCharacter or uint.
function tas.ensure_cheat_mode_enabled(player)
    fail_if_missing(player)

    local player_entity = nil
    game.print(type(player))
    if type(player) == "userdata" then
        player_entity = player
    elseif type(player) == "number" then
        player_entity = game.players[player]
    else
        error("`player` must be a LuaPlayer, LuaCharacter or uint.")
    end

    if player_entity.cheat_mode == false then
        player_entity.print("[TAS] Editor: Enabling cheat mode.")
        player_entity.cheat_mode = true
    end
end

-- [Comment]
-- Creates a new waypoint table. waypoint_entity can be nil.
function tas.new_waypoint(surface, position, waypoint_index, is_visible_in_game, waypoint_entity)
    local text_entity
    if is_visible_in_game == true then
        if waypoint_entity == nil or waypoint_entity.valid == false then
            waypoint_entity = surface.create_entity { name = "tas-waypoint", position = position }
        end

        text_entity = tas.create_static_text(surface, position, util.integer_to_string(waypoint_index))
    end

    return
    {
        surface = surface,
        position = position,
        entity = waypoint_entity,
        text_entity = text_entity,
        build_orders = { },
        mine_orders = { },
        craft_orders = { },
        item_transfer_orders = { }
    }
end

-- creates a new sequence and returns it's index in the sequence table
function tas.new_sequence(add_spawn_waypoint, add_initial_crafting_queue)
    local sequence_index = #global.sequences + 1


    local sequence = {
        waypoints = { }
    }

    if add_spawn_waypoint == true then
        local surface = game.surfaces["nauvis"]
        local origin = { x = 0, y = 0 }

        sequence.waypoints[1] = tas.new_waypoint(surface, origin, 1, true)

        if add_initial_crafting_queue == true then
            tas.add_craft_order(sequence.waypoints[1], "iron-axe", 1)
        end
    end

    global.sequences[sequence_index] = sequence

    local final_waypoint_index = #sequence.waypoints
    if final_waypoint_index == 0 then
        final_waypoint_index = nil
    end

    -- if any sequences exist, players must have one selected
    -- set their sequence if it is nil
    for player_index, player in pairs(global.players) do
        if player.selected_sequence_index == nil then
            tas.select_waypoint(player_index, final_waypoint_index, sequence_index)
        end
    end

    return sequence_index
end

function tas.ensure_first_sequence_initialized(add_spawn_waypoint)
    if #global.sequences > 0 then
        return
    end

    if add_spawn_waypoint then
        game.print("[TAS] Placing the initial waypoint at spawn.")
    end
    tas.new_sequence(add_spawn_waypoint)
end

function tas.realign_sequence_indexes(start_index, shift)

    -- realign each players selected index
    for _, player in pairs(global.players) do
        if player.selected_sequence_index ~= nil
            and player.selected_sequence_index >= start_index then
            local new_selected_sequence = math.max(player.selected_sequence_index + shift, start_index - 1)

            -- selected sequence underflow: select the first sequence. or unselect if no sequences exist.
            if new_selected_sequence < 1 then
                if #global.sequences > 0 then
                    new_selected_sequence = 1
                else
                    new_selected_sequence = nil
                end
            end

            tas.select_waypoint(player_index, new_selected_waypoint, new_selected_sequence)
        end
    end
end

function tas.destoy_sequence(sequence_index)
    table.remove(global.sequences, sequence_index)

    tas.realign_sequence_indexes(sequence_index, -1)
end

-- Clone an entity to a lua table.
-- The returned table will not be corrupted after the entity is deleted.
-- The returned table can be used as an argument for LuaSurface.create_entity()
function tas.entity_to_table(entity)
    -- A LuaEntity is a proxy to a cpp object, so features like ipairs(), #, etc don't work
    -- Clone well-known properties instead
    return {
        name = entity.name,
        position = entity.position,
        direction = entity.direction,
        force = entity.force.name,
        inner_name = function() pcall(entity.ghost_name) end
    }
end

-- scans a table for a value and returns its index
-- returns nil if it doesn't exist
function tas.scan_table_for_value(table, selector, value)
    for key, val in pairs(table) do
        if value == selector(val) then
            return key
        end
    end
end

function tas.select_waypoints_in_sequences()
    return collections.select_many(global.sequences, function(sequence) return sequence.waypoints end)
end

function tas.find_waypoint_from_entity(waypoint_entity)
    -- iterate all waypoints of all sequences to find a match
    for sequence_index, sequence in ipairs(global.sequences) do

        local waypoint_index = tas.scan_table_for_value(sequence.waypoints, function(waypoint) return waypoint.entity end, waypoint_entity)
        if waypoint_index ~= nil then
            return {
                sequence_index = sequence_index,
                sequence = sequence,
                waypoint_index = waypoint_index,
                waypoint = sequence.waypoints[waypoint_index]
            }
        end
    end
end

-- Returns nil if the player hasn't selected a waypoint
function tas.try_get_player_data(player_index)
    local player = global.players[player_index]
    local waypoint_index = player.selected_sequence_waypoint_index

    if waypoint_index == nil then return end

    local sequence_index = player.selected_sequence_index
    local sequence = global.sequences[sequence_index]
    local waypoint = sequence.waypoints[waypoint_index]

    return
    {
        player = player,
        player_entity = game.players[player_index],
        sequence_index = sequence_index,
        sequence = sequence,
        waypoint_index = waypoint_index,
        waypoint = waypoint
    }
end

function tas.find_build_order_from_entity(ghost_entity)
    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local build_order_index = tas.scan_table_for_value(waypoint.build_orders, function(build_order) return build_order.entity end, ghost_entity)
            if build_order_index ~= nil then
                return {
                    sequence = sequence,
                    sequence_index = sequence_index,
                    waypoint = waypoint,
                    waypoint_index = waypoint_index,
                    build_order = waypoint.build_orders[build_order_index],
                    build_order_index = build_order_index
                }
            end
        end
    end
end

function tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
    local key = tas.scan_table_for_value(waypoint.mine_orders, function(order) return order.entity end, entity)

    if key == nil then return nil end

    return {
        mine_order_index = key,
        mine_order = waypoint.mine_orders[key]
    }
end

function tas.find_mine_orders_from_entity(entity)
    local found = { }

    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local indexes = tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
            if indexes ~= nil then
                indexes.sequence = sequence
                indexes.sequence_index = sequence_index
                indexes.waypoint = waypoint
                indexes.waypoint_index = waypoint_index
                table.insert(found, indexes)
            end
        end
    end

    return found
end

function tas.get_mine_order_indexes(mine_order)
    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local mine_order_index = tas.scan_table_for_value(waypoint.mine_orders, function(order) return order end, mine_order)
            if mine_order_index ~= nil then
                return
                {
                    sequence = sequence,
                    sequence_index = sequence_index,
                    waypoint = waypoint,
                    waypoint_index = waypoint_index,
                    mine_order_index = mine_order_index
                }
            end
        end
    end
end

function tas.get_craft_order_indexes(craft_order)
    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local craft_order_index = tas.scan_table_for_value(waypoint.craft_orders, function(order) return order end, craft_order)
            if craft_order_index ~= nil then
                return
                {
                    sequence = sequence,
                    sequence_index = sequence_index,
                    waypoint = waypoint,
                    waypoint_index = waypoint_index,
                    craft_order_index = craft_order_index
                }
            end
        end
    end
end

function tas.get_item_transfer_order_indexes(item_transfer_order)
    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local item_transfer_order_index = tas.scan_table_for_value(waypoint.item_transfer_orders, function(order) return order end, item_transfer_order)
            if item_transfer_order_index ~= nil then
                return
                {
                    sequence = sequence,
                    sequence_index = sequence_index,
                    waypoint = waypoint,
                    waypoint_index = waypoint_index,
                    item_transfer_order_index = item_transfer_order_index
                }
            end
        end
    end
end

-- Makes the player select a new waypoint
-- If selected_sequence_index is specified, the player will switch to that sequence. selected_sequence_index can not be nil
-- If selected_sequence_waypoint_index is nil or less than 1, the index is unselected
function tas.select_waypoint(player_index, selected_sequence_waypoint_index, selected_sequence_index)
    local player = global.players[player_index]

    if selected_sequence_waypoint_index ~= nil and selected_sequence_waypoint_index < 1 then
        selected_sequence_waypoint_index = nil
    end

    -- switch sequences
    if selected_sequence_index ~= nil then
        player.selected_sequence_index = selected_sequence_index
    end

    -- Remove the old highlight
    if player.selected_waypoint_highlight_entity ~= nil then
        player.selected_waypoint_highlight_entity.destroy()
    end

    player.selected_waypoint_highlight_entity = nil
    player.selected_sequence_waypoint_index = selected_sequence_waypoint_index

    if selected_sequence_waypoint_index == nil then

        tas.gui.hide_waypoint_info(player_index)
        return

    else

        -- Create the 'highlight' entity
        local waypoint = global.sequences[player.selected_sequence_index].waypoints[player.selected_sequence_waypoint_index]
        local new_highlight = waypoint.surface.create_entity { name = "tas-waypoint-selected", position = waypoint.position }
        player.selected_waypoint_highlight_entity = new_highlight

        -- Show the waypoint gui (or hide it if no waypoint is selected)
        tas.gui.show_waypoint_info(player_index, player.selected_sequence_index, player.selected_sequence_waypoint_index)

    end
end

function tas.move_waypoint(sequence_index, waypoint_index, new_waypoint_entity)
    local waypoint = global.sequences[sequence_index].waypoints[waypoint_index]

    -- clean up entities
    if waypoint.entity ~= nil and waypoint.entity.valid == true then
        waypoint.entity.destroy()
    end
    waypoint.entity = new_waypoint_entity

    if waypoint.text_entity ~= nil and waypoint.text_entity.valid == true then
        waypoint.text_entity.destroy()
    end

    waypoint.text_entity = tas.create_static_text(new_waypoint_entity.surface, new_waypoint_entity.position, util.integer_to_string(waypoint_index))
    waypoint.position = new_waypoint_entity.position

    -- update waypoint highlights
    for _, player in pairs(global.players) do
        if player.selected_sequence_index == sequence_index
            and player.selected_sequence_waypoint_index == waypoint_index
            and player.selected_waypoint_highlight_entity ~= nil then
            player.selected_waypoint_highlight_entity.destroy()
            player.selected_waypoint_highlight_entity = new_waypoint_entity.surface.create_entity { name = "tas-waypoint-selected", position = new_waypoint_entity.position }
        end
    end
end

function tas.realign_waypoint_indexes(sequence_index, start_index, shift)

    -- realign selected waypoint index
    for player_index, player in pairs(global.players) do
        if player.selected_sequence_waypoint_index ~= nil
            and player.selected_sequence_waypoint_index >= start_index then
            local new_selected_waypoint = math.max(player.selected_sequence_waypoint_index + shift, start_index - 1)

            -- selected waypoint underflow: select the first waypoint. or nothing if no waypoints exist in the sequence.
            if new_selected_waypoint < 1 then
                if #global.sequences[player.selected_sequence_index].waypoints > 0 then
                    new_selected_waypoint = 1
                else
                    new_selected_waypoint = nil
                end
            end

            tas.select_waypoint(player_index, new_selected_waypoint)
        end
    end

    local waypoints = global.sequences[sequence_index].waypoints

    -- realign waypoint entity text, skip entities < start_index
    for i = start_index, #waypoints do
        local waypoint = waypoints[i]
        if waypoint.text_entity ~= nil then
            waypoint.text_entity.destroy()
            waypoint.text_entity = tas.create_static_text(waypoint.surface, waypoint.position, util.integer_to_string(i))
        end
    end

end

function tas.insert_waypoint(waypoint_entity, player_index)

    local sequence_index = global.players[player_index].selected_sequence_index
    local sequence = global.sequences[sequence_index]
    local player = global.players[player_index]
    local player_entity = game.players[player_index]

    local waypoint_insert_index
    if #sequence.waypoints > 0 then
        waypoint_insert_index = player.selected_sequence_waypoint_index + 1
    else
        waypoint_insert_index = 1
    end

    --[[ shouldn't ever happen
    if waypoint_insert_index == nil then
        player_entity.print( { "TAS-warning-generic", "Please select a waypoint before placing a new one" })
        waypoint_entity.destroy()
        return
    end
    --]]

    local waypoint = tas.new_waypoint(waypoint_entity.surface, waypoint_entity.position, waypoint_insert_index, true, waypoint_entity)

    table.insert(sequence.waypoints, waypoint_insert_index, waypoint)

    tas.realign_waypoint_indexes(sequence_index, waypoint_insert_index, 1)

    tas.select_waypoint(player_index, waypoint_insert_index)
end

function tas.on_built_waypoint(created_entity, player_index)
    created_entity.destructible = false

    tas.ensure_first_sequence_initialized(true)

    local player = global.players[player_index]
    local sequence_index = player.selected_sequence_index
    local selected_waypoint_index = player.selected_sequence_waypoint_index
    local sequence = global.sequences[sequence_index]
    local selected_waypoint = sequence.waypoints[selected_waypoint_index]

    if player.gui.current_state == "move" and #sequence.waypoints > 0 then
        tas.move_waypoint(sequence_index, selected_waypoint_index, created_entity)
    else
        tas.insert_waypoint(created_entity, player_index)
    end
end

-- Creates a new build order table. ghost_entity can be nil.
function tas.new_build_order_from_ghost_entity(ghost_entity)

    local build_order_item_name = nil
    for name, entity in pairs(ghost_entity.ghost_prototype.items_to_place_this) do
        build_order_item_name = name
    end
    return
    {
        surface = ghost_entity.surface,
        position = ghost_entity.position,
        item_name = build_order_item_name,
        direction = ghost_entity.direction,
        entity = ghost_entity,
        entity_name = ghost_entity.ghost_name
    }
end

function tas.new_mine_order(entity, num_to_mine)
    return
    {
        position = entity.position,
        surface = entity.surface,
        count = num_to_mine,
        entity = entity
    }
end

function tas.set_mine_order_count(mine_order, new_count)
    local indexes = tas.get_mine_order_indexes(mine_order)

    if indexes == nil then return false end

    mine_order.count = new_count

    -- make calls into runner to synchronize changes
end

function tas.destroy_mine_order(mine_order)
    local indexes = tas.get_mine_order_indexes(mine_order)

    if indexes == nil then return false end

    table.remove(indexes.waypoint.mine_orders, indexes.mine_order_index)

    return true
end

function tas.on_built_ghost(created_ghost, player_index)
    if tas.runner.is_playing(player_index) then
        return
    end

    local player_data = tas.try_get_player_data(player_index)

    if player_data == nil then return end

    local build_order = tas.new_build_order_from_ghost_entity(created_ghost)

    table.insert(player_data.waypoint.build_orders, build_order)
end

function tas.on_built_entity(event)
    local created_entity = event.created_entity
    local player_index = event.player_index

    if created_entity.name == "tas-waypoint" then
        tas.on_built_waypoint(created_entity, player_index)
    elseif created_entity.name == "entity-ghost" then
        tas.on_built_ghost(created_entity, player_index)
    end
end

function tas.add_mine_order(player_index, entity)
    local player_data = tas.try_get_player_data(player_index)

    if player_data == nil then return end

    local find_result = tas.find_mine_order_from_entity_and_waypoint(entity, player_data.waypoint)

    if find_result ~= nil then
        if entity.type == "resource" then
            local existing_mine_order = find_result.mine_order
            existing_mine_order.count = existing_mine_order.count + 1
        end
    else
        local new_mine_order = tas.new_mine_order(entity, 1)
        table.insert(player_data.waypoint.mine_orders, new_mine_order)

        tas.update_players_hover()
    end
end

function tas.on_pre_mined_resource(player_index, resource_entity)
    local player_data = tas.try_get_player_data(player_index)

    if player_data == nil then return end

    -- undo the mine operation
    resource_entity.amount = resource_entity.amount + 1

    tas.add_mine_order(player_index, resource_entity)

    tas.gui.refresh(player_index)
end

function tas.on_pre_removing_waypoint(waypoint_entity)
    local find_result = tas.find_waypoint_from_entity(waypoint_entity)

    if find_result == nil then
        msg_all( { "TAS-err-generic", "Could not locate data for waypoint entity. This should never happen. Stacktrace: " .. debug.traceback() })
        return
    end

    local waypoint = find_result.waypoint

    -- Clean up waypoint data entry and floating text entity
    if waypoint.text_entity ~= nil and waypoint.text_entity.valid == true then
        waypoint.text_entity.destroy()
    end

    -- Remove the waypoint and shift all others to the left
    table.remove(find_result.sequence.waypoints, find_result.waypoint_index)

    -- All waypoint elements after waypoint_index have been shifted left.
    -- Any stored waypoint indexes > waypoint_index must be realigned.
    tas.realign_waypoint_indexes(find_result.sequence_index, find_result.waypoint_index, -1)
end

function tas.on_pre_removing_ghost(ghost_entity)
    local find_result = tas.find_build_order_from_entity(ghost_entity)

    if find_result == nil then return end

    table.remove(find_result.waypoint.build_orders, find_result.build_order_index)
end

function tas.on_pre_mined_entity(event)
    local player_index = event.player_index
    local robot = event.robot
    local entity = event.entity

    if player_index ~= nil then
        tas.runner.on_pre_mined_entity(player_index, entity)
    end

    if entity.name == "tas-waypoint" then
        tas.on_pre_removing_waypoint(entity)
    elseif entity.name == "entity-ghost" then
        -- Note: factorio doesn't fire this event if a player builds on top of a ghost
        tas.on_pre_removing_ghost(entity)
    elseif entity.type == "resource" then
        if not tas.runner.is_playing(player_index) then
            tas.on_pre_mined_resource(player_index, entity)
        end
    end
end

-- recipe may be a string or LuaRecipe.
-- count must be a positive number, nil denotes a count of 1.
function tas.new_craft_order(recipe, count)

    if count == nil then
        count = 1
    end

    return
    {
        count = count,
        recipe = recipe
    }
end

function tas.add_craft_order(waypoint, recipe, count)
    fail_if_missing(waypoint)
    fail_if_missing(recipe)
    fail_if_missing(count)

    local craft_orders = waypoint.craft_orders
    local crafting_queue_end = craft_orders[#craft_orders]

    -- Merge with the last order or append a new order to the end
    if crafting_queue_end ~= nil and recipe == crafting_queue_end.recipe then

        crafting_queue_end.count = crafting_queue_end.count + count

    else

        local craft_order = tas.new_craft_order(recipe, count)
        table.insert(waypoint.craft_orders, craft_order)

    end

end

function tas.destroy_craft_order(craft_order)
    local indexes = tas.get_craft_order_indexes(craft_order)

    if indexes == nil then return false end

    table.remove(indexes.waypoint.craft_orders, indexes.craft_order_index)

    return true
end

function tas.new_item_transfer_order(container_entity, is_player_receiving, player_inventory, container_inventory, items_to_transfer)
    if container_entity ~= util.get_inventory_owner(container_inventory) then
        error()
    end

    if items_to_transfer.count == nil then items_to_transfer.count = 1 end

    return
    {
        is_player_receiving = is_player_receiving,
        container_entity = container_entity,
        container_inventory = container_inventory,
        player_inventory = player_inventory,
        item_stack = items_to_transfer
    }
end

function tas.add_item_transfer_order(player_index, is_player_receiving, player_inventory, container_entity, container_inventory, items_to_transfer)
    local player_data = tas.try_get_player_data(player_index)
    if player_data == nil then error("Could not create a item transfer order because no waypoint was selected.") end
    local existing_orders = player_data.waypoint.item_transfer_orders

    local order = tas.new_item_transfer_order(container_entity, is_player_receiving, player_inventory, container_inventory, items_to_transfer)

    -- If we can't merge the order, append it
    if not tas.try_merge_item_transfer_order_with_collection(order, existing_orders) then
        table.insert(existing_orders, order)
    end


end

function tas.destroy_item_transfer_order(item_transfer_order)
    local indexes = tas.get_item_transfer_order_indexes(item_transfer_order)
    if indexes == nil then return false end

    table.remove(indexes.waypoint.item_transfer_orders, indexes.item_transfer_order_index)

    return true
end

function tas.can_item_transfer_orders_be_merged(order_a, order_b)
    return order_a.item_stack.name == order_b.item_stack.name
    and order_a.is_player_receiving == order_b.is_player_receiving
    and order_a.source_inventory == order_b.source_inventory
    and order_a.target_inventory == order_b.target_inventory
end

function tas.merge_item_transfer_orders(source, destination)
    if not tas.can_item_transfer_orders_be_merged(source, destination) then
        error("Attempted to merge two item transfer orders that are incompatible.")
    end

    destination.count = destination.item_stack.count + source.item_stack.count
    source.item_stack.count = 0
    -- Not actually needed for bug free code but let's throw this in for safety
end

function tas.try_merge_item_transfer_order_with_collection(item_transfer_order, item_transfer_order_collection)
    for existing_order_index, existing_order in ipairs(item_transfer_order_collection) do
        if tas.can_item_transfer_orders_be_merged(item_transfer_order, existing_order) then
            tas.merge_item_transfer_orders(item_transfer_order, existing_order)
            return true
        end
    end

    return false
end

function tas.on_crafted_item(event)
    local item_stack = event.item_stack
    local player_index = event.player_index

    if tas.runner.is_playing(player_index) then
        -- hook in replay crafting logic here?
        return
    end

    local player_entity = game.players[player_index]

    -- Determine the crafting recipe and store it as a runner crafting order
    -- This event is for each item crafted as well as what was clicked ("iron-axe" triggers
    -- both "iron-stick" with a count of 2 and "iron-axe" with a count of 1, assuming no "iron-sticks" are in the player's inventory)
    -- The trick to determine the top-level recipe is to set player.cheat_mode=true so that on_crafted_item fires exactly once when clicking the button to craft.

    -- Only works in factorio 0.15+ -- recipe = event.recipe
    local recipe = game.players[player_index].force.recipes[item_stack.name]

    if player_entity.cheat_mode == false then
        error("Can not determine crafted item because cheat-mode is not enabled for " .. player_entity.name .. ".")
    end

    if #recipe.products ~= 1 then
        error("No support for crafting recipes with zero or multiple products.")
    end

    local player_data = tas.try_get_player_data(player_index)
    if player_data == nil then error("Could not create a craft order because no waypoint was selected.") end
    util.remove_item_stack(player_entity.character, item_stack, constants.character_inventories, player_entity)
    tas.add_craft_order(player_data.waypoint, recipe, item_stack.count / recipe.products[1].amount)
    tas.gui.refresh(player_index)

end

function tas.on_clicked_waypoint(player_index, waypoint_entity)
    local indexes = tas.find_waypoint_from_entity(waypoint_entity)
    tas.select_waypoint(player_index, indexes.waypoint_index, indexes.sequence_index)
end

function tas.on_clicked_ghost(player_index, ghost_entity)
    local build_order_indexes = tas.find_build_order_from_entity(ghost_entity)

    if build_order_indexes == nil then return end

    tas.select_waypoint(player_index, build_order_indexes.waypoint_index, build_order_indexes.sequence_index)
end

function tas.on_left_click(event)
    local player_index = event.player_index
    local player = game.players[player_index]

    if player.selected == nil then return end

    local entity = player.selected
    local entity_name = entity.name

    if entity_name == "tas-waypoint" then
        tas.on_clicked_waypoint(player_index, entity)
    elseif entity_name == "entity-ghost" then
        tas.on_clicked_ghost(player_index, entity)
    else
        tas.gui.show_entity_info(player_index, entity)
    end
end

function tas.update_player_hover(player, player_entity)
    -- delete arrow collection
    for _, arrow in ipairs(player.hover_arrows) do
        tas.destroy_arrow(arrow)
    end

    player.hover_arrows = { }

    -- can be null
    local player_data = tas.try_get_player_data(player_entity.index)
    local selected = player_entity.selected

    player.hover_entity = selected

    if selected == nil then
        return
    end

    -- check if it's a build order
    local find_result = tas.find_build_order_from_entity(selected)
    if find_result ~= nil then
        if find_result.build_order.entity ~= nil and find_result.waypoint.entity ~= nil then
            local arrow = tas.create_arrow(find_result.build_order.entity, find_result.waypoint.entity)
            tas.insert_arrow_into_auto_update_respository(arrow)
            table.insert(player.hover_arrows, arrow)
        end
        return
    elseif selected.name == "tas-waypoint" then

        local find_result = tas.find_waypoint_from_entity(selected)
        if find_result == nil then
            msg_all( { "TAS-err-generic", "Orphan waypoint" })
            return
        end

        local waypoint = find_result.waypoint;

        -- create arrows to waypoints adjacent to this one
        local prev = find_result.sequence.waypoints[find_result.waypoint_index - 1]
        if prev ~= nil and prev.entity ~= nil and prev.entity.valid == true then
            local arrow = tas.create_arrow(prev.entity, selected)
            tas.insert_arrow_into_auto_update_respository(arrow)
            table.insert(player.hover_arrows, arrow)
        end

        local next_ = find_result.sequence.waypoints[find_result.waypoint_index + 1]
        if next_ ~= nil and next_.entity ~= nil and next_.entity.valid == true then
            local arrow = tas.create_arrow(selected, next_.entity)
            tas.insert_arrow_into_auto_update_respository(arrow)
            table.insert(player.hover_arrows, arrow)
        end

        -- create arrows to all mine orders
        for _, mine_order in ipairs(waypoint.mine_orders) do
            if mine_order.entity ~= nil and mine_order.entity.valid == true then
                local arrow = tas.create_arrow(selected, mine_order.entity)
                tas.insert_arrow_into_auto_update_respository(arrow)
                table.insert(player.hover_arrows, arrow)
            end
        end

    else
        local orders = tas.find_mine_orders_from_entity(selected)
        if #orders > 0 then
            for _, indexes in ipairs(orders) do
                local arrow = tas.create_arrow(indexes.mine_order.entity, indexes.waypoint.entity)
                tas.insert_arrow_into_auto_update_respository(arrow)
                table.insert(player.hover_arrows, arrow)
            end
        end

        return
    end
end

function tas.update_players_hover()
    for player_index, player_entity in pairs(game.connected_players) do
        local player = global.players[player_index]
        tas.update_player_hover(player, player_entity)
    end
end

function tas.is_player_hover_target_changed(player, player_entity)
    return player.hover_entity ~= player_entity.selected
end

function tas.check_player_hovering_entities(player_index)
    local player_entity = game.players[player_index]
    local player = global.players[player_index]

    if tas.is_player_hover_target_changed(player, player_entity) then
        tas.update_player_hover(player, player_entity)
    end
end

function tas.check_players_hovering_entities()
    for player_index, player in pairs(game.connected_players) do
        tas.check_player_hovering_entities(player_index)
    end
end

function tas.update_arrow_repository()
    local arrows_to_remove = { }

    for _, arrow in pairs(global.arrow_auto_update_repository) do
        if arrow.disposed == true then
            table.insert(arrows_to_remove, arrow)
        else
            local arrow_visible = tas.update_arrow(arrow)
            if arrow_visible == false then
                tas.destroy_arrow(arrow)
                return table.insert(arrows_to_remove, arrow)
            end
        end
    end

    for _, arrow in ipairs(arrows_to_remove) do
        global.arrow_auto_update_repository[arrow] = nil
    end
end

function tas.insert_arrow_into_auto_update_respository(arrow_facade)
    if arrow_facade == nil then error() end

    global.arrow_auto_update_repository[arrow_facade] = arrow_facade
end

function tas.update_debug_entity_count()
    local num_api_objects = 0
    for _, field in collections.pairs_recursive(global, "table") do
        if type(field) == "userdata" or type(field.__self) == "userdata" then
            num_api_objects = num_api_objects + 1
        end
    end

    tas.gui.set_entity_reference_count(num_api_objects)
end

function tas.on_tick(event)
    tas.check_players_hovering_entities()

    tas.update_arrow_repository()

    -- if constants.debug == true then
    -- tas.update_debug_entity_count()
    -- end

    tas.runner.on_tick()
end
