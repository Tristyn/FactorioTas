local BuildOrder = require("BuildOrder")
local Waypoint = require("Waypoint")
local Sequence = require("Sequence")
local SequenceIndexer = require("SequenceIndexer")
local PlaybackController = require("PlaybackController")
local Arrow = require("Arrow")
local Constants = require("Constants")
local Collections = require("collections")
local PlayerControl = require("PlayerControl")

local Tas = { }
local metatable = { __index = Tas }

function Tas.init_globals()
    global.sequence_indexer = SequenceIndexer.new()
    global.playback_controller = PlaybackController.new()
    global.players = { }

    global.sequence_indexer.sequence_collection_changed:add(Tas, "_on_sequence_collection_changed")
    global.sequence_indexer.sequence_changed:add(Tas, "_on_sequence_changed")
end

function Tas.set_metatable()
    SequenceIndexer.set_metatable(global.sequence_indexer)
    PlaybackController.set_metatable(global.playback_controller)
end

function Tas.init_player(player_index)
    global.players[player_index] =
    {
        hover_arrows = { },
        waypoint_build_mode = "insert",
        waypoint = nil -- set through events from Tas.select_waypoint
    }

    Tas.ensure_true_spawn_position_set(game.players[player_index])

    --  select the first waypoint if any exist
    if #global.sequence_indexer.sequences > 0 then
        Tas.select_waypoint(global.sequence_indexer.sequences[1].waypoints[1])
    end
end

-- Creates and returns a static text entity that never despawns.
-- If color is nil, the text will be white
function Tas.create_static_text(surface, position, content, color)
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

function Tas.ensure_true_spawn_position_set(freshly_spawned_player)
    -- The spawn point for nauvis is 0,0 (or closest land to it)
    -- LuaForce::get_spawn_point doesn't help, it always returns 0,0 even if it is over water
    -- LuaSurface::find_non_colliding_position isn't accurate when precision is set to 1.0
    -- The best solution I found is to store the exact position of a player when they spawn for the first time.
    -- Note the stored position becomes innacurate if the player landfills over a watery spawn.

    fail_if_invalid(freshly_spawned_player)

    if global.true_spawn_position == nil then
        global.true_spawn_position = freshly_spawned_player.position
    end
end

-- [Comment]
-- Notifies the user and sets cheat mode to true if it is currently false.
-- `player` can be a LuaPlayer, LuaCharacter or uint.
function Tas.ensure_cheat_mode_enabled(player)
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
        player_entity.print{ "TAS-info-specific", "Editor", "Enabling cheat mode." }
        player_entity.cheat_mode = true
        game.surfaces["nauvis"].always_day = true
    end
end

-- creates a new sequence and returns it's index in the sequence table
function Tas.new_sequence()
    local sequence = global.sequence_indexer:new_sequence()
    global.playback_controller:new_runner(sequence, defines.controllers.character)
end

function Tas.ensure_first_sequence_initialized()
    if #global.sequence_indexer.sequences > 0 then
        return
    end

    log_error({"TAS-info-specific", "Editor", "Placing the initial waypoint at spawn."}, true)
    local sequence = Tas.new_sequence()
end

-- scans a table for a value and returns its index
-- returns nil if it doesn't exist
function Tas.scan_table_for_value(table, selector, value)
    for key, val in pairs(table) do
        if value == selector(val) then
            return key
        end
    end
end

function Tas.select_waypoints_in_sequences()
    return collections.select_many(global.sequence_indexer.sequences, function(sequence) return sequence.waypoints end)
end

function Tas.find_waypoint_from_entity(waypoint_entity)
    return global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)
end

function Tas.find_build_order_from_entity(ghost_entity)
    fail_if_invalid(ghost_entity)

    local orders = global.sequence_indexer:find_orders_from_entity(ghost_entity, BuildOrder)
    
    if #orders > 1 then
        log_error("Entity look up found mulitple related build orders. Picking the newest one.")
    end

    local first_order = nil

    for _, order in pairs(orders) do
        first_order = order
        break
    end

    if first_order == nil then
        return nil
    end

    return {
        sequence = first_order.waypoint.sequence,
        sequence_index = first_order.waypoint.sequence.index,
        waypoint = first_order.waypoint,
        waypoint_index = first_order.waypoint.index,
        build_order = first_order,
        build_order_index = first_order.index
    }
end

function Tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
    local key = Tas.scan_table_for_value(waypoint.mine_orders, function(order) return order:get_entity() end, entity)

    if key == nil then return nil end

    return {
        mine_order_index = key,
        mine_order = waypoint.mine_orders[key]
    }
end

