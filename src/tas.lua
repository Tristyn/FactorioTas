local BuildOrder = require("BuildOrder")
local Waypoint = require("Waypoint")
local Sequence = require("Sequence")
local SequenceIndexer = require("SequenceIndexer")
local PlaybackController = require("PlaybackController")

local tas = { }

function tas.init_globals()
    global.sequence_indexer = SequenceIndexer.new()
    global.playback_controller = PlaybackController.new()
    global.players = { }
    global.arrow_auto_update_repository = { }

    global.sequence_indexer.sequence_changed:add(tas, "_on_sequence_changed")
end

function tas.set_metatable()
    SequenceIndexer.set_metatable(global.sequence_indexer)
    PlaybackController.set_metatable(global.playback_controller)
end

function tas.init_player(player_index)
    global.players[player_index] =
    {
        hover_arrows = { }
    }

    tas.ensure_true_spawn_position_set(game.players[player_index])

    --  select the first waypoint if any exist
    if #global.sequence_indexer.sequences > 0 then
        tas.select_waypoint(global.sequence_indexer.sequences[1].waypoints[1])
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

function tas.ensure_true_spawn_position_set(freshly_spawned_player)
    -- The spawn point for nauvis is 0,0 (or closest land to it)
    -- LuaForce::get_spawn_point doesn't help, it always returns 0,0 even if it is over water
    -- LuaSurface::find_non_colliding_position isn't accurate when precision is set to 1.0
    -- The best solution I found is to store the exact position of a player when they spawn for the first time.
    -- Note the stored position becomes innacurate if the player landfills over a watery spawn.

    if global.true_spawn_position == nil then
        global.true_spawn_position = freshly_spawned_player.position
    end
end

-- [Comment]
-- Notifies the user and sets cheat mode to true if it is currently false.
-- `player` can be a LuaPlayer, LuaCharacter or uint.
function tas.ensure_cheat_mode_enabled(player)
    fail_if_missing(player)

    local player_entity = nil
    
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

-- creates a new sequence and returns it's index in the sequence table
function tas.new_sequence()
    return global.sequence_indexer:new_sequence()
end

function tas.ensure_first_sequence_initialized()
    if #global.sequence_indexer.sequences > 0 then
        return
    end

    game.print("[TAS] Editor: Placing the initial waypoint at spawn.")
    local sequence = tas.new_sequence()
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
    return collections.select_many(global.sequence_indexer.sequences, function(sequence) return sequence.waypoints end)
end

function tas.find_waypoint_from_entity(waypoint_entity)
    return global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)
end

function tas.find_build_order_from_entity(ghost_entity)
    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local build_order_index = tas.scan_table_for_value(waypoint.build_orders, function(build_order) return build_order:get_entity() end, ghost_entity)
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
    local key = tas.scan_table_for_value(waypoint.mine_orders, function(order) return order:get_entity() end, entity)

    if key == nil then return nil end

    return {
        mine_order_index = key,
        mine_order = waypoint.mine_orders[key]
    }
end

function tas.find_mine_orders_from_entity(entity)
    local found = { }

    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
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
    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
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
    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
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
    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
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

function tas.is_waypoint_selected(player_index)
    return global.players[player_index].waypoint ~= nil
end

-- Makes the player select a new waypoint
function tas.select_waypoint(player_index, waypoint)
    fail_if_missing(player_index)
    fail_if_missing(waypoint)

    local player = global.players[player_index]

    -- Remove the old highlight
    if player.waypoint ~= nil then
        player.waypoint:set_highlight(false)
    end

    player.waypoint = waypoint

    if waypoint == nil then
        global.gui:hide_waypoint_editor(player_index)
    else
        -- Create the 'highlight' entity
        waypoint:set_highlight(true)

        global.gui:show_waypoint_editor(player_index, waypoint.sequence.index, waypoint.index)
    end
end

function tas.insert_waypoint(waypoint_entity, player_index)

    local player = global.players[player_index]
    if player.waypoint ~= null then
        local sequence = player.waypoint.sequence
        local waypoint_insert_index = player.waypoint.index + 1
        local waypoint = sequence:insert_waypoint_from_entity(waypoint_insert_index, waypoint_entity)
        tas.select_waypoint(player_index, waypoint)
    end
    
end

function tas.on_built_waypoint(created_entity, player_index)
    tas.ensure_first_sequence_initialized()

    local player = global.players[player_index]

    local selected_waypoint = player.waypoint

    if player.waypoint == null then
        error()
    end

    if player.gui.current_state == "move" then
        selected_waypoint:move_to_entity(created_entity)
    else
        tas.insert_waypoint(created_entity, player_index)
    end
    
end

