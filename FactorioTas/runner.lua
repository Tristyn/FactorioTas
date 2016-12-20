tas.runner = { }

function tas.runner.init_globals()
    global.runner = {}
    global.runner.runners = {}
end

-- Create a new runner and character entity
-- Returns nil if sequence is empty
function tas.runner.new_runner(sequence)
    local start = sequence.waypoints[1]

    if start == nil then
        return nil
    end

    local runner = {
        sequence = sequence,
        waypoint_index = 1,
        character = start.surface.create_entity { name = "player", position = start.position },
    }

    table.insert(global.runner.runners, runner)

    return runner
end

-- Removes (and murders) the runner from the list of active runners.
-- Returns if the runner was found in the list.
function tas.runner.remove_runner(runner)
    
    -- murder it
    if runner.character.valid then
        if runner.character.destroy() == false then
            game.print("couldn't destroy player :( pls fix")
        end
    end

    local index = tas.scan_table_for_value(global.runner.runners, function(entry) return entry end, runner)
    if index == nil then
        return false
    end
    
    table.remove(global.runner.runners, index)
    return true
end

-- returns if the character has arrived at the waypoint
function tas.runner.move_towards_waypoint(character, waypoint)
    local walking_speed = util.get_walking_speed(character)
    local direction_to_waypoint = util.get_directions(character.position, waypoint.position, walking_speed)
    local is_at_waypoint = direction_to_waypoint == nil
    character.walking_state = { walking = not is_at_waypoint, direction = direction_to_waypoint }
    return is_at_waypoint
end

function tas.runner.step_runner(runner)
    local waypoint = runner.sequence.waypoints[runner.waypoint_index]
    local character = runner.character

    -- check completion
    if waypoint == nil then
        return
    end

    -- check construction

    -- check waypoint goal
    runner.reached_waypoint = tas.runner.move_towards_waypoint(character, waypoint)

    -- check if waypoint goals are satisfied
    if runner.reached_waypoint == true then
        runner.waypoint_index = runner.waypoint_index + 1
        runner.reached_waypoint = false
    end
end

function tas.runner.step_runners()
    for i, runner in pairs(global.runner.runners) do
        tas.runner.step_runner(runner)
    end
end
