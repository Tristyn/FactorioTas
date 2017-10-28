local BuildOrder = require("BuildOrder")

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
end

-- [Comment]
-- Creates a new waypoint instance.
-- Creates the entity if spawn_entity is true.
-- returns an error if a waypoint already exists at the position and `spawn_entity` is true.
function Waypoint.new(surface_name, position, spawn_entity)
	
    local new =
    {
        surface_name = surface_name,
		position = position,
		highlighted = false,
        build_orders = { },
        mine_orders = { },
        craft_orders = { },
		item_transfer_orders = { },
		_on_changed_callbacks = { }
	}

	Waypoint.set_metatable(new)

	if spawn_entity == true then
		local waypoint_entity = new:_spawn_entity()
	else
		local existing = new:get_entity()
		if is_valid(existing) then
			new:_configure_entity(existing)
		end
	end
	
	return new
end

function Waypoint:assign_sequence(sequence, index)
	if self.sequence ~= nil then
        error("A sequence can only be assigned once.") 
    end
    if sequence.waypoints[index] ~= self then error() end
    
    self.sequence = waypoint
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
	return util.entity.tostring(waypoint_entity)
end

function Waypoint:get_entity()
	return util.find_entity(self.surface_name, "tas-waypoint", self.position)
end

function Waypoint:_spawn_entity()

	if util.find_entity(self.surface_name, "tas-waypoint", self.position) ~= nil then 
		error("Waypoint object was created too close to another.")
	end

	local entity = game.surfaces[self.surface_name].create_entity { name = "tas-waypoint", position = self.position }
	self:_configure_entity(entity)
end

function Waypoint:_configure_entity(entity)
	entity.destructible = false
end

function Waypoint:_destroy_entity()
	local entity = self:get_entity()
	if is_valid(entity) == true then
		entity.destry()
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
		highlight.destry()
	end
end

function Waypoint:add_build_order_from_ghost_entity(ghost_entity)
	local order = BuildOrder.new(ghost_entity)
	
	local insert_index = #self.build_orders + 1
	self.build_orders[insert_index] = order
	order:assign_waypoint(self, insert_index)

	return order
end

function Waypoint:remove_build_order(index)
	self:_remove_order(self.build_orders, index)
end

function Waypoint:add_craft_order(recipe_name, count)
    fail_if_missing(recipe)
	fail_if_missing(count)
	
	
    local craft_orders = self.craft_orders
	local crafting_queue_end = craft_orders[#craft_orders]
	
	-- Merge with the last order if recipes match or append a new order to the end
    if crafting_queue_end ~= nil and recipe == crafting_queue_end.recipe then

        crafting_queue_end.count = crafting_queue_end.count + count

    else

        local craft_order = { recipe_name = recipe_name, count = count }
        table.insert(craft_orders, craft_order)

	end
	
	return craft_order
end

function Waypoint:remove_craft_order(index)
	self:_remove_order(self.craft_orders, index)
end

function Waypoint:_remove_order(table, index)
	fail_if_missing(table)
	fail_if_missing(index)

	if index < 1 or index > #table then
		error("index out of range")
	end
	
	table.remove(table, index)

	for i = index, #table do
		table[i].set_index(i)
	end
end

function Waypoint:move(surface_name, position)
	Waypoint:_move(surface_name, position)
end

function Waypoint:move_to_entity(waypoint_entity)
	self:_move(waypoint_entity.surface.name, waypoint_entity.position, waypoint_entity)
end

--[Comment]
-- new_entity represents the updated position and surface, can be nil
function Waypoint:_move(surface_name, position, new_entity)
	fail_if_missing(surface_name)
	fail_if_missing(position)

	local event = {
		sender = self,
		type = "moved",
		surface_name = surface_name,
		position = position
	}

	self:_changed(event)

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
end

function Waypoint:set_highlight(highlighted)
	if highlighted == true and self.highlighted == false then
		self:_spawn_highlight_entity()
		game.highlighted = true
	elseif highlighted == false and self.highlighted == true then
		self:_destroy_highlight_entity()
		game.highlighted = false
	else
		error()
	end
end

function Waypoint:_changed(event)
	for _, func in pairs(self.on_changed_callbacks) do
		func(event)
	end
end

--[Comment]
-- Registers a callback to be run before a waypoint changes and provides an event object. This is called every time any order is added or removed or the waypoint position and surface changes.
-- Parameters
-- sender :: The waypoint that triggered the callback.
-- type :: string: Can be any of [moved]
-- Additional type specific parameters:
-- -- moved
-- -- -- surface_name :: string
-- -- -- position :: table: {x , y}
function Waypoint:on_changed(func)
	table.insert(self._on_changed_callbacks, func)
end

--[Comment]
-- Ends further callbacks. Returns true if the handler was found.
function Waypoint:unregister_on_changed(func)
	table.remove(self._on_changed_callbacks, func)
end

return Waypoint