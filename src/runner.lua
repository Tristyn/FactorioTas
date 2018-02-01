local BuildOrderDispatcher = require("BuildOrderDispatcher")
local ItemTransferOrderDispatcher = require("ItemTransferOrderDispatcher")
local Sequence = require("Sequence")

local Runner = { }
local metatable = { __index = Runner }

function Runner.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

    Sequence.set_metatable(instance.sequence)
    BuildOrderDispatcher.set_metatable(instance.build_order_dispatcher)
    ItemTransferOrderDispatcher.set_metatable(instance.item_transfer_order_dispatcher)
end

-- Create a new runner, returns nil if sequence is empty
function Runner.new(sequence)
	fail_if_missing(sequence)
	
    local sequence_start = sequence.waypoints[1]

    if sequence_start == nil then
        return nil
    end

    local new = {
        sequence = sequence,
        waypoint_index = 1,

        build_order_dispatcher = BuildOrderDispatcher.new(),
        in_progress_build_orders = nil,

        pending_mine_orders = { },
        in_progress_mine_order = nil,
        mine_order_started_tick = 0,

        pending_craft_orders = { },
        pending_craft_orders_num_crafted = { },

        item_transfer_order_dispatcher = ItemTransferOrderDispatcher.new(),
        opened_item_transfer_container = nil
    }
    
    Runner.set_metatable(new)

    new:_process_waypoint_orders(sequence_start)
    
    return new
end

function Runner:_process_waypoint_orders(waypoint)
    fail_if_missing(waypoint)

    for k, order in pairs(waypoint.build_orders) do
        self.build_order_dispatcher:add_order(order)
    end

    for _, mine_order in pairs(waypoint.mine_orders) do
        self.pending_mine_orders[mine_order] = mine_order
    end

    for _, craft_order in pairs(waypoint.craft_orders) do
        self.pending_craft_orders[craft_order] = craft_order
        self.pending_craft_orders_num_crafted[craft_order] = 0
    end
    
    for _, item_transfer_order in pairs(waypoint.item_transfer_orders) do
        self.item_transfer_order_dispatcher:add_order(item_transfer_order)
    end
end

-- returns if the character has arrived at the waypoint
function Runner:_set_walking_state()
    local character = self.player.character
    
    if character == nil then
        return
    end

    local direction_to_waypoint = nil
    local waypoint = self:_get_next_waypoint()

    if waypoint ~= nil then
        direction_to_waypoint = waypoint:get_direction(character)
    end

    character.walking_state = { 
		walking = direction_to_waypoint ~= nil, 
		direction = direction_to_waypoint 
	}
end

function Runner:_step_build_state()
    local dispatcher = self.build_order_dispatcher

    local orders = dispatcher:find_chainable_completable_orders_some_near_player(self.player)
    if orders == nil then
        return
    end
    
    local completed_orders = { }
    local _, first_order = next(orders)

    -- One frame is needed to insert the item_stack into the players hand.
    -- Dragging the mouse allows one item to be placed per frame.
    -- However an infinite amount can be placed by clicking multiple different pixels one frame.
    -- If the item stack depletes in-game it will be automatically replenished mid-frame by the engine. 
    -- So spam away ;)

    if first_order:is_order_item_in_cursor_stack(self.player) == false then
        if first_order:move_order_item_to_cursor_stack(self.player) == true then
            return
        else
            self.in_progress_build_orders = nil
        end
    else
        for i, order in pairs(orders) do
            if order:spawn_entity_through_player(self.player) == true then
                table.insert(completed_orders, order)
            end
        end
    end

    for _, order in pairs(completed_orders) do
        dispatcher:remove_order(order)
    end
end

