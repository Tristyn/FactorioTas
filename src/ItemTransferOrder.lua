local mathex = require("mathex")
local mt = require("persistent_mt")

local ItemTransferOrder = { }
local metatable = { __index = ItemTransferOrder }
mt.init(ItemTransferOrder, "ItemTransferOrder", metatable)

function ItemTransferOrder.set_metatable(instance)
	mt.bless(instance, metatable)
end

function ItemTransferOrder.new(is_player_receiving, player_inventory_index, container_entity, container_inventory_index, item_stack)
	local container_name = container_entity.name
	if container_name == "entity-ghost" then
		container_name = container_entity.ghost_name
	end

	local new = {
		is_player_receiving = is_player_receiving,
        container_name = container_name,
        container_surface_name = container_entity.surface.name,
        container_position = container_entity.position,
        container_inventory_index = container_inventory_index,
		player_inventory_index = player_inventory_index,
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

function ItemTransferOrder:container_to_string()
	return self.container_surface_name .. "_" .. self.container_name .. "_" .. self.container_position.x .. "_" .. self.container_position.y
end

function ItemTransferOrder:get_surface()
	return game.surfaces[self.container_surface_name]
end

function ItemTransferOrder:get_count()
	return self.item_stack.count
end

function ItemTransferOrder:get_source_target_inventories(player)
	local player_inv = player.get_inventory(self.player_inventory_index)
	local entity_inv = nil
	local entity = self:get_entity()
	if entity ~= nil then 
		entity_inv = entity.get_inventory(self.container_inventory_index)
	end
	
	if self.is_player_receiving == true then
		return entity_inv, player_inv
	else
		return player_inv, entity_inv
	end
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

function ItemTransferOrder:can_reach(player)
    return util.can_reach(player, self.container_surface_name, self.container_name, self.container_position)
end

function ItemTransferOrder:can_transfer(player)
	fail_if_missing(player)

	if self:can_reach(player) == false then
		return false
	end
	
	local source_inv, target_inv = self:get_source_target_inventories(player)
	if source_inv == nil or target_inv == nil then 
		return false
	end

	if source_inv.get_item_count(self.item_stack.name) < self.item_stack.count then
		return false
	end

	if target_inv.can_insert(self.item_stack) == false then
		return false
	end

	return true
end

function ItemTransferOrder:transfer(player)
	fail_if_missing(player)

	if self:can_transfer(player) == false then error() end

	local entity = self:get_entity()

	local source_inv, target_inv = self:get_source_target_inventories(player)
	
	local num_transferable = math.min(self.item_stack.count, source_inv.get_item_count(self.item_stack.name))

	if num_transferable ~= self.item_stack.count then error() end

	local transfer_stack = { count = num_transferable, name = self.item_stack.name }
	local num_transfered = target_inv.insert(transfer_stack)
	transfer_stack.count = num_transfered
	local num_removed = source_inv.remove(transfer_stack)

	if num_transfered ~= num_removed then
		error()
	end

	return num_transfered
end

return ItemTransferOrder