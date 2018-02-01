local BuildOrder = require("BuildOrder")
local MineOrder = require("MineOrder")
local CraftOrder = require("CraftOrder")
local ItemTransferOrder = require("ItemTransferOrder")
local Event = require("Event")
local Template = require("Template")

--- Waypoint.changed event:
-- This event is invoked every time any order is added or removed or the waypoint position and surface changes.
-- Parameters
-- sender :: The waypoint that triggered the callback.
-- type :: string: Can be any of [moved]
-- Additional type specific parameters:
-- -- moved
-- -- -- old_surface_name :: string
-- -- -- old_position :: table: {x , y}

local Waypoint = { }
local metatable = { __index = Waypoint }

function Waypoint.set_metatable(instance)

	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, metatable)

	for k, v in pairs(instance.build_orders) do
		BuildOrder.set_metatable(v)
	end

	for k, v in pairs(instance.mine_orders) do
		MineOrder.set_metatable(v)
	end

	for k, v in pairs(instance.craft_orders) do
		CraftOrder.set_metatable(v)
	end

	for k, v in pairs(instance.item_transfer_orders) do
		ItemTransferOrder.set_metatable(v)
	end

end

function Waypoint.new()
	local new =
    {
        surface_name = "nauvis",
		position = { x = 0, y = 0 },
		highlighted = false,
        build_orders = { },
        mine_orders = { },
        craft_orders = { },
		item_transfer_orders = { },
		changed = Event.new()
	}

	Waypoint.set_metatable(new)

	return new
end

-- [Comment]
-- Creates a new waypoint instance.
-- Creates the entity if spawn_entity is true.
-- returns an error if a waypoint already exists at the position and `spawn_entity` is true.
function Waypoint.new(surface_name, position, spawn_entity)
	local new = Waypoint.new()

	new.surface_name = surface_name
	new.position = position

	if spawn_entity == true then
		local waypoint_entity = new:_spawn_entity()
	else
		local existing = new:get_entity()
		if is_valid(existing) then
			Waypoint._configure_entity(existing)
		end
	end
	
	return new
end

function Waypoint.new_from_template(template)
	local new = util.clone_table(template)
	new.position = util.clone_table(template.position)
	
	new.build_orders = { }
	new.mine_orders = { }
	new.craft_orders = { }
	new.item_transfer_orders = { }

	Waypoint.set_metatable(new)

	for index, order_template in pairs(template.build_orders) do
		local order = BuildOrder.new_from_template(order_template)
		table.insert(new.build_orders, order, index)
		order:assign_waypoint(new, index)
	end

	for index, order_template in pairs(template.mine_orders) do
		local order = MineOrder.new_from_template(order_template)
		table.insert(new.mine_orders, order, index)
		order:assign_waypoint(new, index)
	end

	for index, order_template in pairs(template.craft_orders) do
		local order = CraftOrder.new_from_template(order_template)
		table.insert(new.craft_orders, order, index)
		order:assign_waypoint(new, index)
	end

	for index, order_template in pairs(template.item_transfer_orders) do
		local order = ItemTransferOrder.new_from_template(order_template)
		table.insert(new.item_transfer_orders, order, index)
		order:assign_waypoint(new, index)
	end

	return new
end

function Waypoint:to_template(seen)
	local clone = util.clone_table(self)
	clone.changed = nil

	return Template.convert_children(self, clone, seen)
end

function Waypoint:assign_sequence(sequence, index)
	if self.sequence ~= nil then
        error("A sequence can only be assigned once.") 
    end
    if sequence.waypoints[index] ~= self then error() end
    
    self.sequence = sequence
    self.index = index
end

function Waypoint:set_index(index)
	if self.sequence.waypoints[index] ~= self then error() end

	self.index = index
end

function Waypoint:to_string()
	return self.position.x .. '_' .. self.position.y .. '_' .. self.surface_name .. '_' .. "tas-waypoint" 
end

function Waypoint.entity_to_string(waypoint_entity)
	return util.entity.to_string(waypoint_entity)
end

function Waypoint:get_entity()
	return util.find_entity(self.surface_name, "tas-waypoint", self.position)
end

function Waypoint.spawn_entity(surface, position)
	fail_if_missing(surface)
	fail_if_missing(position)

	local entity = surface.create_entity { name = "tas-waypoint", position = position }
	Waypoint._configure_entity(entity)
end

function Waypoint:_spawn_entity()

	if util.find_entity(self.surface_name, "tas-waypoint", self.position) ~= nil then 
		error("Waypoint object was created too close to another.")
	end

	Waypoint.spawn_entity(game.surfaces[self.surface_name], self.position)
end

function Waypoint._configure_entity(entity)
	entity.destructible = false
end

function Waypoint:_destroy_entity()
	local entity = self:get_entity()
	if is_valid(entity) == true then
		entity.destroy()
	end
end

function Waypoint:_get_highlight_entity()
	return util.find_entity(self.surface_name, "tas-waypoint-selected", self.position)
end

function Waypoint:_spawn_highlight_entity()
	if util.find_entity(self.surface_name, "tas-waypoint-selected", self.position) ~= nil then 
		return
	end

	game.surfaces[self.surface_name].create_entity { name = "tas-waypoint-selected", position = self.position }
end

function Waypoint:_destroy_highlight_entity()
	local highlight = self:_get_highlight_entity()
	if is_valid(highlight) == true then
		highlight.destroy()
	end
end

