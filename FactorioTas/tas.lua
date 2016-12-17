tas = { }

function tas.log(level, message)
    if level == "debug" then
        msg_all(message)
    end
end

function tas.integer_to_string(int)
    return string.format("%.0f", int)
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
    global.players = { }
end

function tas.on_player_created(event)
    local player_index = event.player_index

    tas.log("debug", "initializing player: " .. player_index)

    global.players[player_index] = { }
    global.players[player_index].sequence = { }
    global.players[player_index].selected_player_index = player_index

    tas.gui.init_player(player_index)
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
    for key, val in ipairs(table) do
        if value == selector(val) then
            return key
        end
    end
end

function tas.find_waypoint_from_entity(waypoint_entity)
    -- iterate all waypoints of all players to find a match
    for player_index, player in pairs(global.players) do

        waypoint_data_index = tas.scan_table_for_value(player.sequence, function(node) return node.entity end, waypoint_entity)
        if waypoint_data_index ~= nil then
            return { player_index = player_index, waypoint_index = waypoint_data_index }
        end
    end
end

-- Makes the player select a new waypoint
-- If waypoint_index is nil or less than 1, the index is unselected
function tas.select_waypoint(player_index, selected_player_waypoint_index)
    if selected_player_waypoint_index < 1 then
        selected_player_waypoint_index = nil
    end

    local player = global.players[player_index]
    local selected_player = global.players[player.selected_player_index]

    -- Remove the old highlight
    if player.selected_waypoint_highlight_entity ~= nil then
        player.selected_waypoint_highlight_entity.destroy()
    end

    player.selected_waypoint_highlight_entity = nil
    player.selected_player_waypoint_index = selected_player_waypoint_index

    if selected_player_waypoint_index == nil then return end

    -- Create the 'highlight' entity
    local waypoint_data = selected_player.sequence[selected_player_waypoint_index]
    local new_highlight = waypoint_data.surface.create_entity { name = "tas-waypoint-selected", position = waypoint_data.position }
    player.selected_waypoint_highlight_entity = new_highlight
end

function tas.move_waypoint(player_index, waypoint_index, new_waypoint_entity)
    local waypoint = global.players[player_index].sequence[waypoint_index]

    if waypoint.entity ~= nil then
        waypoint.entity.destroy()
    end
    waypoint.entity = new_waypoint_entity
    if waypoint.text_entity ~= nil then
        waypoint.text_entity.destroy()
    end
    waypoint.text_entity = tas.create_static_text(new_waypoint_entity.surface, new_waypoint_entity.position, tas.integer_to_string(waypoint_index))
    waypoint.position = new_waypoint_entity.position

    -- update waypoint highlights
    for _, player in pairs(global.players) do
        if player.selected_player == player_index
            and player.selected_player_waypoint_index == waypoint_index
            and player.selected_waypoint_highlight_entity ~= nil then
            player.selected_waypoint_highlight_entity.destroy()
            player.selected_waypoint_highlight_entity = new_waypoint_entity.surface.create_entity { name = "tas-waypoint-selected", position = new_waypoint_entity.position }
        end
    end
end

-- Finds the location in the sequence in which a new waypoint should be placed.
-- Returns the index, or nil if  
function tas.find_waypoint_insertion_index(selected_element, sequence)
    if selected_element == nil then
        if #sequence > 0 then
            -- If waypoints already exist, one must be selected.
            return nil
        end

        -- append waypoint to the empty sequence
        return 1

        -- elseif selected_element.type == "waypoint-edge" then
        --    return tas.scan_table_for_value(sequence, function(val) return val end, selected_element)

    elseif selected_element.type == "waypoint" then
        return tas.scan_table_for_value(sequence, function(val) return val end, selected_element) + 1
    end
end

