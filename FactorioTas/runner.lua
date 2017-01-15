tas.runner =
{
    playback_state =
    {
        paused = { },
        playing = { },
        tick_1_prepare_to_attach_runner = { },
        tick_2_attach_runner = { },
        tick_3_running = { },
        tick_4_prepare_to_attach_player = { },
        tick_5_attach_player = { }
    },

    playback_mode =
    {
        playing = { },
        stepping = { }
    }
}

function tas.runner.init_globals()
    global.runner_state = { }
    global.runner_state.playback_state = tas.runner.playback_state.paused
end

-- Create a new runner and character entity
-- Returns nil if sequence is empty
function tas.runner.new_runner(sequence)
    local start = sequence.waypoints[1]

    if start == nil then
        return nil
    end

    global.runner = {
        sequence = sequence,
        waypoint_index = 1,
        active_build_orders = { },
        build_state = { },
        character = start.surface.create_entity { name = "player", position = start.position, force = "player" },
    }
    tas.runner.activate_build_orders_in_waypoint(global.runner, 1)
end

-- Removes (and murders) the runner.
-- Returns if the runner was alive.
function tas.runner.remove_runner()
    if global.runner == nil then
        return false
    end

    -- murder it
    if global.runner.character.valid then
        if global.runner.character.destroy() == false then
            msg_all( { "TAS-err-generic", "couldn't destroy character :( pls fix" })
        end
    end

    global.runner = nil
end

function tas.runner.runner_exists()
    return global.runner ~= nil
end

function tas.runner.ensure_runner_initialized()
    tas.ensure_first_sequence_initialized(true)

    if tas.runner.runner_exists() == false then
        tas.runner.new_runner(global.sequences[1])
    end
end

function tas.runner.get_direction_to_waypoint(character, waypoint)
    local walking_speed = util.get_walking_speed(character)
    return util.get_directions(character.position, waypoint.position, walking_speed)
end

-- returns if the character has arrived at the waypoint
function tas.runner.move_towards_waypoint(character, waypoint)
    local direction_to_waypoint = tas.runner.get_direction_to_waypoint(character, waypoint)
    character.walking_state = { walking = direction_to_waypoint ~= nil, direction = direction_to_waypoint }
end

function tas.runner.activate_build_orders_in_waypoint(runner, waypoint_index)
    for _, build_order in ipairs(runner.sequence.waypoints[waypoint_index].build_orders) do
        table.insert(runner.active_build_orders, build_order)
    end
end

-- Returns if the build order was active and was deactivated
function tas.runner.try_deactivate_build_order(runner, build_order)
    local index = tas.scan_table_for_value(runner.active_build_orders, function(order) return order end, build_order)

    if index == nil then return false end

    return table.remove(runner.active_build_orders, index) ~= nil
end

function tas.runner.move_items(target_stack, source_stack, character, overflow_inventories)
    if target_stack == source_stack then return end

    -- move items out of the stack
    if target_stack.valid_for_read == true then
        local inserted_count = util.insert_into_inventories(character, overflow_inventories, target_stack)
        target_stack.count = target_stack.count - inserted_count

        if target_stack.valid_for_read == true and target_stack.count ~= 0 then
            -- valid_for_read may switch to false when count = 0
            return false
        end
    end

    target_stack.clear()

    if target_stack.set_stack(source_stack) == false then
        return false
    end
    source_stack.clear()

    return true
end

function tas.runner.can_reach_build_order(character, build_order)
    local hittest_entity = build_order.entity

    if hittest_entity == nil then
        -- Create an ephemeral entity to run a hit-test against.
        -- Ghost entities flashing into and out of existance may mess with construction robots, not sure.
        hittest_entity = build_order.surface.create_entity( { name = build_order.entity_name, position = build_order.position, direction = build_order.direction })
    end

    -- The function character.can_reach_entity() is off limits because
    -- it will always return true for entities such as ghost.

    local selection_box_world_space = math.rectangle.translate(hittest_entity.prototype.selection_box, hittest_entity.position)
    local distance = math.distance_rectangle_to_point(selection_box_world_space, character.position)
    local can_reach = distance < util.get_build_distance(character) -0.5
    -- Include a 0.5 margin of error because this isn't the exact reach distance formula.

    if build_order.entity == nil then
        -- destroy the ephemeral entity that was created earlier in the function
        hittest_entity.destroy()
    end

    return can_reach
end

function tas.runner.try_build_object(player, build_order)
    -- build_order.surface.create_entity( { name = build_order.entity_name, position = build_order.position, direction = build_order.direction })
    -- in the future, calculate the players zoom
    player.zoom = 1
    player.cursor_position = util.surface_to_screen_position(build_order.position, player.position, 1, constants.indev_screen_resolution)
    local cursor = "empty";
    if player.cursor_stack.valid_for_read then
        cursor = player.cursor_stack.name
    end
    msg_all("placing " .. build_order.item_name .. ", cursor: " .. cursor)

    return player.build_from_cursor(click_position)
