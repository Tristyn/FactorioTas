local position = require("position")
local bounding_box = require("bounding_box")
local mathex = require("mathex")

-- TODO: this would be better as a local
constants = {
    -- Some of these constants can be read/written during data initialization phase.
    -- There is no way to know their value during game execution phase so they are stored here.

    base_walking_speed = 0.14844,
    base_build_distance = 6,
    -- from data.raw.player.player.build_distance; the field is not avaiable during gameplay so it is hardcoded here)
    character_inventories =
    {
        defines.inventory.player_main,
        defines.inventory.player_quickbar,
        defines.inventory.player_guns,
        defines.inventory.player_ammo,
        defines.inventory.player_armor,
        defines.inventory.player_tools,
        defines.inventory.player_vehicle
    },
    god_inventories = {
        defines.inventory.god_main,
        defines.inventory.god_quickbar
    }
}

-- TODO: this would be better as a local
util = { }

function util.init_globals()
    global.guid_count = 0
end

function util.get_guid()
    global.guid_count = global.guid_count + 1
    if global.guid_count < 0 then
        game.print( { "TAS-err-generic", "Globally unique ID overflow. Replace GUID with a big int implementation!" })
    end
    return global.guid_count
end

function util.can_reach(player, entity_surface_name, entity_name, entity_position)
    fail_if_invalid(player)
    local controller_type = player.controller_type

    if controller_type == defines.controllers.ghost then
        return false
    elseif controller_type == defines.controllers.god then
        return true
    end

    -- logic for controller_type == defines.controllers.character
    local character = player.character

    if entity_surface_name ~= character.surface.name then
        return false
    end
    
    -- The function character.can_reach_entity() is off limits because
    -- it will always return true for entities such as ghost.
    
    local selection_box_world_space = bounding_box.translate(game.entity_prototypes[entity_name].selection_box, entity_position)
    local distance = bounding_box.distance_to_point(selection_box_world_space, character.position)
    local can_reach = distance < util.get_build_distance(character) - 0.5
    -- Include a 0.5 margin of error because this isn't the exact reach distance formula.
            
    return can_reach
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
    if mathex.float_equals(start.x, destination.x, walking_speed_per_tick) then
        -- north & south
        if mathex.float_equals(start.y, destination.y, walking_speed_per_tick) then
            return nil
        elseif start.y < destination.y then
            return defines.direction.south
        else
            return defines.direction.north
        end
    elseif start.x < destination.x then
        if mathex.float_equals(start.y, destination.y, walking_speed_per_tick) then
            return defines.direction.east
        elseif start.y < destination.y then
            return defines.direction.southeast
        else
            return defines.direction.northeast
        end
    else
        if mathex.float_equals(start.y, destination.y, walking_speed_per_tick) then
            return defines.direction.west
        elseif start.y < destination.y then
            return defines.direction.southwest
        else
            return defines.direction.northwest
        end
    end
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

--[Comment]
-- Gets the count of items in the inventories.
-- Parameter inventories is a collection of defines.inventory
-- Parameter item is the string name of the item prototype. If not specified, count all items.
function util.get_item_count(entity, inventories, item)
    fail_if_invalid(entity)
    fail_if_missing(inventories)

    local count = 0

    for _, inventory_id in pairs(inventories) do
        local inventory = entity.get_inventory(inventory_id)

        if inventory ~= nil then
            count = count + inventory.get_item_count(item)
        end
    end

    return count
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

-- [Comment]
-- Removes a SimpleItemStack `item_stack` from the inventories. May remove multiple stacks and remove from multiple inventories across the entity.
-- Does not support removing durability or ammo count, but can be extended to support those cases.
-- Returns the number of items actually removed.
function util.remove_item_stack(entity, item_stack, inventories, player)
    local num_to_remove = item_stack.count

    for _, inventory_id in pairs(inventories) do
        local inventory = entity.get_inventory(inventory_id)
        
        if inventory ~= nil then
            local num_removed = inventory.remove( { name = item_stack.name, count = num_to_remove })
            num_to_remove = num_to_remove - num_removed
            -- The specified number of items have been removed
            if num_to_remove == 0 then
                return item_stack.count
            end
        end

    end

    if player ~= nil and player.cursor_stack.valid_for_read then
        
        local num_removed = math.min(player.cursor_stack.count, num_to_remove)
        item_stack.count = player.cursor_stack.count - num_removed
        num_to_remove = num_to_remove - num_removed

    end

    if num_to_remove < 0 then
        error("This should never happen")
    end

    -- Not all items were removed, return the number that were actually removed.
    return item_stack.count - num_to_remove
end

function util.move_item_stack(target_stack, source_stack, character, overflow_inventories)
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

--[Comment]
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

