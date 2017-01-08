tas = { }

function tas.log(level, message)
    if level == "debug" then
        msg_all(message)
    end
end

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

function tas.init_globals()
    global.sequences = { }
    global.players = { }

    tas.runner.init_globals()
    tas.gui.init_globals()
end

function tas.on_player_created(event)
    local player_index = event.player_index

    global.players[player_index] = { }

    --  select the first sequence if any exist
    if #global.sequences > 0 then
        global.players[player_index].selected_sequence_index = 1
    end

    tas.gui.init_player(player_index)
end

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
        build_orders = { }
    }
end

-- creates a new sequence and returns it's index in the sequence table
function tas.new_sequence(add_spawn_waypoint)
    local sequence_index = #global.sequences + 1


    local sequence = {
        waypoints = { }
    }

    if add_spawn_waypoint == true then
        local surface = game.surfaces["nauvis"]
        local origin = { x = 0, y = 0 }

        sequence.waypoints[1] = tas.new_waypoint(surface, origin, 1, true)
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
        game.print("Placing the initial waypoint at spawn..")
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

function tas.remove_sequence(sequence_index)
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

function tas.find_waypoint_from_entity(waypoint_entity)
    -- iterate all waypoints of all sequences to find a match
    for sequence_index, sequence in ipairs(global.sequences) do

        local waypoint_data_index = tas.scan_table_for_value(sequence.waypoints, function(waypoint) return waypoint.entity end, waypoint_entity)
        if waypoint_data_index ~= nil then
            return { sequence_index = sequence_index, waypoint_index = waypoint_data_index }
        end
    end
end

function tas.find_build_order_from_entity(ghost_entity)
    for sequence_index, sequence in ipairs(global.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local build_order_index = tas.scan_table_for_value(waypoint.build_orders, function(build_order) return build_order.entity end, ghost_entity)
            if build_order_index ~= nil then
                return { sequence_index = sequence_index, waypoint_index = waypoint_index, build_order_index = build_order_index }
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

    if selected_sequence_waypoint_index == nil then return end

    -- Create the 'highlight' entity
    local waypoint = global.sequences[player.selected_sequence_index].waypoints[selected_sequence_waypoint_index]
    local new_highlight = waypoint.surface.create_entity { name = "tas-waypoint-selected", position = waypoint.position }
    player.selected_waypoint_highlight_entity = new_highlight
end

function tas.move_waypoint(sequence_index, waypoint_index, new_waypoint_entity)
    local waypoint = global.sequences[sequence_index].waypoints[waypoint_index]

    if waypoint.entity ~= nil then
        waypoint.entity.destroy()
    end
    waypoint.entity = new_waypoint_entity
    if waypoint.text_entity ~= nil then
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
function tas.new_build_order_from_ghost_entity(ghost_entity, item_to_place_prototype)
    return
    {
        surface = ghost_entity.surface,
        position = ghost_entity.position,
        item_name = item_to_place_prototype.name,
        direction = ghost_entity.direction,
        entity = ghost_entity,
        entity_name = ghost_entity.ghost_name
    }
end

function tas.on_built_ghost(created_ghost, player_index)
    local player = global.players[player_index]
    local waypoint_index = player.selected_sequence_waypoint_index
    local cursor_stack = game.players[player_index].cursor_stack

    if cursor_stack.valid_for_read == false or cursor_stack.name == nil then
        error("Could not create a build order because the item used to place it (LuaPlayer.item_stack) is nil or empty.")
    elseif cursor_stack.prototype.place_result ~= created_ghost.ghost_prototype then
        error("Could not create a build order because the ghost and the item held in the players hand do not match.")
    end

    if waypoint_index == nil then return end

    local sequence_index = player.selected_sequence_index
    local sequence = global.sequences[sequence_index]
    local waypoint = sequence.waypoints[waypoint_index]

    local build_order = tas.new_build_order_from_ghost_entity(created_ghost, cursor_stack.prototype)

    table.insert(waypoint.build_orders, build_order)
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

function tas.on_pre_removing_waypoint(waypoint_entity)
    local waypoint_index = nil
    local indexes = tas.find_waypoint_from_entity(waypoint_entity)

    if indexes == nil then
        msg_all( { "TAS-err-generic", "Could not locate data for waypoint entity. This should never happen. Stacktrace: " .. debug.traceback() })
        return
    end

    local waypoints = global.sequences[indexes.sequence_index].waypoints
    local waypoint_index = indexes.waypoint_index
    local waypoint = waypoints[waypoint_index]

    -- Clean up waypoint data entry and floating text entity
    if waypoint.text_entity ~= nil then
        waypoint.text_entity.destroy()
        waypoint.text_entity = nil
    end

    -- Remove the waypoint and shift all others to the left
    table.remove(waypoints, waypoint_index)

    -- All waypoint elements after waypoint_index have been shifted left.
    -- Any stored waypoint indexes > waypoint_index must be realigned.
    tas.realign_waypoint_indexes(indexes.sequence_index, waypoint_index, -1)
end

function tas.on_pre_removing_ghost(ghost_entity)
    local indexes = tas.find_build_order_from_entity(ghost_entity)

    if indexes == nil then return end

    table.remove(global.sequences[indexes.sequence_index].waypoints[indexes.waypoint_index].build_orders, indexes.build_order_index)
end

function tas.on_pre_removing_entity(event)
    local entity = event.entity

    if entity.name == "tas-waypoint" then
        tas.on_pre_removing_waypoint(entity)
    elseif entity.name == "entity-ghost" then
        tas.on_pre_removing_ghost(entity)
    end
end

function tas.on_clicked_waypoint(player_index, waypoint_entity)
    local indexes = tas.find_waypoint_from_entity(waypoint_entity)
    global.players[player_index].selected_sequence_index = indexes.sequence_index
    tas.select_waypoint(player_index, indexes.waypoint_index)
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
    local entity_name = player.selected.name

    if entity_name == "tas-waypoint" then
        tas.on_clicked_waypoint(player_index, player.selected)
    elseif entity_name == "entity-ghost" then
        tas.on_clicked_ghost(player_index, player.selected)
    end
end

function tas.on_tick(event)
    tas.runner.on_tick()
end