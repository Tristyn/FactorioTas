local BuildOrderDispatcher = require("BuildOrderDispatcher")
local Sequence = require("Sequence")

local Runner = { }
local metatable = { __index = Runner }

function Runner.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

    Sequence.set_metatable(instance.sequence)
    BuildOrderDispatcher.set_metatable(instance.build_order_dispatcher)
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
        in_progress_build_order = nil,

        pending_mine_orders = { },
        in_progress_mine_order = nil,
        mine_order_started_tick = 0,

        pending_craft_orders = { },
        pending_craft_orders_num_crafted = { },
    }
    
    Runner.set_metatable(new)

    new:_process_waypoint_orders(sequence_start)
    
    return new
end

function Runner:_process_waypoint_orders(waypoint)
    fail_if_missing(waypoint)

    for k, order in pairs(waypoint.build_orders) do
        self.build_order_dispatcher.add_order(order)
    end

    for _, mine_order in pairs(waypoint.mine_orders) do
        self.pending_mine_orders[mine_order] = mine_order
    end

    for _, craft_order in pairs(waypoint.craft_orders) do
        self.pending_craft_orders[craft_order] = craft_order
        self.pending_craft_orders_num_crafted[craft_order] = 0
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
    if self.in_progress_build_order == nil then
        self.in_progress_build_order = self.build_order_dispatcher:find_completable_order_near_player(self.player)
        if self.in_progress_build_order == nil then
            return false
        end

        self.build_order_dispatcher:remove_order(self.in_progress_build_order)
    end
    
    local order = self.in_progress_build_order

    if order == nil then
        return false
    end


    if order:is_order_item_in_cursor_stack(self.player) == false then
        if order.move_order_item_to_cursor_stack(self.player) == true then
            return true
        else
            build_order_dispatcher.add_order(order)
            self.in_progress_build_order = nil
        end
    else
        if order.spawn_entity_through_player(self.player) == true then
            self.in_progress_build_order = nil
            return true
        else
            build_order_dispatcher.add_order(order)
            self.in_progress_build_order = nil
        end
    end
end

-- returns true if mining is in progress (and player mouse can't be used for another task)
function Runner:_step_mine_state()
    local character = self.player.character

    if self.in_progress_mine_order == nil then
        -- find the next mine order
        for mine_order_index, mine_order in ipairs(self.pending_mine_orders) do

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

    local ticks_spent_mining = game.tick - mine_order_started_tick
    local time_to_mine_once = mine_order:get_mining_time(character)
    
    -- check if resources should be awarded
    if ticks_spent_mining % time_to_mine_once == 0 and mine_order_started_tick ~= game.tick then
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

    -- insert one crafting item in the queue each step

    for _, craft_order in ipairs(self.pending_craft_orders) do
        local num_crafted = self.pending_craft_orders_num_crafted[craft_order]
        local craft_order_total = craft_order:get_count()
        local num_remaining = craft_order_total - num_crafted
        
        local num_started = self.player.begin_crafting( { count = 1, recipe = craft_order.recipe_name, silent = false })
        if num_started > 0 then
            num_crafted = num_crafted + num_started
            self.pending_craft_orders_num_crafted[craft_order] = num_crafted

            if num_crafted < craft_order_total then
                return true
            end
            
            -- mutating a list causes the next loop iteration to be undefined.
            -- It is OK to mutate here because we are exiting the loop immediately.
            self.pending_craft_orders_num_crafted[craft_order] = nil
            self.pending_craft_orders[craft_order] = nil
            return true
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

    local mouse_in_use = self:_step_mine_state()

    if mouse_in_use == false then
        -- check construction
        mouse_in_use = self:_step_build_state()
    end

    if mouse_in_use == false then
        mouse_in_use = self:_step_craft_state()
    end

    -- walk towards waypoint
    self:_set_walking_state()

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