function tas.destroy_mine_order(mine_order)
    local indexes = tas.get_mine_order_indexes(mine_order)

    if indexes == nil then return false end

    if mine_order.waypoint == nil then
        error("Orphan mine order")
    end
    
    mine_order.waypoint:remove_mine_order(mine_order.index)

    return true
end

function tas.on_built_ghost(created_ghost, player_index)
    if tas.is_waypoint_selected(player_index) == false then
        return
    end

    local player = global.players[player_index]

    if global.playback_controller:get_current_playback_player() == player then
        return
    end

    player.waypoint:add_build_order_from_ghost_entity(created_ghost)
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
    if tas.is_waypoint_selected(player_index) == false then
        return
    end

    local player = global.players[player_index]

    local find_result = tas.find_mine_order_from_entity_and_waypoint(entity, player.waypoint)

    if find_result ~= nil then
        local mine_order = find_result.mine_order
        if mine_order.can_set_count() == true then
            mine_order.set_count(mine_order.get_count() + 1)
        end
    else
        player.waypoint:add_mine_order_from_entity(entity)

        tas.update_players_hover()
    end

    return true
end

function tas.on_pre_mined_resource(player_index, resource_entity)
    local player = game.players[player_index]

    if global.playback_controller:get_current_playback_player() == game.players[player_index] then
        return
    end

    if tas.add_mine_order(player_index, resource_entity) == true then
        -- undo the mine operation
        resource_entity.amount = resource_entity.amount + 1
    end        

    global.gui:refresh(player_index)
end

function tas.remove_waypoint(waypoint_entity)
    local waypoint = global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)

    if waypoint == nil then
        game.print( { "TAS-err-generic", "Could not locate data for waypoint entity. This should never happen. Stacktrace: " .. debug.traceback() })
        return false
    end

    if waypoint.sequence:can_remove_waypoint(waypoint.index) == false then
        game.print( { "TAS-err-generic", "Can't remove the only waypoint in the sequence." } )
        return false
    end

    waypoint.sequence:remove_waypoint(waypoint.index)
end

function tas.on_pre_removing_waypoint(waypoint_entity)
    if tas.remove_waypoint(waypoint_entity) == false then
        -- Removing failed but the factorio engine will still destroy the waypoint entity.
        -- Create a second waypoint at the exact same position to effectively counteract this.
        Waypoint.spawn_entity(game.surfaces[waypoint_entity.surface.name], waypoint_entity.position)
    end
end

function tas.on_pre_removing_ghost(ghost_entity)
    local find_result = tas.find_build_order_from_entity(ghost_entity)

    if find_result == nil then return end
    find_result.waypoint:remove_build_order(find_result.build_order.index)
end

function tas.on_pre_mined_entity(event)
    local player = game.players[event.player_index]
    local robot = event.robot
    local entity = event.entity

    if entity.name == "tas-waypoint" then
        tas.on_pre_removing_waypoint(entity)
    elseif entity.name == "entity-ghost" then
        -- Note: factorio doesn't fire this event if a player builds on top of a ghost
        tas.on_pre_removing_ghost(entity)
    elseif entity.type == "resource" then
        if global.playback_controller:get_current_playback_player() ~= player then
            tas.on_pre_mined_resource(event.player_index, entity)
        end
    end

end

function tas.add_item_transfer_order(player_index, is_player_receiving, player_inventory_index, container_entity, container_inventory_index, items_to_transfer)
    if tas.is_waypoint_selected(player_index) == false then
        return false
    end
    
    local waypoint = global.players[player_index].waypoint
    waypoint:add_item_transfer_order(is_player_receiving, player_inventory_index, container_entity, container_inventory_index, items_to_transfer)
end

function tas.destroy_item_transfer_order(item_transfer_order)
    item_transfer_order.waypoint:remove_item_transfer_order(item_transfer_order.index)

    return true
end

function tas.on_crafted_item(event)
    local item_stack = event.item_stack
    local player_index = event.player_index
    local player_entity = game.players[player_index]

    if global.playback_controller:get_current_playback_player() == player_entity then
        return
    end

    if tas.is_waypoint_selected(player_index) == false then
        return
    end

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

    if tas.is_waypoint_selected(player_index) == false then
        error("Could not create a craft order because no waypoint was selected.")
    end

    local player = global.players[player_index]
    
    util.remove_item_stack(player_entity.character, item_stack, constants.character_inventories, player_entity)
    player.waypoint:add_craft_order(recipe.name, item_stack.count / recipe.products[1].amount)
    global.gui:refresh(player_index)

end

function tas.on_clicked_waypoint(player_index, waypoint_entity)
    local waypoint = global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)
    
    fail_if_missing(waypoint, "Orphan Waypoint")

    tas.select_waypoint(player_index, waypoint)