function Tas.find_mine_orders_from_entity(entity)
    local found = { }

    for sequence_index, sequence in ipairs(global.sequence_indexer.sequences) do
        for waypoint_index, waypoint in ipairs(sequence.waypoints) do
            local indexes = Tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
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

function Tas.find_freeroam_control(player_index)
    fail_if_missing(player_index)
    -- if the freeroam character isn't being tracked by the playback
    -- controller than it must either be attached to the player or the player
    -- is in god mode.

    local control = global.playback_controller:try_get_pause_control(player_index)
    
    if control == nil then
        control = PlayerControl.from_player(game.players[player_index])
    end

    return control
end

function Tas.is_waypoint_selected(player_index)
    return global.players[player_index].waypoint ~= nil
end

-- Makes the player select a new waypoint
function Tas.select_waypoint(player_index, waypoint)
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

        global.gui:show_waypoint_editor(player_index, waypoint)
    end
end

function Tas.insert_waypoint(waypoint_entity, player_index)

    local player = global.players[player_index]
    if player.waypoint ~= null then
        local sequence = player.waypoint.sequence
        local waypoint_insert_index = player.waypoint.index + 1
        local waypoint = sequence:insert_waypoint_from_entity(waypoint_insert_index, waypoint_entity)
        Tas.select_waypoint(player_index, waypoint)
    end
    
end

function Tas.on_built_waypoint(created_entity, player_index)
    Tas.ensure_first_sequence_initialized()

    local player = global.players[player_index]

    local selected_waypoint = player.waypoint

    if player.waypoint == null then
        error()
    end

    if player.waypoint_build_mode == "move" then
        selected_waypoint:move_to_entity(created_entity)
    else
        Tas.insert_waypoint(created_entity, player_index)
    end
    
end

function Tas.set_waypoint_build_mode(player_index, mode)
    if mode ~= "move" and mode ~= "insert" then
        error()
    end
    global.players[player_index].waypoint_build_mode = mode
end

function Tas.destroy_mine_order(mine_order)

    if mine_order.waypoint == nil then
        error("Orphan mine order")
    end
    
    mine_order.waypoint:remove_mine_order(mine_order.index)

    return true
end

function Tas.on_built_ghost(created_ghost, player_index)
    if Tas.is_waypoint_selected(player_index) == false then
        return
    end

    local player = global.players[player_index]

    if global.playback_controller:is_player_controlled(player_index) then
        return
    end

    player.waypoint:add_build_order_from_ghost_entity(created_ghost)
end

function Tas.on_built_entity(event)
    local created_entity = event.created_entity
    local player_index = event.player_index

    if created_entity.name == "tas-waypoint" then
        Tas.on_built_waypoint(created_entity, player_index)
    elseif created_entity.name == "entity-ghost" then
        Tas.on_built_ghost(created_entity, player_index)
    end
end

function Tas.add_mine_order(player_index, entity)
    if Tas.is_waypoint_selected(player_index) == false then
        return
    end

    local player = global.players[player_index]

    local find_result = Tas.find_mine_order_from_entity_and_waypoint(entity, player.waypoint)

    if find_result ~= nil then
        local mine_order = find_result.mine_order
        if mine_order.can_set_count() == true then
            mine_order.set_count(mine_order.get_count() + 1)
        end
    else
        player.waypoint:add_mine_order_from_entity(entity)

        Tas.update_players_hover()
    end

    return true
end

function Tas.on_pre_mined_resource(player_index, resource_entity)

    if global.playback_controller:is_player_controlled(player_index) then
        return
    end

    if Tas.add_mine_order(player_index, resource_entity) == true then
        -- undo the mine operation
        resource_entity.amount = resource_entity.amount + 1
    end        

    global.gui:refresh(player_index)
end

function Tas.remove_waypoint(waypoint)

    if waypoint == nil then
        log_error{ "TAS-err-specific", "Editor", "Could not locate data for waypoint entity. This should never happen. Stacktrace: " .. debug.traceback() }
        return false
    end

    if waypoint.sequence:can_remove_waypoint(waypoint.index) == false then
        log_error({ "TAS-info-specific", "Editor", "Can't remove the only waypoint in the sequence." }, true)
        return false
    end

    waypoint.sequence:remove_waypoint(waypoint.index)
end

function Tas.on_pre_removing_waypoint(waypoint_entity)
    local waypoint = global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)

    if Tas.remove_waypoint(waypoint) == false then
        -- Removing failed but the factorio engine will still destroy the waypoint entity.
        -- Create a second waypoint at the exact same position to effectively counteract this.
        Waypoint.spawn_entity(game.surfaces[waypoint.surface_name], waypoint.position)
    end
end