-- returns true if mining is in progress (and player mouse can't be used for another task)
function Runner:_step_mine_state()
    local character = self.player.character

    if self.in_progress_mine_order == nil then
        -- find the next mine order
        for _, mine_order in pairs(self.pending_mine_orders) do
            -- ensure tool durability remains
            if character ~= nil and mine_order:has_sufficient_tool_durability(character) == false then 
                game.print("Error: TAS does not know how to calculate time spent mining when a mining tool is about to break. Ensure that the character never runs out of mining tools. Cheating and breaking the last tool before mining.")
                character.get_inventory(defines.inventory.player_tools)[1].clear()
            end

            if mine_order:can_mine(character) then
                self.pending_mine_orders[mine_order] = nil
                self.in_progress_mine_order = mine_order
                self.mine_order_started_tick = game.tick

                break
            end
        end
    end

    local mine_order = self.in_progress_mine_order
    if mine_order == nil then
        return false
    end

    -- Add one tick to hover over the entity and allow player::selected to update, then mining begins.
    -- The `channeling` aspect of of mining is so funny. You must hold the key down throughout 
    -- however within a frame the player can let go of the key, then build and mess with their inventory.
    -- As long as the key is pressed again at the end of the frame the channel will continue.

    local ticks_spent_mining = game.tick - self.mine_order_started_tick
    local time_to_mine_once = mine_order:get_mining_time(character) + 1
    
    -- check if resources should be awarded
    if ticks_spent_mining % time_to_mine_once == 0 and self.mine_order_started_tick ~= game.tick then
        local success = mine_order:mine(character)
        if success == false then error() end

        mine_order:remove_durability(character)

        if ticks_spent_mining / time_to_mine_once >= mine_order:get_count() then
            -- mine order complete!
            self.in_progress_mine_order = nil
        else
            -- mine for another round
            
            -- ensure tool durability remains
            if mine_order:has_sufficient_tool_durability(character) == false then 
                game.print("Error: TAS does not know how to calculate time spent mining when a mining tool is about to break. Ensure that the character never runs out of mining tools. Cheating and breaking the last tool before mining.")
                character.get_inventory(defines.inventory.player_tools)[1].clear()
            end
        end
    end

    return true
end

function Runner:_step_craft_state()
    local craft_orders_completed = { }

    -- We do not have to wait one frame to begin hovering over a button, 
    -- and multiple buttons can be pressed multiple times per frame.
    -- AND you can press buttons and finish by hovering over an entity
    -- Therefor crafting doesn't occupy the mouse at all.
    -- So spam that shit ;) 
    -- However crafting has to be done BEFORE mining or building that frame,
    -- and crafting cancels mining.

    for _, craft_order in pairs(self.pending_craft_orders) do
        local num_crafted = self.pending_craft_orders_num_crafted[craft_order]
        local craft_order_total = craft_order:get_count()
        local num_remaining = craft_order_total - num_crafted
        

        for i = 1, num_remaining do
            local num_started = self.player.begin_crafting( { count = 1, recipe = craft_order.recipe_name, silent = false })
            if num_started == 0 then
                break
            end
            
            num_crafted = num_crafted + num_started
            
            -- mutating a list causes the next loop iteration to be undefined.
            -- It is OK to mutate here because we are exiting the loop immediately.
            self.pending_craft_orders_num_crafted[craft_order] = nil
            self.pending_craft_orders[craft_order] = nil
            return true
        end

        self.pending_craft_orders_num_crafted[craft_order] = num_crafted
        
        if num_crafted >= craft_order_total then
            table.insert(craft_orders_completed, craft_order)
        end
    end

    for _, order in ipairs(craft_orders_completed) do 
        self.pending_craft_orders_num_crafted[craft_order] = nil
        self.pending_craft_orders[craft_order] = nil
    end
end

function Runner:_step_item_transfer_state()
    local order_group = self.item_transfer_order_dispatcher:find_orders_for_container(self.player)
    if order_group == nil then
        return
    end

    local _, order = next(order_group)
    local container_entity = order:get_entity()
    if container_entity == nil then error() end

    if self.opened_item_transfer_container ~= container_entity then
        self.opened_item_transfer_container = container_entity
        return
    end

    for _, order in pairs(order_group) do
        if order:can_transfer(self.player) == true then
            order:transfer(self.player)
            self.item_transfer_order_dispatcher:remove_order(order)
        end
    end

end

function Runner:_should_move_to_next_waypoint()
    local waypoint = self:_get_next_waypoint()
    if waypoint == nil then
        return false
    end

    if self.player.controller_type == defines.controllers.character then
        return waypoint:has_character_arrived(self.player.character) == true 
    elseif self.player.controller_type == defines.controllers.god then
        return true
    else
        return false
    end
end

function Runner:step()
    local player = self.player
    
    if player == nil then
        return
    elseif is_valid(player) == false then
        self.player = nil
    end

    if player.controller_type == defines.controllers.ghost then
        return -- do respawn here
    end

    local character = player.character -- may be nil!
    local waypoint = self:_get_current_waypoint()

    local immobile = self:_step_mine_state()

    self:_step_build_state()

    self:_step_craft_state()

    self:_step_item_transfer_state()

    -- walk towards waypoint
    if immobile == false then
        self:_set_walking_state()
    end

    -- move ahead in the sequence
    while self:_should_move_to_next_waypoint() == true do
        
        self.waypoint_index = self.waypoint_index + 1
        self:_process_waypoint_orders(self:_get_current_waypoint())
        self:_set_walking_state()
    end
end

--[Comment]
-- Sets the player that this runner will control while stepping.
function Runner:set_player(player)
    if player ~= nil and is_valid(player) == false then
        error()
    end

    self.player = player
end

function Runner:get_sequence()
    return self.sequence
end

function Runner:_get_current_waypoint()
	return self.sequence.waypoints[self.waypoint_index]
end

function Runner:_get_next_waypoint()
	return self.sequence.waypoints[self.waypoint_index + 1]
end

return Runner