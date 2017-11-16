local BuildOrderDispatcher = { }
local metatable = { __index = BuildOrderDispatcher }

BuildOrderDispatcher.execution_progress = {
	tick_1_set_cursor_stack = 1,
	tick_2_build_entity = 2,
	tick_3_complete = 3
}

function BuildOrderDispatcher.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)
end

function BuildOrderDispatcher.new()
	local new = {
		_orders_grouped_by_item_name = { }
	}

	BuildOrderDispatcher.set_metatable(new)

	return new
end

function BuildOrderDispatcher:add_order(build_order)
	fail_if_missing(build_order)

	local item_name = build_order.item_name
	local order_group = self._orders_grouped_by_item_name[item_name]

	if order_group == nil then
		order_group = { }
		self._orders_grouped_by_item_name[item_name] = order_group
	end

	if order_group[build_order] ~= nil then 
		error("Build order added to the dispatcher twice.")
	end

	order_group[build_order] = build_order
end

function BuildOrderDispatcher:find_completable_order_near_player(player)
	fail_if_invalid(player)
	
	local cursor_stack_name = nil
	local orders_using_cursor_stack = nil

	if player.cursor_stack.valid_for_read then
		cursor_stack_name = player.cursor_stack.name
		orders_using_cursor_stack = self._orders_grouped_by_item_name[cursor_stack_name]
	end

	-- preferably find a build order for an item thats in the players hands
	if orders_using_cursor_stack ~= nil then
		for _, order in pairs(orders_using_cursor_stack) do
			if order:can_spawn_entity_through_player(player) then
				return order
            end
		end
	end
		
	-- find a build order for any item in the inventory.
	-- skip build orders for items in the cursor stack;
	-- those were checked in the above loop

	for item_name, order_collection in pairs(self._orders_grouped_by_item_name) do
		if item_name ~= cursor_stack_name then
			for _, order in pairs(order_collection) do
				if order:can_spawn_entity_through_player(player) then
					return order
				end
			end
		end
	end
end

--[Comment]
-- Returns a collection of build orders in which at least one is reachable by the player
-- and all have matching item names.
function BuildOrderDispatcher:find_chainable_completable_orders_some_near_player(player)
	fail_if_invalid(player)
	
	local cursor_stack_name = nil
	local orders_using_cursor_stack = nil

	if player.cursor_stack.valid_for_read then
		cursor_stack_name = player.cursor_stack.name
		orders_using_cursor_stack = self._orders_grouped_by_item_name[cursor_stack_name]
	end

	-- preferably find a build order for an item thats in the players hands
	if orders_using_cursor_stack ~= nil then
		for _, order in pairs(orders_using_cursor_stack) do
			if order:can_spawn_entity_through_player(player) then
				return orders_using_cursor_stack
            end
		end
	end
		
	-- find a build order for any item in the inventory.
	-- skip build orders for items in the cursor stack;
	-- those were checked in the above loop

	for item_name, order_collection in pairs(self._orders_grouped_by_item_name) do
		if item_name ~= cursor_stack_name then
			for _, order in pairs(order_collection) do
				if order:can_spawn_entity_through_player(player) then
					return order_collection
				end
			end
		end
	end
end

function BuildOrderDispatcher:remove_order(order)
	fail_if_missing(order)

	orders = self._orders_grouped_by_item_name[order.item_name]
	if orders == nil then error() end
	orders[order] = nil
end

function BuildOrderDispatcher:_is_build_order_added_to_dispatcher(build_order)
	fail_if_missing(build_order)

	local collection = self._orders_grouped_by_item_name[build_order.item_name]
	if collection == nil then return false end

	return collection[build_order] ~= nil
end

return BuildOrderDispatcher