function Tas.on_pre_removing_ghost(ghost_entity)
    local find_result = Tas.find_build_order_from_entity(ghost_entity)

    if find_result == nil then return end
    find_result.waypoint:remove_build_order(find_result.build_order.index)
end

function Tas.on_pre_mined_entity(event)
    local robot = event.robot
    local entity = event.entity

    if entity.name == "tas-waypoint" then
        Tas.on_pre_removing_waypoint(entity)
    elseif entity.name == "entity-ghost" then
        -- Note: factorio doesn't fire this event if a player builds on top of a ghost
        Tas.on_pre_removing_ghost(entity)
    elseif entity.type == "resource" then
        if global.playback_controller:is_player_controlled(player_index) then
            Tas.on_pre_mined_resource(event.player_index, entity)
        end
    end

end

function Tas.add_item_transfer_order(player_index, is_player_receiving, player_inventory_index, container_entity, container_inventory_index, items_to_transfer)
    if Tas.is_waypoint_selected(player_index) == false then
        return false
    end
    
    local waypoint = global.players[player_index].waypoint
    waypoint:add_item_transfer_order(is_player_receiving, player_inventory_index, container_entity, container_inventory_index, items_to_transfer)
end

function Tas.destroy_item_transfer_order(item_transfer_order)
    item_transfer_order.waypoint:remove_item_transfer_order(item_transfer_order.index)

    return true
end