function util.get_inventory_owner(inventory)
    -- LuaInventory has fields entity_owner and player_owner. Only one is not nil, and when the owner is a player it depends on how the inventory was acquired.
    -- player_owner is set when player.get_inventory is used, and entity_owner is set when player.character.get_inventory is used
    -- Avoid that nonsense with this method
    -- May return nil if the inventory does not belong to any entity

    local owner = inventory.entity_owner
    if owner ~= nil then return owner end
    return inventory.player_owner
end

--[Comment]
-- Returns the inventories associated with the player. 
function util.get_player_inventories(player)
    fail_if_invalid(player)

    if player.controller_type == defines.controllers.character then
        return constants.character_inventories
    elseif player.controller_type == defines.controllers.god then
        return constants.god_inventories
    else
        return { }
    end
end

util.entity = { }

local entity_type_to_inventories_map = {
    ["player"] =
    {
        { id = defines.inventory.player_main, name = "Backpack" },
        { id = defines.inventory.player_quickbar, name = "Quickbar" },
        { id = defines.inventory.player_guns, name = "Guns" },
        { id = defines.inventory.player_ammo, name = "Ammo" },
        { id = defines.inventory.player_armor, name = "Armor" },
        { id = defines.inventory.player_tools, name = "Tools" },
        { id = defines.inventory.player_trash, name = "Trash" }
    },
    ["container"] = { { id = defines.inventory.chest, name = "Chest" } },
    ["locomotive"] = { { id = defines.inventory.fuel, name = "Train Fuel" } },
    ["cargo-wagon"] = { { id = defines.inventory.cargo_wagon, name = "Cargo Wagon" } },
    ["car"] =
    {
        { id = defines.inventory.fuel, name = "Car Fuel" },
        { id = defines.inventory.car_ammo, name = "Car Ammo" },
        { id = defines.inventory.car_trunk, name = "Car Trunk" }
    },
    ["roboport_robot"] =
    {
        { id = defines.inventory.roboport_robot, name = "Roboport Robots" },
        { id = defines.inventory.roboport_material, name = "Roboport Repair Packs" }
    },
    ["boiler"] = { { id = defines.inventory.fuel, name = "Boiler Fuel" } },
    ["mining-drill"] =
    {
        { id = defines.inventory.fuel, name = "Fuel" },
        { id = defines.inventory.mining_drill_modules, name = "Modules" }
    },
    ["furnace"] =
    {
        { id = defines.inventory.fuel, name = "Furnace Fuel" },
        { id = defines.inventory.furnace_source, name = "Input" },
        { id = defines.inventory.furnace_result, name = "Output" },
        { id = defines.inventory.furnace_modules, name = "Modules" }
    },
    ["assembling-machine"] =
    {
        { id = defines.inventory.assembling_machine_input, name = "Input" },
        { id = defines.inventory.assembling_machine_output, name = "Output" },
        { id = defines.inventory.assembling_machine_modules, name = "Modules" }
    },
    ["lab"] =
    {
        { id = defines.inventory.lab_input, name = "Input" },
        { id = defines.inventory.lab_modules, name = "Modules" },
    },
    ["beacon"] = { ["Modules"] = defines.inventory.beacon_modules },
    ["ammo-turret"] = { ["Turret Ammo"] = defines.inventory.turret_ammo },
    ["rocket-silo"] =
    {
        { id = defines.inventory.rocket_silo_rocket, name = "Silo Rocket" },
        { id = defines.inventory.assembling_machine_input, name = "Input" },
        { id = defines.inventory.rocket_silo_result, name = "Silo Result" },
        { id = defines.inventory.assembling_machine_modules, name = "Modules" }
    },
}

function util.entity.get_inventory_info(entity_type)
    local result = entity_type_to_inventories_map[entity_type]
    if result == nil then return { } end
    return result
end

--[Comment]
-- Returns a string representation of `entity` which can be used as a table index.
-- If fields position and surface are changed then the index is stale state.
function util.entity.get_entity_id(entity)
    fail_if_invalid(entity)
    local name
    if entity.type ~= "entity-ghost" then
        name = entity.name
    else
        name = entity.ghost_name
    end

    return entity.position.x .. '_' .. entity.position.y .. '_' .. entity.surface.name .. '_' .. name
end

-- Attempts to read the property of the object.
-- It's first result returns true when the property was read, along
-- with the value of the property. In the case of an error, it returns false.
function util.entity.try_read_property(entity, property_name)
    return pcall(function() 
        return entity[property_name]
    end)
end

function util.find_entity(surface_name, entity_name, position)
    local surface = game.surfaces[surface_name]
    if surface == nil then return nil end
    -- find_entities_filtered works better than find_entity
    -- because it doesn't require a collision box
    local entities = surface.find_entities_filtered{name = entity_name, area = {{position.x - 0.05, position.y - 0.05}, {position.x + 0.05, position.y + 0.05}}}
    if #entities == 0 then return nil end
    return entities[1]