function tas.insert_waypoint(waypoint_entity, player_index)

    local selected_player_index = global.players[player_index].selected_player_index
    local selected_player = global.players[selected_player_index]
    local selected_waypoint_index = global.players[player_index].selected_player_waypoint_index
    local selected_waypoint = selected_player.sequence[selected_waypoint_index]
    local sequence = selected_player.sequence
    local player = global.players[player_index]
    local player_entity = game.players[player_index]

    local sequence_insert_index = tas.find_waypoint_insertion_index(selected_waypoint, sequence)

    if sequence_insert_index == nil then
        player_entity.print( { "TAS-warning-generic", "Please select a waypoint before placing a new one" })
        waypoint_entity.destroy()
        return
    end

    local waypoint_text_entity = tas.create_static_text(waypoint_entity.surface, waypoint_entity.position, tas.integer_to_string(sequence_insert_index))

    local waypoint_data = { type = "waypoint", position = waypoint_entity.position, surface = waypoint_entity.surface, entity = waypoint_entity, text_entity = waypoint_text_entity }
    table.insert(sequence, sequence_insert_index, waypoint_data)

    tas.realign_sequence_indexes(selected_player_index, sequence, sequence_insert_index, 1)

    tas.select_waypoint(player_index, sequence_insert_index)
end

function tas.on_built_waypoint(created_entity, player_index)
    created_entity.destructible = false

    local selected_player_index = global.players[player_index].selected_player_index
    local selected_player = global.players[selected_player_index]
    local selected_waypoint_index = global.players[player_index].selected_player_waypoint_index
    local selected_waypoint = selected_player.sequence[selected_waypoint_index]
    local player = global.players[player_index]

    if player.gui.current_state == "move" then
        tas.move_waypoint(selected_player_index, selected_waypoint_index, created_entity)
    else
        tas.insert_waypoint(created_entity, player_index)
    end
end

function tas.on_built_entity(event)
    local created_entity = event.created_entity
    local player_index = event.player_index

    if created_entity.name == "tas-waypoint" then
        tas.on_built_waypoint(created_entity, player_index)
    end
end

function tas.on_pre_removing_waypoint(waypoint_entity)
    local waypoint_index = nil
    local indexes = tas.find_waypoint_from_entity(waypoint_entity)

    if indexes == nil then
        msg_all( { "TAS-error-generic", "Could not locate data for waypoint entity. This should never happen. Stacktrace: " .. debug.traceback() })
        return
    end

    local waypoint_index = indexes.waypoint_index
    local sequence = global.players[indexes.player_index].sequence

    -- Clean up waypoint data entry and floating text entity
    local waypoint = sequence[waypoint_index]

    if waypoint.text_entity ~= nil then
        waypoint.text_entity.destroy()
        waypoint.text_entity = nil
    end

    -- Remove the waypoint and shift all others to the left
    table.remove(sequence, waypoint_index)

    -- All sequence elements after waypoint_index have been shifted left.
    -- Any stored sequence indexes > waypoint_index must be realigned.
    tas.realign_sequence_indexes(owner_index, sequence, waypoint_index, -1)
end

function tas.realign_sequence_indexes(player_index, sequence, start_index, shift)

    -- realign selected waypoint index
    for player_index, player in pairs(global.players) do
        if player.selected_player_waypoint_index ~= nil
            and player.selected_player_waypoint_index >= start_index then
            local new_selected_waypoint = math.max(player.selected_player_waypoint_index + shift, start_index - 1)
            tas.select_waypoint(player_index, new_selected_waypoint)
        end
    end

    -- realign waypoint entity text, skip entities < start_index
    for i = start_index, #sequence do
        local waypoint = sequence[i]
        if waypoint.text_entity ~= nil then
            waypoint.text_entity.destroy()
            waypoint.text_entity = tas.create_static_text(waypoint.surface, waypoint.position, tas.integer_to_string(i))
        end
    end

end

function tas.on_pre_removing_entity(event)
    local entity = event.entity

    if entity.name == "tas-waypoint" then
        tas.on_pre_removing_waypoint(entity)
    end
end

function tas.on_clicked_waypoint(player_index, waypoint_entity)
    local indexes = tas.find_waypoint_from_entity(waypoint_entity)
    global.players[player_index].selected_player = indexes.player_index
    tas.select_waypoint(player_index, indexes.waypoint_index)
end

function tas.on_left_click(event)
    local player_index = event.player_index
    local player = game.players[player_index]

    if player.selected ~= nil and player.selected.name == "tas-waypoint" then
        tas.on_clicked_waypoint(player_index, player.selected)
    end
end