local mathex = require("mathex")

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
		-- itemstack could be LuaItemStack, so clone properties to a table
		item_stack = { name = item_stack.name, count = item_stack.count }
	}

	ItemTransferOrder.set_metatable(new)

	-- sanitize count
	new:set_count(item_stack.count)

	return new
end

function ItemTransferOrder.new_from_template(template)
	local new = util.clone_table(template)
	new.container_position = util.clone_table(template.container_position)
	new.item_stack = util.clone_table(template.item_stack)

	ItemTransferOrder.set_metatable(new)

	return new
end

function ItemTransferOrder:to_template()
	local template = util.clone_table(self)
	template.container_position = util.clone_table(self.container_position)
	template.waypoint = nil
	return template
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

function ItemTransferOrder:get_surface()
	return game.surfaces[self.container_surface_name]
end

function ItemTransferOrder:get_count()
	return self.item_stack.count
end

function ItemTransferOrder:set_count(value)
	fail_if_missing(value)
	if value < 1 then error("Out of range")	end
	if value ~= mathex.round(value) then error("Fractional count") end

	self.item_stack.count = value
end

function ItemTransferOrder:can_merge(other)
	return self.is_player_receiving == other.is_player_receiving
	and self.container_name == other.container_name
	and self.container_surface_name == other.container_surface_name
	and self.container_position.x == other.container_position.x
	and self.container_position.y == other.container_position.y
	and self.container_inventory_index == other.container_inventory_index
	and self.player_inventory_index == other.player_inventory_index
	and self.item_stack.name == other.item_stack.name
end

--[Comment]
-- Merge the source into this. May throw an error if :can_merge returns false
function ItemTransferOrder:merge(source)
	if self:can_merge(source, destination) == false then
        error("Attempted to merge two item transfer orders that are incompatible.")
    end

    self.item_stack.count = self.item_stack.count + source.item_stack.count
end

return ItemTransferOrder