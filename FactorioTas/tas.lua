tas = {}

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

    global.players[player_index] = {}
    global.players[player_index].sequence = {}
    global.players[player_index].is_adding_waypoint = false

    tas.gui.init_player(player_index)
end

function tas.is_adding_waypoint(player_index)
    return global.players[player_index].is_adding_waypoint
end

function tas.set_adding_waypoint(bool)
    global.players[player_index].is_adding_waypoint = bool
end