function Tas.on_crafted_item(event)
    local item_stack = event.item_stack
    local player_index = event.player_index
    local player_entity = game.players[player_index]

    if global.playback_controller:is_player_controlled(player_index) then
        return
    end

    if Tas.is_waypoint_selected(player_index) == false then
        return
    end

    -- Determine the crafting recipe and store it as a CraftOrder in the
    -- waypoint. This event is for each item crafted as well as what was
    -- clicked ("iron-axe" triggers both "iron-stick" with a count of
    -- 2 and "iron-axe" with a count of 1, assuming no "iron-sticks"
    -- are in the player's inventory) The trick to determine the 
    -- top-level recipe is to set player.cheat_mode=true so that
    -- on_crafted_item fires exactly once when clicking the button to craft.

    -- Only works in factorio 0.15+ -- recipe = event.recipe
    local recipe = game.players[player_index].force.recipes[item_stack.name]

    if player_entity.cheat_mode == false then
        error("Can not determine crafted item because cheat-mode is not enabled for " .. player_entity.name .. ".")
    end

    if #recipe.products ~= 1 then
        error("No support for crafting recipes with zero or multiple products.")
    end

    if Tas.is_waypoint_selected(player_index) == false then
        error("Could not create a craft order because no waypoint was selected.")
    end

    local player = global.players[player_index]
    
    util.remove_item_stack(player_entity.character, item_stack, Constants.character_inventories, player_entity)
    player.waypoint:add_craft_order(recipe.name, item_stack.count / recipe.products[1].amount)
    global.gui:refresh(player_index)

end

function Tas.on_clicked_waypoint(player_index, waypoint_entity)
    local waypoint = global.sequence_indexer:find_waypoint_from_entity(waypoint_entity)
    
    fail_if_missing(waypoint, "Orphan Waypoint")

    Tas.select_waypoint(player_index, waypoint)
end

function Tas.on_clicked_ghost(player_index, ghost_entity)
    if Tas.is_waypoint_selected(player_index) == false then
        local build_order_indexes = Tas.find_build_order_from_entity(ghost_entity)
        if build_order_indexes == nil then 
            log_error({"TAS-warn-specific", "Editor", "no build order for this ghost"}, true)
            return 
        end
        Tas.select_waypoint(player_index, build_order_indexes.waypoint)
    end
    Tas.show_entity_editor(player_index, ghost_entity)
end

function Tas.on_clicked_generic_entity(player_index, entity)
    Tas.show_entity_editor(player_index, entity)
end

function Tas.show_entity_editor(player_index, entity)
    if Tas.is_waypoint_selected(player_index)  == false then
        return
    end

    local sequence = global.players[player_index].waypoint.sequence
    local character = global.playback_controller:try_get_character(sequence)
    global.gui:show_entity_editor(player_index, entity, character)
end

function Tas.on_left_click(event)
    local player_index = event.player_index
    local player = game.players[player_index]
    
    if player.selected == nil then return end

    local entity = player.selected
    local entity_name = entity.name

    if entity_name == "tas-waypoint" then
        Tas.on_clicked_waypoint(player_index, entity)
    elseif entity_name == "entity-ghost" then
        Tas.on_clicked_ghost(player_index, entity)
    else
        Tas.on_clicked_generic_entity(player_index, entity)
    end
end

function Tas.update_player_hover(player, player_entity)

    -- delete arrow collection
    for _, arrow in pairs(player.hover_arrows) do
        arrow:destroy()
    end
    player.hover_arrows = { }

    -- can be null
    local selected = player_entity.selected

    player.hover_entity = selected

    if selected == nil then
        return
    end
    

    -- check if it's a build order
    local find_result = Tas.find_build_order_from_entity(selected)
    if find_result ~= nil then
        local build_order_entity = find_result.build_order:get_entity()
        local waypoint_entity = find_result.waypoint:get_entity()
        if is_valid(build_order_entity) and is_valid(waypoint_entity) then
            local arrow = Arrow.new(waypoint_entity, build_order_entity)
            player.hover_arrows[arrow] = arrow
        end
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
                local arrow = Arrow.new(selected, prev_waypoint_entity)
                player.hover_arrows[arrow] = arrow
            end
        end

        local next_ = waypoint.sequence.waypoints[waypoint.index + 1]
        if next_ ~= nil then
            local next_waypoint_entity = next_:get_entity()
            if is_valid(next_waypoint_entity) then
                local arrow = Arrow.new(selected, next_waypoint_entity)
                player.hover_arrows[arrow] = arrow
            end
        end

        -- create arrows to all mine orders
        for _, mine_order in ipairs(waypoint.mine_orders) do
            local mine_order_entity = mine_order:get_entity()
            if is_valid(mine_order_entity) then
                local arrow = Arrow.new(selected, mine_order_entity)
                player.hover_arrows[arrow] = arrow
            end
        end

    else -- generic entity, check if it is referenced by any mine orders

        local orders = Tas.find_mine_orders_from_entity(selected)
        if #orders > 0 then
            for _, indexes in ipairs(orders) do
                local mine_order_entity = indexes.mine_order:get_entity()
                local waypoint_entity = indexes.waypoint:get_entity()
                if is_valid(mine_order_entity) and is_valid(waypoint_entity) then
                    local arrow = Arrow.new(waypoint_entity, mine_order_entity)
                    player.hover_arrows[arrow] = arrow
                end
            end
        end
    end
end

function Tas.update_players_hover()
    for player_index, player_entity in pairs(game.connected_players) do
        local player = global.players[player_index]
        Tas.update_player_hover(player, player_entity)
    end
end

function Tas.is_player_hover_target_changed(player, player_entity)
    return player.hover_entity ~= player_entity.selected
end

function Tas.check_player_hovering_entities(player_index)
    local player_entity = game.players[player_index]
    local player = global.players[player_index]

    if Tas.is_player_hover_target_changed(player, player_entity) then
        Tas.update_player_hover(player, player_entity)
    end
end

function Tas.check_players_hovering_entities()
    for player_index, player in pairs(game.connected_players) do
        Tas.check_player_hovering_entities(player_index)
    end
end

function Tas.update_hover_arrows()

    for _, player in pairs(global.players) do
        local arrows_to_remove = { }

        for _, arrow in pairs(player.hover_arrows) do
            local is_valid = arrow:update()
            if is_valid == false then
                table.insert(arrows_to_remove, arrow)
            end
        end
        
        for _, arrow in ipairs(arrows_to_remove) do
            arrow:destroy()
            player.hover_arrows[arrow] = nil
        end
    end

end

function Tas._on_sequence_collection_changed(self, event)
    if event.type == "add_sequence" then
        Tas.select_waypoint(event.sequence.waypoints[1])
    elseif event.type == "remove_sequence" then
        for index, player in pairs(global.players) do
            if player.waypoint.sequence == event.sequence then
                local waypoint_to_select = nil

                for _, sequence in pair(global.sequence_indexer.sequences) do
                    waypoint_to_select = sequence.waypoints[1]
                end

                Tas.select_waypoint(index, waypoint_to_select)
            end
        end
    end
end

function Tas._on_sequence_changed(self, event)
    
    if event.type == "add_waypoint" then
        for index, player in pairs(global.players) do
            if player.waypoint == nil then
                Tas.select_waypoint(index, event.waypoint)
            end
        end
    elseif event.type == "remove_waypoint" then
        for index, player in pairs(global.players) do
            if player.waypoint == event.waypoint then
                -- select a new waypoint
                local waypoints = event.sender.waypoints
                local selected_waypoint = waypoints[math.min(event.waypoint.index, #waypoints)]
                Tas.select_waypoint(index, selected_waypoint)
            end
        end
    end
end

function Tas.on_tick(event)
    Tas.check_players_hovering_entities()

    Tas.update_hover_arrows()

    global.playback_controller:on_tick()
end

return Tas