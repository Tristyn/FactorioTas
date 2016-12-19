-- Calculate Euclidean distance in 2d.

constants = {
    base_walking_speed = 0.14844,
}

util = { }

function math.pyth(point_a, point_b)
    return Math.Sqrt(Math.Pow(point_b[1] - point_a[1], 2) + Math.Pow(point_b[2] - point_a[2], 2))
end

-- Calculates the players walking speed.
function util.get_walking_speed(character)
    local armor_slots = character.get_inventory(defines.inventory.player_armor)
    -- armor_slots is an inventory of length 1

    local running_speed_modifier = 1 + character.character_running_speed_modifier

    -- enumerate all equipment items in the characters armor
    if armor_slots ~= nil then
        for _, armor in pairs(armor_slots) do
            if armor ~= nil and armor.grid ~= nil then
                for _, equipment in pairs(armor.grid.equipment) do

                    running_speed_modifier = base_running_speed_modifier +
                    -- actual equipment movement bonus calculation
                    (equipment.movement_bonus * equipment.energy / equipment.max_energy)

                end
            end
        end
    end

    return running_speed_modifier * constants.base_walking_speed
end

-- south/down = +y
-- east/right = +x
local direction_map = {
    [defines.direction.north] = { x = - 1, y = 0 },
    [defines.direction.northeast] = { x = - 1, y = 1 },
    [defines.direction.east] = { x = 0, y = 1 },
    [defines.direction.southeast] = { x = 1, y = 1 },
    [defines.direction.south] = { x = 1, y = 0 },
    [defines.direction.southwest] = { x = 1, y = - 1 },
    [defines.direction.west] = { x = 0, y = - 1 },
    [defines.direction.northwest] = { x = - 1, y = - 1 }
}

function util.direction_to_vector(direction)
    return direction_map[direction]
end

-- Returns the direction one should take to reach the destination.
-- Returns nil if the destination has been reached
function util.get_directions(start, destination, walking_speed_per_tick)
    -- could be optimized by using a lookup table

    -- east & west
    if util.equals(start.x, destination.x, walking_speed_per_tick) then
        -- north & south
        if util.equals(start.y, destination.y, walking_speed_per_tick) then
            return nil
        elseif start.y < destination.y then
            return defines.direction.south
        else
            return defines.direction.north
        end
    elseif start.x < destination.x then
        if util.equals(start.y, destination.y, walking_speed_per_tick) then
            return defines.direction.east
        elseif start.y < destination.y then
            return defines.direction.southeast
        else
            return defines.direction.northeast
        end
    else
        if util.equals(start.y, destination.y, walking_speed_per_tick) then
            return defines.direction.west
        elseif start.y < destination.y then
            return defines.direction.southwest
        else
            return defines.direction.northwest
        end
    end
end

function util.equals(double1, double2, precision)
    return math.abs(double1 - double2) <= precision
end