function Waypoint:add_build_order_from_ghost_entity(ghost_entity)
	local order = BuildOrder.new_from_ghost_entity(ghost_entity)
	
	local insert_index = #self.build_orders + 1
	self.build_orders[insert_index] = order
	order:assign_waypoint(self, insert_index)

	return order
end

function Waypoint:remove_build_order(index)
	self:_remove_order(self.build_orders, index)
end

function Waypoint:add_mine_order_from_entity(entity)
	local order = MineOrder.new_from_entity(entity)

	table.insert(self.mine_orders, order)
	order:assign_waypoint(self, #self.mine_orders)

	return order
end

function Waypoint:remove_mine_order(index)
	self:_remove_order(self.mine_orders, index)
end

function Waypoint:add_craft_order(recipe_name, count)
    fail_if_missing(recipe_name)
	fail_if_missing(count)
	
	
    local craft_orders = self.craft_orders
	local crafting_queue_end = craft_orders[#craft_orders]

	local craft_order = CraftOrder.new(recipe_name, count)
	
	-- Merge with the last order if recipes match or append a new order to the end
    if crafting_queue_end ~= nil and crafting_queue_end:can_merge(craft_order) then

        crafting_queue_end:merge(craft_order)

    else

		table.insert(craft_orders, craft_order)
		craft_order:assign_waypoint(self, #craft_orders)

	end
	
	return craft_order
end

function Waypoint:remove_craft_order(index)
	self:_remove_order(self.craft_orders, index)
end

function Waypoint:add_item_transfer_order(is_player_receiving, player_inventory_index, container_entity, container_inventory_index, items_to_transfer)
	
	local order = ItemTransferOrder.new(is_player_receiving, player_inventory, container_entity, container_inventory_index, items_to_transfer)

	-- If we can't merge the order, then append it
	
    local combined_order = self:_try_merge_item_transfer_order_with_collection(order)
	
	if combined_order ~= nil then
		return combined_order
	else
		table.insert(self.item_transfer_orders, order)
		order:assign_waypoint(self, #self.item_transfer_orders)
		return order
	end
end

function Waypoint:remove_item_transfer_order(index)
	self:_remove_order(self.item_transfer_orders, index)
end

--[Comment]
-- Attempts to merge with any existing orders.
-- Returns the order that it was merged into or nil if none were possible.
function Waypoint:_try_merge_item_transfer_order_with_collection(order)
	for _, existing in pairs(self.item_transfer_orders) do
		if existing:can_merge(order) then
			existing:merge(order)
			return existing
		end
	end
end

function Waypoint:_remove_order(order_collection, index)
	fail_if_missing(order_collection)
	fail_if_missing(index)

	if index < 1 or index > #order_collection then
		error("index out of range")
	end
	
	table.remove(order_collection, index)

	for i = index, #order_collection do
		order_collection[i]:set_index(i)
	end
end

function Waypoint:move(surface_name, position)
	self:_move(surface_name, position)
end

function Waypoint:move_to_entity(waypoint_entity)
	self:_move(waypoint_entity.surface.name, waypoint_entity.position, waypoint_entity)
end

--[Comment]
-- new_entity represents the updated position and surface, can be nil
function Waypoint:_move(surface_name, position, new_entity)
	fail_if_missing(surface_name)
	fail_if_missing(position)

	local old_surface_name = self.surface_name
	local old_position = self.position

    -- clean up entities
    local old_waypoint_entity = self:get_entity()
    if is_valid(old_waypoint_entity)  then
        old_waypoint_entity.destroy()
	end
	if self.highlighted then
		local old_highlight = self:_get_highlight_entity()
		if is_valid(old_highlight) then
			old_highlight.destroy()
		end
	end
	
	self.surface_name = surface_name
	self.position = position

	if is_valid(new_entity) == false then
		self:_spawn_entity()
	end

	if self.highlighted == true then
		self:_spawn_highlight_entity()
	end

	local event = {
		sender = self,
		type = "moved",
		old_surface_name = old_surface_name,
		old_position = old_position
	}

	self:_changed(event)
end

function Waypoint:set_highlight(highlighted)
	self.highlighted = highlighted

	if highlighted == true then
		self:_spawn_highlight_entity()
	elseif highlighted == false then
		self:_destroy_highlight_entity()
	else
		error()
	end
end

--[Comment]
-- Returns a direction the character as to walk to move closer to the Waypoint.
-- Returns nil if it would move over the Waypoint.
function Waypoint:get_direction(character)
	local walking_speed = util.get_walking_speed(character)
    return util.get_directions(character.position, self.position, walking_speed)
end

function Waypoint:has_character_arrived(character)
	return self:get_direction(character) == nil
end

function Waypoint:_changed(event)
	for _, func in pairs(self._on_changed_callbacks) do
		func(event)
	end
end


function Waypoint:on_changed(func)
	if self._on_changed_callbacks[func] ~= nil then
		error()
	end
	self._on_changed_callbacks[func] = func
end

--[Comment]
-- Ends further callbacks. Returns true if the handler was found.
function Waypoint:unregister_on_changed(func)
	if self._on_changed_callbacks[func] == nil then
		error()
	end
	self._on_changed_callbacks[func] = nil
end

--[Comment]
-- Returns a collection containing lists of orders that are within this Waypoint.
function Waypoint:_get_order_collections()
	return {
		self.build_orders,
		self.mine_orders,
		self.craft_orders,
		self.item_transfer_orders
	}
end

function Waypoint:destroy()
	self:_destroy_entity()
	self:set_highlight(false)

	for k, order in pairs(self.build_orders) do
		order:destroy()
	end
end

return Waypoint