constants = {
    -- Some of these constants can be read/written during data initialization phase.
    -- There is no way to know their value during game execution phase so they are stored here.

    base_walking_speed = 0.14844,
    base_build_distance = 6,
    -- from data.raw.player.player.build_distance
    character_inventories = { defines.inventory.player_main, defines.inventory.player_quickbar },
    indev_screen_resolution = { x = 1362, y = 701 }
}

util = { }
math.point = { }
math.rectangle = { }

-- Restricts a number to be within a specified range.
function math.clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

-- Calculate Euclidean distance in 2d.
function math.pyth(point_a, point_b)
    local distance_x = point_a.x - point_b.x
    local distance_y = point_a.y - point_b.y

    return math.sqrt(distance_x * distance_x + distance_y * distance_y)
end

-- Computes the distance between a point and a rectangle.
-- If the point is inside the rectangle, the distance returned is 0.
-- Argument point is defines as { x = 3, y = 8 }
-- Argument rectangle is defined as {left_top = { x = -2, y = -3}, right_bottom = {x = 5, y = 8}}. See http://lua-api.factorio.com/latest/Concepts.html#BoundingBox
function math.distance_rectangle_to_point(rectangle, point)
    -- Get a position within the bounds of rectangle that is the nearest to point
    -- When point is inside of rectangle, then rect_position will equal point
    local rect_position =
    {
        x = math.clamp(point.x,rectangle.left_top.x,rectangle.right_bottom.x),
        y = math.clamp(point.y,rectangle.left_top.y,rectangle.right_bottom.y)
    }

    return math.pyth(point, rect_position)
end

-- Adds two points together
function math.point.add(point_a, point_b)
    return
    {
        x = point_a.x + point_b.x,
        y = point_a.y + point_b.y
    }
end

function math.rectangle.translate(rectangle, point_offset)
    return
    {
        left_top = math.point.add(rectangle.left_top, point_offset),
        right_bottom = math.point.add(rectangle.right_bottom, point_offset)
    }
end

-- Calculates the players walking speed.
function util.get_walking_speed(character)
    -- the commented code is used to calculate walking speed bonus from armor modules, which doesn't work ATM.

    local running_speed_modifier = 1 + character.character_running_speed_modifier

    --[[
    local armor_slots = character.get_inventory(defines.inventory.player_armor)
    -- armor_slots is an inventory of length 1

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
    --]]

    return running_speed_modifier * constants.base_walking_speed
end

function util.get_build_distance(character)
    return constants.base_build_distance + character.character_build_distance_bonus
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

function util.integer_to_string(int)
    return string.format("%.0f", int)
end

-- Converts an in-game position to screen coordinates. Useful for setting the LuaPlayer.cursor_position field.
-- Note that the game resolution must be known beforehand.
function util.surface_to_screen_position(surface_position, player_position, player_zoom, screen_size)
    -- at zoom level 1, a tile is 32 pixels wide. at zoom 2 it is 64 pixels.
    -- Zooming in increases the pixel width.
    local tile_size = 32 * player_zoom
    local player_screen_coords = { x = screen_size.x / 2, y = screen_size.y / 2 }

    return
    {
        x = (surface_position.x - player_position.x) * tile_size + player_screen_coords.x,
        y = (surface_position.y - player_position.y) * tile_size + player_screen_coords.y
    }
end

-- Gets the first LuaItemStack in the inventories of a given entity with the given name
-- Parameter inventories is a collection of defines.inventory, see http://lua-api.factorio.com/latest/defines.html#defines.inventory.
-- Returns the LuaItemStack and the inventory it resides in.
function util.find_item_stack(entity, inventories, name)
    for _, inventory_id in pairs(inventories) do
        local inventory = entity.get_inventory(inventory_id)

        if inventory ~= nil then

            local item = inventory.find_item_stack(name)

            if item ~= nil then
                return item, inventory
            end

        end
    end
end

-- Inserts the item into the first empty slot of the the inventories. Does not reduce the 'count' property of the item_stack parameter.
-- Parameter inventories is a collection of defines.inventory, see http://lua-api.factorio.com/latest/defines.html#defines.inventory.
-- Parameter items is SimpleItemStack.
-- Returns the count of items actually inserted.
-- It is important to note that inventories like the player quickbar will only accept at most one stack of each item.
-- Providing the quickbar first and the main inventory second will reduce allow excess stacks to overflow into main inventory.
function util.insert_into_inventories(entity, inventories, items)
    local inserted_tally = 0
    local items_clone = { name = items.name, count = items.count, health = items.health }

    for _, inventory_id in pairs(inventories) do
        local inventory = entity.get_inventory(inventory_id)

        if inventory ~= nil then
            local num_inserted = inventory.insert(items_clone)

            inserted_tally = inserted_tally + num_inserted
            items_clone.count = items_clone.count - num_inserted

            if items_clone.count == 0 then
                break
            end
        end
    end

    return inserted_tally
end