end

function tas.runner.tear_down_build_state(runner, remove_build_order)
    if remove_build_order == true then
        table.remove(runner.active_build_orders, runner.in_progress_build_order_index)
    end

    runner.in_progress_build_order = nil
    runner.in_progress_build_order_index = nil
    runner.build_order_progress = nil
end

function tas.runner.step_build_state(runner, player)
    local character = runner.character

    if runner.in_progress_build_order == nil then
        -- find the next build order
        for build_order_index, build_order in ipairs(runner.active_build_orders) do
            if tas.runner.can_reach_build_order(character, build_order) then
                runner.in_progress_build_order = build_order
                runner.in_progress_build_order_index = build_order_index
                runner.build_order_progress = 1
                break
            end
        end
    end

    -- build_order_progress tracks the current tick in this multi-tick procedure
    if runner.build_order_progress == 1 then
        -- tick 1: Swap contents of players hand with the item to place
        local item_to_place = util.find_item_stack(character, constants.character_inventories, runner.in_progress_build_order.item_name)

        if item_to_place == nil then
            msg_all( { "TAS-err-generic", "Could not place " .. runner.in_progress_build_order.item_name .. " because it wasn't in the inventory." })
            tas.runner.tear_down_build_state(runner, true)
            return
        end

        if tas.runner.move_items(player.cursor_stack, item_to_place, character, constants.character_inventories) == true then
            runner.build_order_progress = 2
        else
            msg_all( { "TAS-err-generic", "Could not move items from the players hand into inventory because there wasn't room. Cheating and deleting extra items.." })
            player.cursor_stack.clear()
            tas.runner.move_items(player.cursor_stack, item_to_place, character, constants.character_inventories)
        end
    elseif runner.build_order_progress == 2 then
        -- tick 2: move cursor, place the item, and return item stack to inventory

        -- Move items to the players hand once again incase the player was controlled at some point.
        -- This is technically not cheating because we did this last tick.
        local item_to_place = player.cursor_stack
        if item_to_place.valid_for_read == false or item_to_place.name ~= runner.in_progress_build_order.item_name then
            item_to_place = util.find_item_stack(character, constants.character_inventories, runner.in_progress_build_order.item_name)
        end
        if item_to_place == nil then
            msg_all( { "TAS-err-generic", "Could not place " .. runner.in_progress_build_order.item_name .. " because it wasn't in the inventory." })
            tas.runner.tear_down_build_state(runner, true)
            return
        end

        tas.runner.move_items(player.cursor_stack, item_to_place, character, constants.character_inventories)

        -- Check for collisions with terrain or other entities.
        if runner.in_progress_build_order.surface.can_place_entity( {
                name = runner.in_progress_build_order.entity_name,
                position = runner.in_progress_build_order.position,
                direction = runner.in_progress_build_order.direction,
                force = character.force
            } ) == false then
            msg_all( { "TAS-err-generic", "Couldn't place a " .. runner.in_progress_build_order.entity_name .. " at {" .. runner.in_progress_build_order.position.x .. "," .. runner.in_progress_build_order.position.y .. "} because something was in the way." })
            tas.runner.tear_down_build_state(runner, true)

            -- Check if the character ran out of placement range since last tick.
        elseif tas.runner.can_reach_build_order(character, runner.in_progress_build_order) == false then
            msg_all( { "TAS-err-generic", "Couldn't place a " .. runner.in_progress_build_order.entity_name .. " at {" .. runner.in_progress_build_order.position.x .. "," .. runner.in_progress_build_order.position.y .. "} because the player left the area while putting the item in hand. Will retry." })
            tas.runner.tear_down_build_state(runner, false)

            -- Actually place the entity. This may"Couldn't place a " .. runner.in_progress_build_order.entity_name .. " at {" .. runner.in_progress_build_order.position.x .. ","..runner.in_progress_build_order.position.y .. "} because  fail for reasons not explained in the docs.
        elseif tas.runner.try_build_object(player, runner.in_progress_build_order) == false then
            -- ?? failed to place the object. FUUUCK, something should be done here
            -- Could be due to:
            -- Was in range of placement last tick, but walked out of range
            -- Ghosts, man
            -- Never fails because it may collide with other objects
            msg_all( { "TAS-err-generic", "Failed to place object {} at position {} for an unknown reason." })
            tas.runner.tear_down_build_state(runner, true)
        else
            -- successsssss
            tas.runner.tear_down_build_state(runner, true)
        end
    end
end

function tas.runner.are_waypoint_goals_satisfied(runner, player)
    local waypoint = runner.sequence.waypoints[runner.waypoint_index]
    local walking_state = tas.runner.get_direction_to_waypoint(runner.character, waypoint)

    -- Does the character have to walk to the next goal
    if walking_state ~= nil then
        return false
    end

    return true
end

