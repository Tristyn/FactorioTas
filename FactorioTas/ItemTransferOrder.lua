local ItemTransferOrder = { }
local metatable = { __index = ItemTransferOrder }

function ItemTransferOrder.set_metatable(instance)
	setmetatable(instance, metatable)
end

function ItemTransferOrder.new(is_player_receiving, player_inventory, container_inventory, item_stack)
	local new = {
		is_player_receiving = is_player_receiving,
        container_name = container_inventory.entity_owner.name,
        container_surface_name = container_inventory.entity_owner.surface.name,
        container_position = container_inventory.entity_owner.position,
        container_inventory_index = container_inventory.index,
		player_inventory_index = player_inventory.index,
        item_stack = item_stack
	}

	ItemTransferOrder.set_metatable(new)

	return new
end

function ItemTransferOrder:assign_waypoint(waypoint, index)
	fail_if_missing(waypoint)
	fail_if_missing(index)

	if self.waypoint ~= nil then
		error("A waypoint can only be assigned once.")
	end
	if waypoint.item_transfer_orders[index] ~= self then error() end

	self.waypoint = waypoint
	self.index = index
end

function ItemTransferOrder:set_index(index)
	if self.waypoint.item_transfer_orders[index] ~= self then error() end

	self.index = index
end

function ItemTransferOrder:get_entity()
	return util.find_entity(self.container_surface_name, self.container_name, self.container_position)
end

function ItemTransferOrder:can_merge(other)
	return self.is_player_receiving == order.is_player_receiving
	and self.container_name == order.container_name
	and self.container_surface_name == order.container_surface_name
	and self.container_position.x == order.container_position.x
	and self.container_position.y == order.container_position.y
	and self.container_inventory_index == order.container_inventory_index
	and self.player_inventory_index == order.player_inventory_index
	and self.item_stack.name == order.item_stack.name
end

--[Comment]
-- Merge the source into this. May throw an error if :can_merge returns false
function ItemTransferOrder:merge(source)
	if tas.can_item_transfer_orders_be_merged(source, destination) == false then
        error("Attempted to merge two item transfer orders that are incompatible.")
    end

    self.item_stack.count = self.item_stack.count + source.item_stack.count
end