end

function tas.on_clicked_ghost(player_index, ghost_entity)
    if tas.is_waypoint_selected(player_index) == false then
        local build_order_indexes = tas.find_build_order_from_entity(ghost_entity)
        if build_order_indexes == nil then 
            game.print("no build order for this ghost") 
            return 
        end
        tas.select_waypoint(player_index, build_order_indexes.waypoint)
    end
    tas.show_entity_editor(player_index, ghost_entity)
end

function tas.on_clicked_generic_entity(player_index, entity)
    tas.show_entity_editor(player_index, entity)
end

function tas.show_entity_editor(player_index, entity)
    if tas.is_waypoint_selected(player_index)  == false then
        return
    end

    local sequence = global.players[player_index].waypoint.sequence
    local character = global.playback_controller:try_get_character(sequence)
    global.gui:show_entity_editor(player_index, entity, character)
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
        tas.on_clicked_generic_entity(player_index, entity)
    end
end

function tas.update_player_hover(player, player_entity)
    -- delete arrow collection
    for _, arrow in ipairs(player.hover_arrows) do
        tas.destroy_arrow(arrow)
    end

    player.hover_arrows = { }

    -- can be null
    local selected = player_entity.selected

    player.hover_entity = selected

    if selected == nil then
        return
    end

    -- check if it's a build order
    local find_result = tas.find_build_order_from_entity(selected)
    if find_result ~= nil then
        local build_order_entity = find_result.build_order:get_entity()
        local waypoint_entity = find_result.waypoint:get_entity()
        if is_valid(build_order_entity) and is_valid(waypoint_entity) then
            local arrow = tas.create_arrow(build_order_entity, waypoint_entity)
            tas.insert_arrow_into_auto_update_respository(arrow)
            table.insert(player.hover_arrows, arrow)
        end
        return
    elseif selected.name == "tas-waypoint" then

        local waypoint = global.sequence_indexer:find_waypoint_from_entity(selected)
        if waypoint == nil then
            error("Orphan waypoint")
        end

        -- create arrows to waypoints adjacent to this one
        local prev = waypoint.sequence.waypoints[waypoint.index - 1]
        if prev ~= nil then
            local prev_waypoint_entity = prev:get_entity() 
            if is_valid(prev_waypoint_entity) then
                local arrow = tas.create_arrow(prev_waypoint_entity, selected)
                tas.insert_arrow_into_auto_update_respository(arrow)
                table.insert(player.hover_arrows, arrow)
            end
        end

        local next_ = waypoint.sequence.waypoints[waypoint.index + 1]
        if next_ ~= nil then
            local next_waypoint_entity = next_:get_entity()
            if is_valid(next_waypoint_entity) then
                local arrow = tas.create_arrow(selected, next_waypoint_entity)
                tas.insert_arrow_into_auto_update_respository(arrow)
                table.insert(player.hover_arrows, arrow)
            end
        end

        -- create arrows to all mine orders
        for _, mine_order in ipairs(waypoint.mine_orders) do
            local mine_order_entity = mine_order:get_entity()
            if is_valid(mine_order_entity) then
                local arrow = tas.create_arrow(selected, mine_order_entity)
                tas.insert_arrow_into_auto_update_respository(arrow)
                table.insert(player.hover_arrows, arrow)
            end
        end

    else -- generic entity, check if it is referenced by any mine orders

        local orders = tas.find_mine_orders_from_entity(selected)
        if #orders > 0 then
            for _, indexes in ipairs(orders) do
                local mine_order_entity = indexes.mine_order:get_entity()
                local waypoint_entity = indexes.waypoint:get_entity()
                if is_valid(mine_order_entity) and is_valid(waypoint_entity) then
                    local arrow = tas.create_arrow(mine_order_entity, waypoint_entity)
                    tas.insert_arrow_into_auto_update_respository(arrow)
                    table.insert(player.hover_arrows, arrow)
                end
            end
        end
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

function tas._on_sequence_changed(event)
    
    if event.type == "add_waypoint" then
        for index, player in pairs(global.players) do
            if player.waypoint == nil then
                game.print("Highlight")
                tas.select_waypoint(index, event.waypoint)
            end
        end
    elseif event.type == "remove_waypoint" then
        for index, player in pairs(global.players) do
            if player.waypoint == event.waypoint then
                -- select a new waypoint
                local waypoints = event.sender.waypoints
                local selected_waypoint = waypoints[math.min(event.waypoint.index, #waypoints)]
                tas.select_waypoint(index, selected_waypoint)
            end
        end
    end
end

function tas.on_tick(event)
    tas.check_players_hovering_entities()

    tas.update_arrow_repository()

    global.playback_controller:on_tick()
end

return tas