end


--[Comment]
-- Gets the time required to mine an entity in ticks,
-- as well as the tool durability lost from mining by hand.
function util.get_mining_time_and_durability_loss(miner_entity, minable_entity_name)
    -- reference: https://wiki.factorio.com/Mining#Mining_Speed_Formula
    -- (Mining power - Mining hardness) * Mining speed / Mining time = Production rate/tick
    -- Mining time / ((Mining power - Mining hardness) * Mining speed) = ticks for 1 product

    fail_if_missing(miner_entity)
    fail_if_missing(minable_entity_name)

    local miner_prototype = game.entity_prototypes[miner_entity.name]
    local minable_prototype = game.entity_prototypes[minable_entity_name]

    local mining_power = miner_prototype.mining_power
    local mining_speed = miner_prototype.mining_speed
    local mining_hardness = minable_prototype.mineable_properties.hardness
    local mining_time = minable_prototype.mineable_properties.mining_time
    
    if mining_power == nil then
        -- default mining power is nil when entity type is not `mining_drill` and is `player`
        -- player base mining power is not exposed by the api, so hardcode it
        mining_power = 1
    end

    -- include tool power and character_mining_speed_modifier
    if miner_entity.type == "player" then
        
        mining_speed = mining_speed * (1 + miner_entity.character_mining_speed_modifier)
        
        local miner_tool = miner_entity.get_inventory(defines.inventory.player_tools)[1]
        if miner_tool.valid_for_read == true then
            local tool_power = game.item_prototypes[miner_tool.name].speed
            
            mining_power = mining_power * tool_power
        end
    end

    local time_in_ticks = mining_time / ((mining_power - mining_hardness) * mining_speed)
    local durability_loss = time_in_ticks * mining_hardness

    -- not sure if fractional ticks are rounded down or up. Round up to stay safe and not cheat.
    time_in_ticks = math.ceil(time_in_ticks)
    
    return time_in_ticks, durability_loss
end

function util.get_item_stack_split_count(click_event, item_name)
    fail_if_missing(click_event)
    fail_if_missing(item_name)

    if click_event.button == defines.mouse_button_type.left  then
        if click_event.shift == true then
            return game.item_prototypes[item_name].stack_size
        else
            return 1
        end
    elseif click_event.button == defines.mouse_button_type.right then
        return 5
    else 
        return 1
    end
end

function util.alert(surface_name, pos)
    fail_if_missing(surface_name)
    fail_if_missing(pos)

    local surface = game.surfaces[surface_name]
    if surface == nil then return end

    pos = position.floor(pos)
    local text = surface.create_entity({ name = "flying-text", position = pos, text = "⬇"})
    for _, player in pairs(game.connected_players) do 
        player.add_alert(text, defines.alert_type.not_enough_construction_robots)
    end
end

--[Comment]
-- Spawns a character at the origin.
-- parameter respawn:bool is optional; if true adds items given during respawn, 
-- if false gives items during first spawn. Defaults to false.
function util.spawn_character(respawn)
    local surface = game.surfaces["nauvis"]
    local spawn_point = global.true_spawn_position
    if spawn_point == nil then
        spawn_point = surface.find_non_colliding_position("player", { x=0, y=0}, 0, 1)
    end
    fail_if_missing(spawn_point)

    local character = surface.create_entity { 
        name = "player", 
        position = spawn_point,
        force = "player" 
    }
    
    local quickbar = character.get_inventory(defines.inventory.player_quickbar)
    local main = character.get_inventory(defines.inventory.player_main)
    local guns = character.get_inventory(defines.inventory.player_guns)
    local ammo = character.get_inventory(defines.inventory.player_ammo)

    -- insert items that are given at spawn and respawn
    guns.insert( { name = "pistol", count = 1 })
    ammo.insert( { name = "firearm-magazine", count = 10 })

    if respawn == nil or respawn  == false then
        quickbar.insert( { name = "burner-mining-drill", count = 1 })
        quickbar.insert( { name = "stone-furnace", count = 1 })
        main.insert( { name = "iron-plate", count = 8 })
    end

    return character

end

function util.clone_table(source_table)
    fail_if_missing(source_table)
    
    local target_table = { }

    for source_key, source_value in pairs(source_table) do
        target_table[source_key] = source_value
    end

    return target_table
end

-- Similar to JavaScript Object.assign() 
-- It's used in this codebase as util.assign_table({}, foo)
-- so that it's in functional style, just like as a shallow clone method.
function util.assign_table(target_table, source_table)
    for source_key, source_value in pairs(source_table) do
        target_table[source_key] = source_value
    end

    return target_table
end

return util