function tas.runner.step_runner(runner, attachable_player)
    local waypoint = runner.sequence.waypoints[runner.waypoint_index]
    local character = runner.character

    -- check construction
    tas.runner.step_build_state(runner, attachable_player)

    -- walk towards waypoint
    tas.runner.move_towards_waypoint(character, runner.sequence.waypoints[runner.waypoint_index])

    -- move ahead in the sequence
    while tas.runner.are_waypoint_goals_satisfied(runner) == true do
        if runner.waypoint_index == #runner.sequence.waypoints then
            -- sequence complete
            break
        end

        runner.waypoint_index = runner.waypoint_index + 1
        tas.runner.move_towards_waypoint(character, runner.sequence.waypoints[runner.waypoint_index])
        tas.runner.activate_build_orders_in_waypoint(runner, runner.waypoint_index)
    end
end

function tas.runner.on_tick()
    if tas.runner.runner_exists() == false then return end

    local runner = global.runner
    local player = game.players[global.runner_state.playback_player_index]

    if global.runner_state.playback_state == tas.runner.playback_state.tick_1_prepare_to_attach_runner then

        tas.runner.prepare_to_attach_player(player)

        global.runner_state.playback_state = tas.runner.playback_state.tick_2_attach_runner

    elseif global.runner_state.playback_state == tas.runner.playback_state.tick_2_attach_runner then

        tas.runner.attach_player(player, global.runner.character)

        global.runner_state.playback_state = tas.runner.playback_state.tick_3_running

    elseif global.runner_state.playback_state == tas.runner.playback_state.tick_3_running then

        tas.runner.step_runner(runner, player)

        -- decrement num_ticks_to_step and check if we should start to pause
        if global.runner_state.num_ticks_to_step ~= nil then
            global.runner_state.num_ticks_to_step = global.runner_state.num_ticks_to_step - 1

            if global.runner_state.num_ticks_to_step == 0 then
                global.runner_state.playback_state = tas.runner.playback_state.tick_4_prepare_to_attach_player
            end
        end

    elseif global.runner_state.playback_state == tas.runner.playback_state.tick_4_prepare_to_attach_player then

        tas.runner.prepare_to_attach_player(player)

        global.runner_state.playback_state = tas.runner.playback_state.tick_5_attach_player

    elseif global.runner_state.playback_state == tas.runner.playback_state.tick_5_attach_player then

        local player_original_character = global.runner_state.playback_player_original_character
        tas.runner.attach_player(player, player_original_character)

        global.runner_state.playback_state = tas.runner.playback_state.paused

    end

end

function tas.runner.prepare_to_attach_player(player_entity)

    -- Make character stand still
    if player_entity.character ~= nil then
        player_entity.character.walking_state = { walking = false }
    end

    -- move items from cursor to inventory.
    if player_entity.cursor_stack.valid_for_read == true then
        player_entity.get_inventory(defines.inventory.player_main).insert(player_entity.cursor_stack)
        player_entity.cursor_stack.clear()
    end

    -- ensure zoom is reasonable.
    -- If we can determine screen resolution and zoom, then we can just ensure zoom is >= 1
    player_entity.zoom = 1

    -- need to: reset player build rotation to 0
    -- determine screen resolution by creating placeable-off-grid entity

end

-- if character is nil, the player enters god mode
function tas.runner.attach_player(player_entity, character)
    if character ~= nil then
        player_entity.set_controller( { type = defines.controllers.character, character = character })
    else
        player_entity.set_controller( { type = defines.controllers.god })
    end
end

-- setting num_ticks_to_step to nil denotes that it will step indefinitely
function tas.runner.play(player_index, num_ticks_to_step)
    if global.runner_state.playback_state == tas.runner.playback_state.tick_1_prepare_to_attach_runner or
        global.runner_state.playback_state == tas.runner.playback_state.tick_2_attach_runner or
        global.runner_state.playback_state == tas.runner.playback_state.tick_3_running then
        if num_ticks_to_step == nil then
            -- begin running forever
            global.runner_state.num_ticks_to_step = nil
        elseif global.runner_state.num_ticks_to_step == nil then
            global.runner_state.num_ticks_to_step = num_ticks_to_step
        else
            global.runner_state.num_ticks_to_step = global.runner_state.num_ticks_to_step + num_ticks_to_step
        end

        return
    elseif global.runner_state.playback_state ~= tas.runner.playback_state.paused then
        return
    end

    local player_entity = game.players[player_index]
    local original_character = player_entity.character

    tas.runner.ensure_runner_initialized()

    global.runner_state.playback_state = tas.runner.playback_state.tick_1_prepare_to_attach_runner
    global.runner_state.num_ticks_to_step = num_ticks_to_step

    global.runner_state.playback_player_index = player_index
    global.runner_state.playback_player_original_character = original_character
end

function tas.runner.pause()
    if global.runner_state.playback_state ~= tas.runner.playback_state.tick_3_running then
        return
    end

    global.runner_state.playback_state = tas.runner.playback_state.tick_4_prepare_to_attach_player
end