tas = { }

function tas.log(level, message)
    if level == "debug" then
        msg_all(message)
    end
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
    global.players[player_index].visible_sequence_entities = { }
    global.players[player_index].visible_sequence_position = 0
    global.players[player_index].visible_sequence_length = 10

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
function tas.scan_table_for_value(table, value)
    for key, val in table do
        if value == val then
            return key
        end
    end
end

--[[
function tas.update_visible_sequence(player_index)
    local player = global.players[player_index]

    local selected_player_index = player.selected_player_index
    local selected_player = global.players[selected_player_index]
    local sequence = selected_player.sequence

    local new_entities = { }

    local visible_sequence_end = player.visible_sequence_position + player.visible_sequence_length
    for i = player.visible_sequence_position, visible_sequence_end do

        local node = sequence[i]
        if node == nil then
            -- The visible range goes beyond the end of the sequence
            -- Attempt to shift back into range of the sequence, then stop enumerating
            local new_visible_sequence_end = i - 1
            player.visible_sequence_position = new_visible_sequence_end - player.visible_sequence_length
            if player.visible_sequence_position < 1 then
                player.visible_sequence_position = 1
            end
            break
        end


    end
end
--]]

function tas.on_built_waypoint(created_entity, player_index)
    local selected_element = global.players[player_index].selected_element
    local selected_player_index = global.players[player_index].selected_player_index
    local selected_player = global.players[selected_player_index]
    local sequence = selected_player.sequence
    local player = game.players[player_index]

    local new_waypoint = { type = "waypoint", position = created_entity.position, entity = created_entity }

    if selected_element == nil then
        if #selected_player.sequence > 0 then
            -- should use locality here
            player.print( { "TAS-warning-generic", "Please select a waypoint before placing a new one" })
        end

        -- append waypoint to the end of the sequence
        sequence[#sequence + 1] = new_waypoint

    elseif selected_element.type == "waypoint-edge" then
        local insert_index = tas.scan_table_for_value(sequence, selected_element.destination)
        table.insert(sequence, insert_index, waypoint)

    elseif selected_element.type == "waypoint" then
        if sequence[1] == selected_element then
            table.insert(sequence, 1, waypoint)
        elseif sequence[#sequence] == selected_element then
            table.insert(sequence, #sequence + 1, waypoint)
        else
            -- the selected waypoint must be at the start or end of the sequence
            player.print( { "TAS-warning-generic", "Please select a waypoint edge before placing a new one" })
        end
    end
end

function tas.on_built_entity(event)
    local created_entity = event.created_entity
    local player_index = event.player_index

    if created_entity.name == "tas-waypoint" then
        tas.on_built_waypoint(created_entity, player_index)
    elseif created_entity.name == "tas-build" then

    end
end